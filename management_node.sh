#!/bin/bash
su
cd ~
hostnamectl set-hostname management
hostname
systemctl stop firewalld
systemctl status firewalld
systemctl disable firewalld
echo "
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     disabled - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=enforcing
# SELINUXTYPE= can take one of three values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted


" > /etc/sysconfig/selinux
echo "TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="static"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="ens33"
UUID="66d91598-c587-4035-bfca-3f73470a046a"
DEVICE="ens33"
ONBOOT="yes"
IPADDR="192.168.0.1"
NETMASK="255.255.255.0"" > /etc/sysconfig/network-scripts/ifcfg-ens33
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
echo "192.168.0.1 management
192.168.0.2 compute1
192.168.0.3 compute2" >> /etc/hosts
echo "compute1
compute2" > /etc/rhosts.equiv
echo "compute1
compute2" > /root/.rhosts
echo "rsh
rexec
rlogin" >> /etc/securetty

rpm –qa | grep openssh
yum –y install openssh-server openssh-clients openssh-libs
systemctl start sshd
systemctl status sshd
systemctl enable sshd
ssh-keygen
ssh-copy-id -i ~/.ssh/id_rsa.pub root@compute1
ssh-copy-id -i ~/.ssh/id_rsa.pub root@compute2

nmcli d
yum install -y nfs-utils nfs-utils-lib
systemctl start nfs-server rpcbind
systemctl enable nfs-server rpcbind
mkdir home
echo "/home *(rw,insecure,no_root_squash,sync)" > /etc/exports
exportfs –a
systemctl restart nfs-server

yum -y install ypserv rpcbind cache nfs make ypbind portmap xinetd
rpm –qa ypserv
echo "# Created by anaconda
NETWORKING=yes
NETWORKING_IPVG=no
HOSTNAME=management
NISDOMAIN=zchpc" > /etc/sysconfig/network
echo "255.0.0.0 127.0.0.0
255.255.255.0 192.168.0.0" > /var/yp/securenets
systemctl start rpcbind ypserv ypxfrd yppasswdd
systemctl enable rpcbind ypserv ypxfrd yppasswdd
rpcinfo -u management ypserv
/usr/lib64/yp/ypinit –m
#"next host to add:" management
#"next host to add:" compute1
#"next host to add:" compute2
#"Ctrl + D key"
#The current list of NIS servers looks like this:
#management 
#compute1
#compute2
#"y key and Enter"
cd /var/yp
make
cd ~

yum install epel-release
yum -y install libtool openssl-devel libxml2-devel  boost-devel  gcc gcc-c++ git
git clone https://github.com/adaptivecomputing/torque.git -b 6.0.1 6.0.1
cd 6.0.1
./autogen.sh
./configure
make
make install
echo "management" > /var/spool/torque/server_name
echo "/usr/local/lib" > /etc/ld.so.conf.d/torque.conf
ldconfig
echo "compute1 np=1
compute2 np=1" >> /var/spool/torque/server_priv/nodes
cp contrib/systemd/trqauthd.service   /usr/lib/systemd/system/
systemctl enable trqauthd.service
systemctl start trqauthd.service
./torque.setup root
qterm
cp contrib/systemd/pbs_server.service   /usr/lib/systemd/system/
systemctl enable pbs_server.service
systemctl start pbs_server.service
cp contrib/systemd/ pbs_sched.service  /usr/lib/systemd/system/
systemctl enable pbs_sched.service
systemctl start pbs_sched.service
make packages
echo "[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
# We want systemd to give httpd some time to finish gracefully, but still want
# it to kill httpd after TimeoutStopSec if something went wrong during the
# graceful stop. Normally, Systemd sends SIGTERM signal right after the
# ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
# httpd time to finish.
KillSignal=SIGCONT
PrivateTmp=false

[Install]
WantedBy=multi-user.target" > /usr/lib/systemd/system/httpd.service
systemctl daemon-reload
systemctl restart httpd
pbsnodes -a

