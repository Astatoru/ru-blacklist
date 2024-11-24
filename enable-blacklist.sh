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

# Download the blacklist
URL="https://raw.githubusercontent.com/C24Be/AS_Network_List/refs/heads/main/blacklists/blacklist.txt"
curl -o "ru-blacklist.txt" "$URL" &>/dev/null
if [ $? -eq 0 ]; then
    echo "The blacklist was successfully updated"
else
    echo "Update failed"
    exit 2
fi

# Backup current iptables rules
if [ ! -d "iptables-backup" ]; then
  mkdir "iptables-backup"
fi
if [ -f "iptables-backup/iptables.rules" ]; then
	mv "iptables-backup/iptables.rules" "iptables-backup/iptables_old.rules"
fi
iptables-save > "iptables-backup/iptables.rules"

# Delete old iptables rule
if iptables -n -t raw -C PREROUTING -m set --match-set ru-blacklist src -j DROP 2>/dev/null; then
	iptables -n -t raw -D PREROUTING -m set --match-set ru-blacklist src -j DROP
fi

# Delete old ipset list
if ipset list -n | grep -q "ru-blacklist"; then
	ipset destroy ru-blacklist
fi

# Create new ipset list
ipset create ru-blacklist hash:net &>/dev/null
while read -r ip; do
    if ! ipset test ru-blacklist "$ip" 2>/dev/null; then
        ipset add ru-blacklist "$ip"
		echo "$ip was successfully added to ipset"
    fi
done < ru-blacklist.txt
ipset save > /etc/ipset.conf

# Create new iptables rule
if ! iptables -n -t raw -C PREROUTING -m set --match-set ru-blacklist src -j DROP 2>/dev/null; then
	iptables -n -t raw -I PREROUTING -m set --match-set ru-blacklist src -j DROP
	echo "The rule for PREROUTING chain was successfully created"
fi
iptables-save > /etc/iptables/iptables.rules

echo "The blacklist was successfully enabled"
