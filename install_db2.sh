#!/bin/bash

DB2HOME=/opt/ibm/db2/V10.5
echo "VAGRANT_INSTALLER: Installing IBM DB2 database...."
cd /vagrant/

#Oracle installer present?
db2File=$(ls db2v11*.tar.gz)
if [ -f $db2File ];then
  chmod 777 $db2File
else
  echo -e "VAGRANT_INSTALLER: No DB2 installation file present... Exiting..."
  exit 1
fi

# This is needed because we must sync 64 bit packages to 32 bit ones
echo "VAGRANT_INSTALLER: Running yum update"
sudo yum update -y

echo "VAGRANT_INSTALLER: Running yum install with 32-bit compatibility libraries"
sudo yum install -y wget nfs-utils libaio* ksh compat-libstdc++* libstdc++* numactl.x86_64 pam.i686 install libstdc++.i686 kernel-develop

echo "VAGRANT_INSTALLER: Unarchiving db2 installer tar.gz to /tmp"
cp /vagrant/db2v11.1expressc.tar.gz /tmp
cd /tmp
tar -xvf db2v11.1expressc.tar.gz

# Launch the installer
echo "VAGRANT_INSTALLER: Running DB2 installer (db2_install)"
sudo /tmp/expc/db2_install -n -b $DB2HOME  -p expc -y

echo "VAGRANT_INSTALLER: Cleaning up /tmp installer files"
rm -r -f /tmp/expc/
rm /tmp/db2v11.1expressc.tar.gz

# Groups
echo "VAGRANT_INSTALLER: Creating required groups"
sudo groupadd -g 510 db2grp1
sudo groupadd -g 511 db2fgrp1
sudo groupadd -g 1999 db2iadm1
sudo groupadd -g 1998 db2fadm1
sudo groupadd -g 1997 dasadm1
sudo groupadd -g 1098 db2dev


# Users
echo "VAGRANT_INSTALLER: Creating required users"
# The -p argument is a bcryt'ed 'password'
sudo useradd -p rcOL8s6Vfbjw2 -g db2grp1 -m -d /home/db2inst1 db2inst1
sudo useradd -p rcOL8s6Vfbjw2 -g db2fgrp1 -m -d /home/db2fenc1 db2fenc1
sudo useradd -p rcOL8s6Vfbjw2 -g dasadm1 -m -d /home/dasusr1 dasusr1
sudo useradd -p rcOL8s6Vfbjw2 -g db2dev -m -d /home/db2user db2user

# Instance
echo "VAGRANT_INSTALLER: Creating the Database Instance"
sudo /opt/ibm/db2/V10.5/instance/db2icrt -a SERVER -p 50000 -u db2fenc1 db2inst1

# Das user
sudo /opt/ibm/db2/V10.5/instance/dascrt -u dasusr1

# Remote administration
echo "VAGRANT_INSTALLER: Add DB2 to /etc/services"
sudo cat /etc/services >> /vagrant/services
sudo echo 'ibm-db2 523/tcp # IBM DB2 DAS' >> /vagrant/services
sudo echo 'ibm-db2 523/udp # IBM DB2 DAS' >> /vagrant/services
sudo echo 'db2c_db2inst1 50000/tcp # IBM DB2 instance - db2inst1' >> /vagrant/services
sudo mv -f /vagrant/services /etc/services


echo "VAGRANT_INSTALLER: Set configuration options"
sudo -i -u db2inst1 $DB2HOME/bin/db2 update dbm cfg using SVCENAME db2c_db2inst1
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2set DB2COMM=tcpip
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2set DB2_EXTENDED_OPTIMIZATION=ON
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2set DB2_DISABLE_FLUSH_LOG=ON
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2set AUTOSTART=YES
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2set DB2_HASH_JOIN=Y
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2set DB2_PARALLEL_IO=*
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2set DB2CODEPAGE=1208
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2set DB2_COMPATIBILITY_VECTOR=3F
sudo -i -u db2inst1 $DB2HOME/bin/db2 update dbm cfg using INDEXREC ACCESS

# Start the instance
echo "VAGRANT_INSTALLER: Start the Database Instance"
sudo -i -u db2inst1 /home/db2inst1/sqllib/adm/db2start

# Start the administration server
echo "VAGRANT_INSTALLER: Start the administration server"
sudo -i -u dasusr1 /home/dasusr1/das/bin/db2admin stop
sudo -i -u dasusr1 /home/dasusr1/das/bin/db2admin start

# Autostart
echo "VAGRANT_INSTALLER: Configure DB2 to autostart when OS is started"
sudo -u root /home/db2inst1/sqllib/bin/db2iauto -on db2inst1

# Admin interface autostart
echo "VAGRANT_INSTALLER: Create administartion server startup script; /home/dasusr1/script/startadmin.sh"
sudo -u dasusr1 mkdir /home/dasusr1/script
sudo cp /vagrant/db2/startadmin.sh /home/dasusr1/script/
sudo chown dasusr1:dasadm1 -R /home/dasusr1/script
sudo chmod 777 /home/dasusr1/script/startadmin.sh

# Finalizing
echo "VAGRANT_INSTALLER: Set various helper options in profiles"
sudo cat /home/db2inst1/.bashrc >> /vagrant/db2/.bashrc
sudo echo '# Something useful for DB2' >> /vagrant/db2/.bashrc
sudo echo 'export PATH=/home/db2inst1/scripts:$PATH' >> /vagrant/db2/.bashrc
sudo echo 'export DB2CODEPAGE=1208' >> /vagrant/db2/.bashrc
sudo echo 'export PATH=/opt/ibm/db2/V10.5/bin:$PATH' >> /vagrant/db2/.bashrc
sudo mv -f /vagrant/db2/.bashrc /home/db2inst1/.bashrc

sudo cat /home/db2inst1/sqllib/db2profile >> /vagrant/db2/db2profile
sudo echo 'export DB2CODEPAGE=1208' >> /vagrant/db2/db2profile
sudo mv -f /vagrant/db2/db2profile /home/db2inst1/sqllib/db2profile

sudo cat /etc/profile >> /vagrant/db2/profile
sudo echo 'DB2INSTANCE=db2inst1' >> /vagrant/db2/profile
sudo echo 'export DB2INSTANCE' >> /vagrant/db2/profile
sudo echo 'INSTHOME=/home/db2inst1' >> /vagrant/db2/profile
sudo echo 'export DB2CODEPAGE=1208' >> /vagrant/db2/profile
sudo mv -f /vagrant/db2/profile /etc/profile

echo 'Setting up sample database'
sudo chmod 777 /vagrant/db2/setup_database.sh
sudo -i -u db2inst1 /vagrant/db2/setup_database.sh

echo "VAGRANT_INSTALLER: IBM DB2 database installation... Done..."