cd ~
yum install ganglia ganglia-gmetad ganglia-web ganglia-gmond
echo "# This is an example of a Ganglia Meta Daemon configuration file
#                http://ganglia.sourceforge.net/
#
#
#-------------------------------------------------------------------------------
# Setting the debug_level to 1 will keep daemon in the forground and
# show only error messages. Setting this value higher than 1 will make 
# gmetad output debugging information and stay in the foreground.
# default: 0
# debug_level 10
#
#-------------------------------------------------------------------------------
# What to monitor. The most important section of this file. 
#
# The data_source tag specifies either a cluster or a grid to
# monitor. If we detect the source is a cluster, we will maintain a complete
# set of RRD databases for it, which can be used to create historical 
# graphs of the metrics. If the source is a grid (it comes from another gmetad),
# we will only maintain summary RRDs for it.
#
# Format: 
# data_source "my cluster" [polling interval] address1:port addreses2:port ...
# 
# The keyword 'data_source' must immediately be followed by a unique
# string which identifies the source, then an optional polling interval in 
# seconds. The source will be polled at this interval on average. 
# If the polling interval is omitted, 15sec is asssumed. 
#
# If you choose to set the polling interval to something other than the default,
# note that the web frontend determines a host as down if its TN value is less
# than 4 * TMAX (20sec by default).  Therefore, if you set the polling interval
# to something around or greater than 80sec, this will cause the frontend to
# incorrectly display hosts as down even though they are not.
#
# A list of machines which service the data source follows, in the 
# format ip:port, or name:port. If a port is not specified then 8649
# (the default gmond port) is assumed.
# default: There is no default value
#
# data_source "my cluster" 10 localhost  my.machine.edu:8649  1.2.3.5:8655
# data_source "my grid" 50 1.3.4.7:8655 grid.org:8651 grid-backup.org:8651
# data_source "another source" 1.3.4.7:8655  1.3.4.8

data_source "my_cluster" 192.168.0.1

#
# Round-Robin Archives
# You can specify custom Round-Robin archives here (defaults are listed below)
#
# Old Default RRA: Keep 1 hour of metrics at 15 second resolution. 1 day at 6 minute
# RRAs "RRA:AVERAGE:0.5:1:244" "RRA:AVERAGE:0.5:24:244" "RRA:AVERAGE:0.5:168:244" "RRA:AVERAGE:0.5:672:244" \
#      "RRA:AVERAGE:0.5:5760:374"
# New Default RRA
# Keep 5856 data points at 15 second resolution assuming 15 second (default) polling. That's 1 day
# Two weeks of data points at 1 minute resolution (average)
#RRAs "RRA:AVERAGE:0.5:1:5856" "RRA:AVERAGE:0.5:4:20160" "RRA:AVERAGE:0.5:40:52704"

