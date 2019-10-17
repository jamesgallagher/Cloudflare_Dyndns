#!/bin/bash

# CHECK IF JQ IS INSTALLED
if [ "$(which jq)" = "" ] ;then
	echo "This script requires jq to be install, please resolve and try again. Try yum/apt-get/brew install jq"
	exit 1
fi

# CHECK IF CONFIG EXISTS
FILE=./config.ini
if ! [ -f "$FILE" ]; then
    echo "$FILE does not exist. Try and remane config.ini-default with your settings to $FILE."
    exit 1
fi

#LOAD CONFIG FILE
. ./config.ini

# MAYBE CHANGE THESE
ip=$(curl -s http://ipv4.icanhazip.com)
ip_file="ip.txt"
id_file="cloudflare.ids"
log_file="cloudflare.log"

# LOGGER
log() {
	if [ "$1" ]; then
		echo -e "[$(date)] - $1" >> $log_file
	fi
}

# SCRIPT START
log "Check Initiated"

if [ -f $ip_file ]; then
	old_ip=$(cat $ip_file)
	

	if [[ $ip == $old_ip ]]; then
	        echo "IP has not changed."
			        exit 0
	fi
fi


if [[ -f $id_file ]] && [[ $(wc -l $id_file | cut -d " " -f 1) == 2 ]]; then
	zone_identifier=$(head -1 $id_file)
	record_identifier=$(tail -1 $id_file)
else
	zone_identifier=$(curl -s -X GET "https://api.Cloudflare.com/client/v4/zones/?name=$zone_name" /
							-H "X-Auth-Email: $auth_email" /
							-H "X-Auth-Key: $auth_key" /
							-H "Content-Type: application/json" | jq -r '.result[] | "\(.id)"')

	record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" /
							-H "X-Auth-Email: $auth_email" /
							-H "X-Auth-Key: $auth_key" /
							-H "Content-Type: application/json"  | jq -r '.result[] | "\(.id)"')
	
	echo "$zone_identifier" > $id_file
	echo "$record_identifier" >> $id_file
fi	

update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" /
				-H "X-Auth-Email: $auth_email" /
				-H "X-Auth-Key: $auth_key" /
				-H "Content-Type: application/json" --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\"}")

if [[ $update == *"\"success\":false"* ]]; then
	message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
	log "$message"
	echo -e "$message"
	exit 1 
else
	message="IP changed to: $ip"
	echo "$ip" > $ip_file
	log "$message"
	echo "$message"
fi
