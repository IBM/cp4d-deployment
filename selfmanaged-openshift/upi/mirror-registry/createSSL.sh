#! /bin/bash

#Change to your company details

HOSTNAME=`hostname`
Countrycode=$(grep countrycode ./certificate | awk -F "=" '{print $2}')
State=$(grep state ./certificate | awk -F "=" '{print $2}')
Locality=$(grep locality ./certificate | awk -F "=" '{print $2}')
Organization=$(grep organization ./certificate | awk -F "=" '{print $2}')
OrganizationalUnit=$(grep unit ./certificate | awk -F "=" '{print $2}')
CommonName=$HOSTNAME
EMAIL="$1"

# Genearte SSL cert and key
echo  "Generate a self-signed certificate"
sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/domain.key -x509 -days 365 -out /opt/registry/certs/domain.crt \
-subj "/C=$Countrycode/ST=$State/L=$Locality/O=$Organization/OU=$OrganizationalUnit/CN=$CommonName/emailAddress=$EMAIL"