#
#-------------------------------------------------------------------------------
# Scalability mode. If on, we summarize over downstream grids, and respect
# authority tags. If off, we take on 2.5.0-era behavior: we do not wrap our output
# in <GRID></GRID> tags, we ignore all <GRID> tags we see, and always assume
# we are the "authority" on data source feeds. This approach does not scale to
# large groups of clusters, but is provided for backwards compatibility.
# default: on
# scalable off
#
#-------------------------------------------------------------------------------
# The name of this Grid. All the data sources above will be wrapped in a GRID
# tag with this name.
# default: unspecified
# gridname "MyGrid"
#
#-------------------------------------------------------------------------------
# The authority URL for this grid. Used by other gmetads to locate graphs
# for our data sources. Generally points to a ganglia/
# website on this machine.
# default: "http://hostname/ganglia/",
#   where hostname is the name of this machine, as defined by gethostname().
# authority "http://mycluster.org/newprefix/"
#
#-------------------------------------------------------------------------------
# List of machines this gmetad will share XML with. Localhost
# is always trusted. 
# default: There is no default value
# trusted_hosts 127.0.0.1 169.229.50.165 my.gmetad.org
#
#-------------------------------------------------------------------------------
# If you want any host which connects to the gmetad XML to receive
# data, then set this value to "on"
# default: off
# all_trusted on
#
#-------------------------------------------------------------------------------
# If you don't want gmetad to setuid then set this to off
# default: on
# setuid off
#
#-------------------------------------------------------------------------------
# User gmetad will setuid to (defaults to "nobody")
# default: "nobody"
setuid_username ganglia
#
#-------------------------------------------------------------------------------
# Umask to apply to created rrd files and grid directory structure
# default: 0 (files are public)
# umask 022
#
#-------------------------------------------------------------------------------
# The port gmetad will answer requests for XML
# default: 8651
# xml_port 8651
#
#-------------------------------------------------------------------------------
# The port gmetad will answer queries for XML. This facility allows
# simple subtree and summation views of the XML tree.
# default: 8652
# interactive_port 8652
#
#-------------------------------------------------------------------------------
# The number of threads answering XML requests
# default: 4
# server_threads 10
#
#-------------------------------------------------------------------------------
# Where gmetad stores its round-robin databases
# default: "/var/lib/ganglia/rrds"
# rrd_rootdir "/some/other/place"
#
#-------------------------------------------------------------------------------
# List of metric prefixes this gmetad will not summarize at cluster or grid level.
# default: There is no default value
# unsummarized_metrics diskstat CPU
#
#-------------------------------------------------------------------------------
# Prevent gmetad from generating summaries for sFlow VM metrics
# default: off
# unsummarized_sflow_vm_metrics on
#
#-------------------------------------------------------------------------------
# In earlier versions of gmetad, hostnames were handled in a case
# sensitive manner
# If your hostname directories have been renamed to lower case,
# set this option to 0 to disable backward compatibility.
# From version 3.2, backwards compatibility will be disabled by default.
# default: 1   (for gmetad < 3.2)
# default: 0   (for gmetad >= 3.2)
case_sensitive_hostnames 0

#-------------------------------------------------------------------------------
# It is now possible to export all the metrics collected by gmetad directly to
# graphite by setting the following attributes. 
#
# The hostname or IP address of the Graphite server
# default: unspecified
# carbon_server "my.graphite.box"
#
# The port and protocol on which Graphite is listening
# default: 2003
# carbon_port 2003
#
# default: tcp
# carbon_protocol udp
#
# **Deprecated in favor of graphite_path** A prefix to prepend to the 
# metric names exported by gmetad. Graphite uses dot-
# separated paths to organize and refer to metrics. 
# default: unspecified
# graphite_prefix "datacenter1.gmetad"
#
# A user-definable graphite path. Graphite uses dot-
# separated paths to organize and refer to metrics. 
# For reverse compatibility graphite_prefix will be prepended to this
# path, but this behavior should be considered deprecated.
# This path may include 3 variables that will be replaced accordingly:
# %s -> source (cluster name)
# %h -> host (host name)
# %m -> metric (metric name)
# default: graphite_prefix.%s.%h.%m
# graphite_path "datacenter1.gmetad.%s.%h.%m

# Number of milliseconds gmetad will wait for a response from the graphite server 
# default: 500
# carbon_timeout 500

#-------------------------------------------------------------------------------
# Memcached configuration (if it has been compiled in)
# Format documentation at http://docs.libmemcached.org/libmemcached_configuration.html
# default: ""
# memcached_parameters "--SERVER=127.0.0.1 --POOL-MIN=10 --POOL-MAX=32"
#
# Metrics will be stored in memcached as follows HOST/METRIC_NAME. If you
# want to include cluster name e.g. CLUSTER/HOST/METRIC_NAME set below value
# to 1
# default: 0
# memcached_include_cluster_in_key 0

