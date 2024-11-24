#!/bin/bash

if [ $(id -u) -ne 0 ]
  then echo "Please run this script as root or using sudo"
  exit 1
fi

if [[ ! -d "/etc/iptables" ]]; then
	echo "The script is intended to be used with iptables. Are you sure all the necessary packages are installed?"
	exit 2
fi

if [[ ! -f "/etc/ipset.conf" ]]; then
	echo "The script is intended to be used with ipset. Are you sure all the necessary packages are installed?"
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

# Remove iptables rule
if iptables -t raw -C PREROUTING -m set --match-set ru-blacklist-v4 src -j DROP 2>/dev/null; then
	iptables -t raw -D PREROUTING -m set --match-set ru-blacklist-v4 src -j DROP
	echo "iptables rule for PREROUTING chain was successfully removed"
else
	echo "iptables rule for PREROUTING chain wasn't found"
fi
iptables-save > /etc/iptables/rules.v4

# Remove ip6tables rule
if ip6tables -t raw -C PREROUTING -m set --match-set ru-blacklist-v6 src -j DROP 2>/dev/null; then
	ip6tables -t raw -D PREROUTING -m set --match-set ru-blacklist-v6 src -j DROP
	echo "ip6tables rule for PREROUTING chain was successfully removed"
else
	echo "ip6tables rule for PREROUTING chain wasn't found"
fi
ip6tables-save > /etc/iptables/rules.v6

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
ipset save > /etc/ipset.conf

echo "Blacklist was successfully disabled"

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