#!/bin/bash
# (c) Red Haired!

# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NO_COLOR='\033[0m'

#Check if Nmap is Installed or not in a machine
if ! which nmap >/dev/null; then
    echo -e "$RED Sorry Can't Run!\nNmap is not installed!"
    echo -e "$GREEN\nIt can be installed in debian based linux with the command$BLUE\n-->apt install nmap"
    echo -e "$GREEN In arch based linux System with the command$BLUE\n-->pacman -S nmap\n$NO_COLOR"
    return;
fi

# Check if the script is being run as superuser
if [ "$EUID" -ne 0 ]; then
    echo -e "$RED This script should be run as root user!"
    return;
fi
dhcp_lease_file_location="/var/lib/dhcp/dhcpd.leases"

# will return eth0,wlan0,ens33 or whatever the default Interface is
default_interface=$(ip route | awk '/default/ {print $5}')
ip_and_cidr=$(ip -o -f inet addr show $default_interface | awk '{print $4}')
ip_range=$(echo $ip_and_cidr | sed 's/\.[0-9]*\//.0\//')

echo -e "$GREEN\nRunning nmap -sn $ip_range to get a list of all IP addresses\n"
readarray -t ips < <(nmap -sn $ip_range | awk '/Nmap scan report/{gsub(/[()]/,""); print $NF}' | sort -t . -n -k 1,1 -k 2,2 -k 3,3 -k 4,4)

# Set column widths
col1=14
col2=17
col3=17
col4=15
col5=27


echo -e "$YELLOW\nChecking each IP address for MAC ADDRESS, HOSTNAME ,WORKGROUP or Domain, Manufacturer info in a Network\n"

# Format the output
printf "%-${col1}s | %-${col2}s | %-${col3}s | %-${col4}s | %-${col5}s \n" "IP ADDRESS" "MAC ADDRESS" "HOSTNAME" "WG-DOMAIN" "MANUFACTURER"
printf "%-${col1}s | %-${col2}s | %-${col3}s | %-${col4}s | %-${col5}s \n" "$(printf '%.s-' {1..13})" "$(printf '%.s-' {1..17})" "$(printf '%.s-' {1..17})" "$(printf '%.s-' {1..15})" "$(printf '%.s-' {1..30})"

for IP in "${ips[@]}"
do
  # Run the nmap command for the current IP
  OUTPUT="$(nmap --script nbstat.nse -p 137,139 $IP)"
  # Extract the necessary information from the scan!
  MACADDRESS=$(echo "$OUTPUT" | grep 'MAC Address' | awk '{print $3}')
  HOSTNAME=$(echo "$OUTPUT" | grep '<20>.*<unique>.*<active>' | awk -F'[|<]' '{print $2}' | tr -d '_' | xargs)
  WG_DOMAIN=$(echo "$OUTPUT" | grep -v '<permanent>' | grep '<00>.*<group>.*<active>' | awk -F'[|<]' '{print $2}' | tr -d '_' | xargs)
  MANUFACTURER=$(echo "$OUTPUT" | grep 'MAC Address' | awk -F'(' '{print $2}' | cut -d ')' -f1)

  # if a dhcp server leases file exists on the machine, we will query it for a hostname if not already returned by nmap
  if [ -f "$dhcp_lease_file_location" ]; then
    # If HOSTNAME is empty,it fetch HOSTNAME from dhcpd.leases
    if [ -z "$HOSTNAME" ]; then
      HOSTNAME=$(awk -v ip="$IP" '$1 == "lease" && $2 == ip {f=1} f && /client-hostname/ {print substr($2, 2, length($2) - 3); exit}' "$dhcp_lease_file_location" | cut -c 1-15)

      # Add an asterisk (*) if HOSTNAME has a value
      if [ -n "$HOSTNAME" ]; then
        HOSTNAME="$HOSTNAME *"
      fi
    fi
  fi

  # Print a row of data for the current IP
  printf "%-${col1}s | %-${col2}s | %-${col3}s | %-${col4}s | %-${col5}s \n" "$IP" "$MACADDRESS" "$HOSTNAME" "$WG_DOMAIN" "$MANUFACTURER"
done

if [ -f "$dhcp_lease_file_location" ]; then
  echo -e "\n$RED Asterik (*) to the right of hostname indicates the hostname could not be acquired from nmap so was pulled from $dhcp_lease_file_location\n"
fi


echo -e "$RED\tThis network scanner script is provided free of charge by Red Haired!/Github:umesh-hamal\n"