#-------------------------------------------------------------------------------
# Riemann configuration (if enabled during build)
# Metrics can be forwarded to a Riemann event stream processor for real-time
# thresholding and alerting. See http://riemann.io/
#
# +-------------------+----------------+
# |  Ganglia          |  Riemann       |
# |-------------------|----------------|
# |  grid             |  grid          |
# |  cluster          |  cluster       |
# |  host             |  host*         |
# |  ip               |  ip            |
# |  metric           |  service*      |
# |  value(int,float) |  metric*       |
# |  type             |  (internal)    |
# |  units            |  description*  |
# |  value(string)    |  state*        |
# |  reported         |  time*         |
# |  tags(comma-sep)  |  tags*         |
# |  location         |  location      |
# |  tmax             |  ttl*          |
# +-------------------+----------------+
#
# Note: attributes with a star (*) are standard Riemann fields
#
# The hostname or IP address of the Riemann server
# default: unspecified
# riemann_server "my.riemann.box"
#
# The port and protocol on which Riemann is listening
# default: 5555
# riemann_port 5555
#
# default: udp
# riemann_protocol tcp
#
# List of arbitrary key-value pairs to be used as event attributes in
# addition to those listed above.
#
# default: undefined
# riemann_attributes "key=val[,...]"
# riemann_attributes "customer=Acme Corp,environment=PROD"
" > /etc/ganglia/gmetad.conf
echo "/* This configuration is as close to 2.5.x default behavior as possible
   The values closely match ./gmond/metric.h definitions in 2.5.x */
globals {
  daemonize = yes
  setuid = yes
  user = ganglia
  debug_level = 0
  max_udp_msg_len = 1472
  mute = no
  deaf = no
  allow_extra_data = yes
  host_dmax = 86400 /*secs. Expires (removes from web interface) hosts in 1 day */
  host_tmax = 20 /*secs */
  cleanup_threshold = 300 /*secs */
  gexec = no
  # By default gmond will use reverse DNS resolution when displaying your hostname
  # Uncommeting following value will override that value.
  # override_hostname = "mywebserver.domain.com"
  # If you are not using multicast this value should be set to something other than 0.
  # Otherwise if you restart aggregator gmond you will get empty graphs. 60 seconds is reasonable
  send_metadata_interval = 0 /*secs */

}

/*
 * The cluster attributes specified will be used as part of the <CLUSTER>
 * tag that will wrap all hosts collected by this instance.
 */
cluster {
  name = "my_cluster"
  owner = "unspecified"
  latlong = "unspecified"
  url = "unspecified"
}

/* The host section describes attributes of the host, like the location */
host {
  location = "unspecified"
}

/* Feel free to specify as many udp_send_channels as you like.  Gmond
   used to only support having a single channel */
udp_send_channel {
  #bind_hostname = yes # Highly recommended, soon to be default.
                       # This option tells gmond to use a source address
                       # that resolves to the machine's' hostname.  Without
                       # this, the metrics may appear to come from any
                       # interface and the DNS names associated with
                       # those IPs will be used to create the RRDs.
  mcast_join = 239.2.11.71
  host = 192.168.0.1
  port = 8649
  ttl = 1
}

/* You can specify as many udp_recv_channels as you like as well. */
udp_recv_channel {
  mcast_join = 239.2.11.71
  port = 8649
  bind = 239.2.11.71
  retry_bind = true
  # Size of the UDP buffer. If you are handling lots of metrics you really
  # should bump it up to e.g. 10MB or even higher.
  # buffer = 10485760
}

/* You can specify as many tcp_accept_channels as you like to share
   an xml description of the state of the cluster */
tcp_accept_channel {
  port = 8649
  # If you want to gzip XML output
  gzip_output = no
}

/* Channel to receive sFlow datagrams */
#udp_recv_channel {
#  port = 6343
#}

/* Optional sFlow settings */
#sflow {
# udp_port = 6343
# accept_vm_metrics = yes
# accept_jvm_metrics = yes
# multiple_jvm_instances = no
# accept_http_metrics = yes
# multiple_http_instances = no
# accept_memcache_metrics = yes
# multiple_memcache_instances = no
#}

/* Each metrics module that is referenced by gmond must be specified and
   loaded. If the module has been statically linked with gmond, it does
   not require a load path. However all dynamically loadable modules must
   include a load path. */
