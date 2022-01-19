#!/bin/bash

hostnamectl set-hostname compute2
hostname
systemctl stop firewalld
systemctl status firewalld
systemctl disable firewalld
#vi /etc/sysconfig/selinux
#"disable SELINUX"
cd /etc/sysconfig/network-scripts
#vi ifcfg-ens33
#"change from dhcp to static"
#IPADDR=192.168.0.1/2/3
#NETMASK=255.255.255.0
service network restart
ip a s
cd ~

yum -y install rsh rsh-server
systemctl restart rsh.socket
systemctl restart rlogin.socket 
systemctl restart rexec.socket
systemctl enable rsh.socket 
systemctl enable rlogin.socket
systemctl enable rexec.socket
echo "\nmanagement 192.168.0.1\ncompute1 192.168.0.2\ncompute2 192.168.0.3" >> /etc/hosts
echo "\nmanagement\ncompute1" >> /etc/rhosts.equiv
echo "\nmanagement\ncompute1" >> /root/.rhosts
echo "\nrsh\nrexec\nrlogin" >> /etc/securetty

rpm –qa | grep openssh
yum –y install openssh-server openssh-clients openssh-libs
systemctl start sshd
systemctl status sshd
systemctl enable sshd
ssh-keygen
ssh-copy-id -i ~/.ssh/id_rsa.pub root@management
ssh-copy-id -i ~/.ssh/id_rsa.pub root@compute1

      
yum install -y nfs-utils nfs-utils-lib
systemctl start nfs-server rpcbind
systemctl enable nfs-server rpcbind
showmount -e 192.168.0.1
rpcinfo -p 192.168.0.1
mkdir /mnt/home
mount 192.168.0.1:/home /mnt/home
mount | grep nfs
df –hT
touch /mnt/home/test.txt
ls -l /mnt/home/
echo "\n192.168.0.1:/home /mnt/home nfs nosuid,rw,sync,hard,intr 0 0" >> /etc/fstab
mount -a

yum -y install yp-tools ypbind ypserv rpcbind
#vi  /etc/sysconfig/network
#NISDOMAIN=zchpc
#vi /etc/yp.conf 
#Domain name zchpc  
#Server  management
authconfig --enablenis --nisdomain=zchpc --nisserver=management --enablemkhomedir --update
systemctl start ypbind  
systemctl start  rpcbind
cd /usr/lib64/yp
./ypinit –s management
cd ~

ssh root@management
cd 6.0.1
scp contrib/systemd/pbs_mom.service root@compute2:/usr/lib/systemd/system/
scp torque-package-mom-linux-x86_64.sh root@compute2:/opt
scp torque-package-clients-linux-x86_64.sh root@compute2:/opt
ssh root@compute2
./torque-package-mom-linux-x86_64.sh --install
./torque-package-clients-linux-x86_64.sh --install
scp root@management:/etc/ld.so.conf.d/torque.conf / /etc/ld.so.conf.d/
ldconfig
echo "management" > /var/spool/torque/server_name
systemctl enable pbs_mom.service
systemctl start pbs_mom.service

#vi /usr/lib/systemd/system/httpd.service 
#PrivateTmp=false
systemctl daemon-reload
systemctl restart httpd

yum install ganglia ganglia-gmond
#vi /etc/ganglia/gmond.conf
                  #cluster {
                        #name = “my_cluster"
                        #}
                  #udp_send_channel {
                        #mcast_join = 239.2.11.71
                        #host = 192.168.0.1
                        #}
                  #udp_recv_channel {
                        #mcast_join = 239.2.11.71
                        #bind = 239.2.11.71
                        #}
                  #tcp_accept_channel {
                        #port = 8649
                        #}

systemctl start gmond
systemctl enable gmond

echo "\nexport PATH=/mnt/home/mpich2/bin:$PATH\nexport LD_LIBRARY_PATH="mnt/home/mpich2/lib:$LD_LIBRARY_PATH"" >> ~/.bashrc
source ~/.bashrc
mpirun
mpirun –f hosts –n 4 echo "hello world"
#mpicc -o objectOutputName c_CodeName.c
#mpirun –np 4 ./objectOutputName

echo "\nexport PATH=$PATH:/mnt/home/scilab/scilab-5.2.2/bin" >> ~/.bashrc
source ~/.bashrc
scilab
#mpirun -n 4 scilab-cli –f /path/to/the/scilabfile.sce