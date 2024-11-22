#!/bin/bash

if [ $(id -u) -ne 0 ]
  then echo "Please run this script as root or using sudo"
  exit
fi

if [ ! -d "iptables-backup" ]; then
  mkdir "iptables-backup"
fi
iptables-save > "iptables-backup/iptables_disable-blacklist.rules"

if iptables -C INPUT -m set --match-set ru-blacklist src -j DROP 2>/dev/null; then
	iptables -D INPUT -m set --match-set ru-blacklist src -j DROP
fi

if iptables -C FORWARD -m set --match-set ru-blacklist src -j DROP 2>/dev/null; then
	iptables -D FORWARD -m set --match-set ru-blacklist src -j DROP
fi

if [ ! -d "/etc/iptables" ]; then
  mkdir "/etc/iptables"
fi
iptables-save > /etc/iptables/iptables.rules

if ipset list -n | grep -q "ru-blacklist"; then
ipset destroy ru-blacklist
fi

ipset save > /etc/ipset.conf

echo "The blacklist was successfully disabled"