modules {
  module {
    name = "core_metrics"
  }
  module {
    name = "cpu_module"
    path = "modcpu.so"
  }
  module {
    name = "disk_module"
    path = "moddisk.so"
  }
  module {
    name = "load_module"
    path = "modload.so"
  }
  module {
    name = "mem_module"
    path = "modmem.so"
  }
  module {
    name = "net_module"
    path = "modnet.so"
  }
  module {
    name = "proc_module"
    path = "modproc.so"
  }
  module {
    name = "sys_module"
    path = "modsys.so"
  }
}

/* The old internal 2.5.x metric array has been replaced by the following
   collection_group directives.  What follows is the default behavior for
   collecting and sending metrics that is as close to 2.5.x behavior as
   possible. */

/* This collection group will cause a heartbeat (or beacon) to be sent every
   20 seconds.  In the heartbeat is the GMOND_STARTED data which expresses
   the age of the running gmond. */
collection_group {
  collect_once = yes
  time_threshold = 20
  metric {
    name = "heartbeat"
  }
}

/* This collection group will send general info about this host*/
collection_group {
  collect_every = 60
  time_threshold = 60
  metric {
    name = "cpu_num"
    title = "CPU Count"
  }
  metric {
    name = "cpu_speed"
    title = "CPU Speed"
  }
  metric {
    name = "mem_total"
    title = "Memory Total"
  }
  metric {
    name = "swap_total"
    title = "Swap Space Total"
  }
  metric {
    name = "boottime"
    title = "Last Boot Time"
  }
  metric {
    name = "machine_type"
    title = "Machine Type"
  }
  metric {
    name = "os_name"
    title = "Operating System"
  }
  metric {
    name = "os_release"
    title = "Operating System Release"
  }
  metric {
    name = "location"
    title = "Location"
  }
}

/* This collection group will send the status of gexecd for this host
   every 300 secs.*/
/* Unlike 2.5.x the default behavior is to report gexecd OFF. */
collection_group {
  collect_once = yes
  time_threshold = 300
  metric {
    name = "gexec"
    title = "Gexec Status"
  }
}

/* This collection group will collect the CPU status info every 20 secs.
   The time threshold is set to 90 seconds.  In honesty, this
   time_threshold could be set significantly higher to reduce
   unneccessary  network chatter. */
collection_group {
  collect_every = 20
  time_threshold = 90
  /* CPU status */
  metric {
    name = "cpu_user"
    value_threshold = "1.0"
    title = "CPU User"
  }
  metric {
    name = "cpu_system"
    value_threshold = "1.0"
    title = "CPU System"
  }
  metric {
    name = "cpu_idle"
    value_threshold = "5.0"
    title = "CPU Idle"
  }
  metric {
    name = "cpu_nice"
    value_threshold = "1.0"
    title = "CPU Nice"
  }
  metric {
    name = "cpu_aidle"
    value_threshold = "5.0"
    title = "CPU aidle"
  }
  metric {
    name = "cpu_wio"
    value_threshold = "1.0"
    title = "CPU wio"
  }
  metric {
    name = "cpu_steal"
    value_threshold = "1.0"
    title = "CPU steal"
  }
  /* The next two metrics are optional if you want more detail...
     ... since they are accounted for in cpu_system.
  metric {
    name = "cpu_intr"
    value_threshold = "1.0"
    title = "CPU intr"
  }
  metric {
    name = "cpu_sintr"
    value_threshold = "1.0"
    title = "CPU sintr"
  }
  */
}

collection_group {
  collect_every = 20
  time_threshold = 90
  /* Load Averages */
  metric {
    name = "load_one"
    value_threshold = "1.0"
    title = "One Minute Load Average"
  }
  metric {
    name = "load_five"
    value_threshold = "1.0"
    title = "Five Minute Load Average"
  }
  metric {
    name = "load_fifteen"
    value_threshold = "1.0"
    title = "Fifteen Minute Load Average"
  }
}

