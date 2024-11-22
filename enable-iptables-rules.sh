#!/bin/bash

if [ $(id -u) -ne 0 ]
  then echo "Please run this script as root or using sudo"
  exit
fi

# Backup current iptables rules
if [ ! -d "iptables-backup" ]; then
  mkdir "iptables-backup"
fi
iptables-save > "iptables-backup/iptables_enable-iptables-rules.rules"

# SSH
if ! iptables -C INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT 2>/dev/null; then
	iptables -I INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
fi

# Local interface
if ! iptables -C INPUT -i lo -j ACCEPT 2>/dev/null; then
	iptables -A INPUT -i lo -j ACCEPT
fi
if ! iptables -C OUTPUT -o lo -j ACCEPT 2>/dev/null; then
	iptables -A OUTPUT -o lo -j ACCEPT
fi

# Incoming connections related to already established connections
if ! iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
	iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
fi

# HTTP; HTTPS
if ! iptables -C INPUT -p tcp -m multiport --dports 80,443,8443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT 2>/dev/null; then
	iptables -A INPUT -p tcp -m multiport --dports 80,443,8443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
fi

# X-UI web panel
if ! iptables -C INPUT -p tcp --dport 11111 -j ACCEPT 2>/dev/null; then
	iptables -A INPUT -p tcp --dport 11111 -j ACCEPT
fi

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP

# Save rules
if [ ! -d "/etc/iptables" ]; then
  mkdir "/etc/iptables"
fi
iptables-save > /etc/iptables/iptables.rules
echo "Iptables rules were applied"