#!/bin/bash

# Colors
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

if [ $(id -u) -ne 0 ]
  then echo -e "${red}Please run this script as root or using sudo${nc}\a"
  exit 1
fi

if [[ ! -d "/etc/iptables" ]]; then
	echo -e "${red}The script is intended to be used with iptables. Are you sure all the necessary packages are installed?${nc}\a"
	exit 2
fi

if [[ ! -f "/etc/ipset.conf" ]]; then
	echo -e "${red}The script is intended to be used with ipset. Are you sure all the necessary packages are installed?${nc}\a"
	exit 2
fi

if [ ! -d "backup" ]; then
  mkdir "backup"
fi

# Backup current iptables rules
if [ -f "backup/rules.v4" ]; then
	mv "backup/rules.v4" "backup/rules_old.v4"
fi
iptables-save > "backup/rules.v4"
echo "iptables rules were successfully backed up: backup/rules.v4"

# Backup current ip6tables rules
if [ -f "backup/rules.v6" ]; then
	mv "backup/rules.v6" "backup/rules_old.v6"
fi
ip6tables-save > "backup/rules.v6"
echo "ip6tables rules were successfully backed up: backup/rules.v6"

# Backup current ipset settings
if [ -f "backup/ipset.conf" ]; then
	mv "backup/ipset.conf" "backup/ipset_old.conf"
fi
ipset save > "backup/ipset.conf"

echo "ipset settings were successfully backed up: backup/ipset.conf"
# Backup old ru-blacklist.txt file
if [ -f "ru-blacklist.txt" ]; then
    mv "ru-blacklist.txt" "ru-blacklist-old.txt"
    chmod 600 ru-blacklist-old.txt
	echo "ru-blacklist.txt was successfully backed up: ru-blacklist-old.txt"
else
    echo "ru-blacklist.txt wasn't found"
fi

# Download the blacklist
URL="https://raw.githubusercontent.com/C24Be/AS_Network_List/refs/heads/main/blacklists/blacklist.txt"
echo "Downloading ru-blacklist.txt..."
curl -# -o "ru-blacklist.txt" "$URL"

# Check if the download was successful
if [ $? -eq 0 ]; then
    echo "ru-blacklist.txt was successfully downloaded"
    chmod 600 ru-blacklist.txt
else
    echo -e "${red}ru-blacklist.txt download failed...${nc}\a"
    exit 2
fi

# Create a new ipset lists for ipv4 and ipv6
if ! ipset list ru-blacklist-v4 &>/dev/null; then
    ipset create ru-blacklist-v4 hash:net
    echo "New ipset list was successfully created: ru-blacklist-v4"
fi

if ! ipset list ru-blacklist-v6 &>/dev/null; then
    ipset create ru-blacklist-v6 hash:net family inet6
    echo "New ipset list was successfully created: ru-blacklist-v6"
fi

# Read a new blacklist and add ips to ipset lists
declare -A new_ips
declare -A old_ips
while read -r ip; do
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        new_ips["$ip"]=1
        if ! ipset test ru-blacklist-v4 "$ip" 2>/dev/null; then
            ipset add ru-blacklist-v4 "$ip"
            echo "$ip was successfully added to ru-blacklist-v4"
        fi
    elif [[ "$ip" =~ ^[0-9a-fA-F:]+(/[0-9]+)?$ ]]; then
        new_ips["$ip"]=1
        if ! ipset test ru-blacklist-v6 "$ip" 2>/dev/null; then
            ipset add ru-blacklist-v6 "$ip"
            echo "$ip was successfully added to ru-blacklist-v6"
        fi
    else
        echo -e "${red}$ip is not a valid IP address${nc}"
    fi
done < ru-blacklist.txt

# Read an old blacklist
if [[ -f ru-blacklist-old.txt ]]; then
    while read -r ip; do
        old_ips["$ip"]=1
    done < ru-blacklist-old.txt

# Remove ips that was removed with a new blacklist update
for ip in "${!old_ips[@]}"; do
    if [[ -z "${new_ips[$ip]}" ]]; then
        if ipset test ru-blacklist-v4 "$ip" &>/dev/null; then
            ipset del ru-blacklist-v4 "$ip"
            echo "$ip was successfully removed from ru-blacklist-v4"
        elif ipset test ru-blacklist-v6 "$ip" &>/dev/null; then
            ipset del ru-blacklist-v6 "$ip"
            echo "$ip was successfully removed from ru-blacklist-v6"
        fi
	fi
done
else
	echo "ru-blacklist-old.txt wasn't found"
fi
ipset save > "/etc/ipset.conf"
echo "New ipset settings were successfully saved and made persistent: /etc/ipset.conf"

# Create a new iptables rule
if ! iptables -t raw -C PREROUTING -m set --match-set ru-blacklist-v4 src -j DROP 2>/dev/null; then
	iptables -t raw -I PREROUTING -m set --match-set ru-blacklist-v4 src -j DROP
	echo "iptables rule for PREROUTING chain was successfully created"
fi

# Create a new ip6tables rule
if ! ip6tables -t raw -C PREROUTING -m set --match-set ru-blacklist-v6 src -j DROP 2>/dev/null; then
	ip6tables -t raw -I PREROUTING -m set --match-set ru-blacklist-v6 src -j DROP
	echo "ip6tables rule for PREROUTING chain was successfully created"
fi

# Save iptables and ip6tables rules and make them peristent
iptables-save > "/etc/iptables/rules.v4"
echo "New iptables rules were successfully saved and made persistent: /etc/iptables/rules.v4"
ip6tables-save > "/etc/iptables/rules.v6"
echo "New ip6tables rules were successfully saved and made persistent: /etc/iptables/rules.v6"

echo -e "${green}Blacklist was successfully enabled${nc}"

# Show current iptables and ip6tables rules
while true; do
	read -p "Show current iptables and ip6tables rules in PREROUTING chain? (y/n): " answer
	answer=${answer,,}
	if [[ -z "$answer" || "$answer" == "y" ]]; then
		echo ""
		echo "iptables PREROUTING rules:"
		iptables -t raw -L PREROUTING -n -v
		echo ""
		echo "ip6tables PREROUTING rules:"
		ip6tables -t raw -L PREROUTING -n -v
		echo ""
		break
	elif [[ "$answer" == "n" ]]; then
		break
	else
		echo -e "${red}Invalid input. Please enter 'y' or 'n'${nc}\a"
	fi
done

# Show current ipset list
while true; do
    read -p "Show current ipset lists? (y/n): " answer
	answer=${answer,,}
    if [[ -z "$answer" || "$answer" == "y" ]]; then
        # Check whether less is installed
        if command -v less &>/dev/null; then
            ipset list | less
        else
            ipset list | more
        fi
        exit 0
    elif [[ "$answer" == "n" ]]; then
        exit 0
    else
            echo -e "${red}Invalid input. Please enter 'y' or 'n'${nc}\a"
    fi
done
