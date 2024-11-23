#!/bin/bash

if [ $(id -u) -ne 0 ]
  then echo "Please run this script as root or using sudo"
  exit
fi

# Backup current iptables rules
if [ ! -d "iptables-backup" ]; then
  mkdir "iptables-backup"
fi
if [ -f "iptables-backup/iptables.rules" ]; then
	mv "iptables-backup/iptables.rules" "iptables-backup/iptables_old.rules"
fi
iptables-save > "iptables-backup/iptables.rules"

# SSH
read -p "Enter the ssh port number to add the rule (default 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}
if ! iptables -C INPUT -p tcp --dport $SSH_PORT -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT 2>/dev/null; then
	iptables -A INPUT -p tcp --dport $SSH_PORT -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
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
read -p "Enter the X-UI web panel port number to add the rule (empty if none): " XUI_PORT
if [ -n "$XUI_PORT" ]; then
    if ! iptables -C INPUT -p tcp --dport "$XUI_PORT" -j ACCEPT 2>/dev/null; then
        iptables -A INPUT -p tcp --dport "$XUI_PORT" -j ACCEPT
    fi
else
    echo "No port entered, skipping rule addition for X-UI web panel"
fi

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP

# Save rules
if [ ! -d "/etc/iptables" ]; then
  mkdir "/etc/iptables"
fi
iptables-save > /etc/iptables/iptables.rules
echo "iptables rules were successfully applied"