/* This group collects the number of running and total processes */
collection_group {
  collect_every = 80
  time_threshold = 950
  metric {
    name = "proc_run"
    value_threshold = "1.0"
    title = "Total Running Processes"
  }
  metric {
    name = "proc_total"
    value_threshold = "1.0"
    title = "Total Processes"
  }
}

/* This collection group grabs the volatile memory metrics every 40 secs and
   sends them at least every 180 secs.  This time_threshold can be increased
   significantly to reduce unneeded network traffic. */
collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "mem_free"
    value_threshold = "1024.0"
    title = "Free Memory"
  }
  metric {
    name = "mem_shared"
    value_threshold = "1024.0"
    title = "Shared Memory"
  }
  metric {
    name = "mem_buffers"
    value_threshold = "1024.0"
    title = "Memory Buffers"
  }
  metric {
    name = "mem_cached"
    value_threshold = "1024.0"
    title = "Cached Memory"
  }
  metric {
    name = "swap_free"
    value_threshold = "1024.0"
    title = "Free Swap Space"
  }
}

collection_group {
  collect_every = 40
  time_threshold = 300
  metric {
    name = "bytes_out"
    value_threshold = 4096
    title = "Bytes Sent"
  }
  metric {
    name = "bytes_in"
    value_threshold = 4096
    title = "Bytes Received"
  }
  metric {
    name = "pkts_in"
    value_threshold = 256
    title = "Packets Received"
  }
  metric {
    name = "pkts_out"
    value_threshold = 256
    title = "Packets Sent"
  }
}

/* Different than 2.5.x default since the old config made no sense */
collection_group {
  collect_every = 1800
  time_threshold = 3600
  metric {
    name = "disk_total"
    value_threshold = 1.0
    title = "Total Disk Space"
  }
}

collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "disk_free"
    value_threshold = 1.0
    title = "Disk Space Available"
  }
  metric {
    name = "part_max_used"
    value_threshold = 1.0
    title = "Maximum Disk Space Used"
  }
}

include ("/etc/ganglia/conf.d/*.conf")
" > /etc/ganglia/gmond.conf
systemctl start httpd
systemctl enable httpd
systemctl start gmond
systemctl enable gmond
systemctl start gmetad
systemctl enable gmetad
echo "#
# Ganglia monitoring system php web frontend
#

Alias /ganglia /usr/share/ganglia

<Location /ganglia>
  # Order deny,allow
  # Deny from all
  # Allow from 127.0.0.1
  # Allow from ::1
  # Allow from .example.com
  Require all granted
</Location>" > /etc/httpd/conf.d/ganglia.conf

wget http://www.mpich.org/static/downloads/3.1.4/mpich-3.1.4.tar.gz
yum install gcc gcc-c++ kernel-devel -y
tar xvf mpich-3.1.4.tar.gz
mkdir mpich2
cd mpich-3.1.4
./configure --prefix=/home/mpich2 --disable-fortran
make
make install
ls
cd ../
ls
cd mpich2/
ls
cd bin/
ls
cd ../
echo "export PATH=/home/mpich2/bin:$PATH
export LD_LIBRARY_PATH="home/mpich2/lib:$LD_LIBRARY_PATH"" >> ~/.bashrc
source ~/.bashrc
mpirun
cd /home/
mkdir projects
cd projects
echo "192.168.0.1
192.168.0.2
192.168.0.3" >> hosts
mpirun –f hosts –n 4 echo “hello world”
#"Create c program using vi and save"
#"Compile your code as:""
#mpicc -o objectOutputName c_CodeName.c
#mpirun –np 4 ./objectOutputName
cd ~
mkdir /home/scilab
cd /home/scilab/
wget http://www.scilab.org/download/5.5.2/scilab-5.2.2.bin.linux-x86_64.tar.gz
tar xzvf scilab-5.2.2.bin.linux-x86_64.tar.gz
cd /scilab-5.2.2/
./bin/scilab
echo "export PATH=$PATH:/home/scilab/scilab-5.2.2/bin" >> ~/.bashrc
source ~/.bashrc
scilab
#mpirun -n 4 scilab-cli –f /path/to/the/scilabfile.sce