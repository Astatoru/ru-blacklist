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

# Remove iptables rule
if iptables -t raw -C PREROUTING -m set --match-set ru-blacklist-v4 src -j DROP 2>/dev/null; then
	iptables -t raw -D PREROUTING -m set --match-set ru-blacklist-v4 src -j DROP
	echo "iptables rule for PREROUTING chain was successfully removed"
else
	echo "iptables rule for PREROUTING chain wasn't found"
fi

# Remove ip6tables rule
if ip6tables -t raw -C PREROUTING -m set --match-set ru-blacklist-v6 src -j DROP 2>/dev/null; then
	ip6tables -t raw -D PREROUTING -m set --match-set ru-blacklist-v6 src -j DROP
	echo "ip6tables rule for PREROUTING chain was successfully removed"
else
	echo "ip6tables rule for PREROUTING chain wasn't found"
fi

# Save iptables and ip6tables rules and make them peristent
iptables-save > "/etc/iptables/rules.v4"
echo "New iptables rules were successfully saved and made persistent: /etc/iptables/rules.v4"
ip6tables-save > "/etc/iptables/rules.v6"
echo "New ip6tables rules were successfully saved and made persistent: /etc/iptables/rules.v6"

# Delete ipset list for ipv4
if ipset list -n | grep -q "ru-blacklist-v4"; then
	ipset destroy ru-blacklist-v4
	echo "ipset list ru-blacklist-v4 was successfully removed"
else
	echo "ipset list ru-blacklist-v4 wasn't found"
fi

# Delete ipset list for ipv6
if ipset list -n | grep -q "ru-blacklist-v6"; then
	ipset destroy ru-blacklist-v6
	echo "ipset list ru-blacklist-v6 was successfully removed"
else
	echo "ipset list ru-blacklist-v6 wasn't found"
fi
ipset save > "/etc/ipset.conf"
echo "New ipset settings were successfully saved and made persistent: /etc/ipset.conf"

echo -e "${green}Blacklist was successfully disabled${nc}"

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
