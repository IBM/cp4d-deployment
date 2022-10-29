#!/bin/sh

set -x

yum update --disablerepo=* --enablerepo="*microsoft*"
yum install -y nfs-utils
yum install -y rpcbind
systemctl unmask firewalld
systemctl start firewalld
systemctl start nfs-server
systemctl enable nfs-server
mkdir -p /exports/home
echo "/exports/home *(rw,sync,subtree_check,no_root_squash)" >> /etc/exports
dataDisk=$(sudo lsblk | egrep -i "1T|2T" | awk '{print $1}')
mkfs.xfs /dev/$dataDisk
#mkfs.xfs /dev/sdc
sleep 10
mount /dev/$dataDisk /exports/home
#chown -R nfsnobody:nfsnobody /exports/home
chmod -R 777 /exports/home
exportfs -a
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload
echo "$(sudo blkid | grep /dev/$dataDisk | awk '{print $2}') /exports/home        xfs     defaults    0 0" >> /etc/fstab