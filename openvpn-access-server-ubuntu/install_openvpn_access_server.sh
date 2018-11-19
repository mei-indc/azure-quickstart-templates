#!/bin/bash
userPassword=$1

#download the packages
cd /tmp
wget -c http://swupdate.openvpn.org/as/openvpn-as-2.1.9-Ubuntu16.amd_64.deb
#download predefined access serever settings files
wget -c https://raw.githubusercontent.com/kunalpatwardhan/azure-quickstart-templates/master/openvpn-access-server-ubuntu/as.conf.bak
wget -c https://raw.githubusercontent.com/kunalpatwardhan/azure-quickstart-templates/master/openvpn-access-server-ubuntu/certs.db.bak
wget -c https://raw.githubusercontent.com/kunalpatwardhan/azure-quickstart-templates/master/openvpn-access-server-ubuntu/config.db.bak
wget -c https://raw.githubusercontent.com/kunalpatwardhan/azure-quickstart-templates/master/openvpn-access-server-ubuntu/log.db.bak
wget -c https://raw.githubusercontent.com/kunalpatwardhan/azure-quickstart-templates/master/openvpn-access-server-ubuntu/userprop.db.bak
#download nginx default site enabled configuration
wget -c https://raw.githubusercontent.com/kunalpatwardhan/azure-quickstart-templates/master/openvpn-access-server-ubuntu/default

#install the software
sudo dpkg -i openvpn-as-2.1.9-Ubuntu16.amd_64.deb

#update the password for user openvpn
sudo echo "openvpn:$userPassword"|sudo chpasswd

#configure server network settings
PUBLICIP=$(curl -s ifconfig.me)

#install nginx
sudo apt-get update
sudo apt-get install nginx -y

#install sqlite3
sudo apt-get install sqlite3 -y

sudo su
#backup existing access server configuraion
cd /usr/local/openvpn_as/
./bin/sqlite3 ./etc/db/config.db .dump > ./config.db.bak
./bin/sqlite3 ./etc/db/certs.db .dump > ./certs.db.bak
./bin/sqlite3 ./etc/db/userprop.db .dump > ./userprop.db.bak
./bin/sqlite3 ./etc/db/log.db .dump > ./log.db.bak
cp ./etc/as.conf ./as.conf.bak

#copy predefined access serever settings files
service openvpnas stop
cd /usr/local/openvpn_as/
rm ./etc/db/config.db
rm ./etc/db/certs.db
#rm ./etc/db/userprop.db
rm ./etc/db/log.db
rm ./etc/as.conf
./bin/sqlite3 </tmp/config.db.bak ./etc/db/config.db
./bin/sqlite3 </tmp/certs.db.bak ./etc/db/certs.db
./bin/sqlite3 </tmp/userprop.db.bak ./etc/db/userprop_template.db
./bin/sqlite3 </tmp/log.db.bak ./etc/db/log.db
cp /tmp/as.conf.bak ./etc/as.conf
service openvpnas start

#change required access server settings
sudo sqlite3 "/usr/local/openvpn_as/etc/db/config.db" "update config set value='$PUBLICIP' where name='host.name';"

sudo ./bin/sqlite3 "/usr/local/openvpn_as/etc/db/userprop.db" <<EOS
ATTACH "/usr/local/openvpn_as/etc/db/userprop_template.db" AS db2;
INSERT INTO config SELECT * FROM db2.config WHERE profile_id = 3;
EOS

service nginx stop
#copy nginx default site enabled configuration
cp /tmp/default /etc/nginx/sites-enabled/default
service nginx start
sudo systemctl restart nginx


#restart OpenVPN AS service
sudo systemctl restart openvpnas

