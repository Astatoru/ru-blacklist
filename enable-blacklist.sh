#!/bin/bash
set -euo pipefail

if [ $(id -u) -ne 0 ]
  then echo "Please run this script as root or using sudo"
  exit 1
fi

if [[ ! -d "/etc/iptables" ]]; then
	echo "The script is intended to be used with iptables. Are you sure all the necessary packages are installed?"
	exit 2
fi

if [[ ! -d "/etc/ipset.conf" ]]; then
	echo "The script is intended to be used with ipset. Are you sure all the necessary packages are installed?"
	exit 2
fi

# Backup old ru-blacklist.txt file
if [ -f "ru-blacklist.txt" ]; then
    mv "ru-blacklist.txt" "ru-blacklist-old.txt"
else
    echo "ru-blacklist.txt not found"
fi

# Download the blacklist
URL="https://raw.githubusercontent.com/C24Be/AS_Network_List/refs/heads/main/blacklists/blacklist.txt"
curl -o "ru-blacklist.txt" "$URL" &>/dev/null
if [ $? -eq 0 ]; then
    echo "Blacklist was successfully updated"
else
    echo "Blacklist update failed"
    exit 2
fi

# Backup current iptables rules
if [ ! -d "iptables-backup" ]; then
  mkdir "iptables-backup"
fi
if [ -f "iptables-backup/rules.v4" ]; then
	mv "iptables-backup/rules.v4" "iptables-backup/rules_old.v4"
fi
iptables-save > "iptables-backup/rules.v4"

# Backup current ip6tables rules
if [ -f "iptables-backup/rules.v6" ]; then
	mv "iptables-backup/rules.v6" "iptables-backup/rules_old.v6"
fi
ip6tables-save > "iptables-backup/rules.v6"

echo "iptables and ip6tables rules were successfully backed up"

# Create a new ipset lists for ipv4 and ipv6
ipset create ru-blacklist-v4 hash:net &>/dev/null
ipset create ru-blacklist-v6 hash:net family inet6 &>/dev/null

# Read a new blacklist and add cidrs to ipset lists
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
        echo "$ip is not a valid IP address"
    fi
done < ru-blacklist.txt

# Read an old blacklist
while read -r ip; do
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        old_ips["$ip"]=1
    elif [[ "$ip" =~ ^[0-9a-fA-F:]+(/[0-9]+)?$ ]]; then
        old_ips["$ip"]=1
    else
        echo "$ip is not a valid IP address"
    fi
done < ru-blacklist-old.txt

# Remove cidrs that was removed with a new blacklist update
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
ipset save > /etc/ipset.conf

# Create a new iptables rule
if ! iptables -t raw -C PREROUTING -m set --match-set ru-blacklist-v4 src -j DROP 2>/dev/null; then
	iptables -t raw -I PREROUTING -m set --match-set ru-blacklist-v4 src -j DROP
	echo "iptables rule for PREROUTING chain was successfully created"
fi
iptables-save > /etc/iptables/rules.v4

# Create a new ip6tables rule
if ! iptables -t raw -C PREROUTING -m set --match-set ru-blacklist-v6 src -j DROP 2>/dev/null; then
	iptables -t raw -I PREROUTING -m set --match-set ru-blacklist-v6 src -j DROP
	echo "ip6tables rule for PREROUTING chain was successfully created"
fi
ip6tables-save > /etc/iptables/rules.v6

echo "Blacklist was successfully enabled"

# Display current iptables and ip6tables rules
while true; do
read -p "Show current iptables and ip6tables rules in PREROUTING chain? (y/n): " answer
if [[ -z "$answer" || "$answer" == "y" ]]; then
	echo ""
	echo "iptables PREROUTING rules:"
	iptables -t raw -L PREROUTING -n -v
	echo ""
	echo "ip6tables PREROUTING rules:"
	ip6tables -t raw -L PREROUTING -n -v
	echo ""
	exit 0
elif [[ "$answer" == "n" ]]; then
	exit 0
else
    echo "Invalid input. Please enter 'y' or 'n'"
fi
done
