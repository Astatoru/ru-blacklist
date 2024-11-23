#!/bin/bash

# Blacklist URL
URL="https://raw.githubusercontent.com/C24Be/AS_Network_List/refs/heads/main/blacklists/blacklist.txt"

# Download the blacklist
curl -o "ru-blacklist.txt" "$URL" &>/dev/null

# Check whether update was succsessful or not
if [ $? -eq 0 ]; then
    echo "The blacklist was successfully updated"
else
    echo "Update failed"
fi