#!/bin/bash
set -x
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/tflog.out 2>&1

EXTERNAL_IP=$(curl -s -m 10 http://whatismyip.akamai.com/)
REDIS_CONFIG_FILE=/etc/redis.conf
SENTINEL_CONFIG_FILE=/etc/sentinel.conf

# Setup firewall rules
firewall-offline-cmd --zone=public --add-port=${redis_port1}/tcp
firewall-offline-cmd --zone=public --add-port=${redis_port2}/tcp
firewall-offline-cmd --zone=public --add-port=${sentinel_port}/tcp
firewall-offline-cmd --zone=public --add-port=${redis_exporter_port}/tcp
systemctl restart firewalld

# Config sysctl.conf
sysctl vm.overcommit_memory=1
cat << EOF > /etc/sysctl.conf
vm.swappiness = 1
vm.overcommit_memory = 1
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
EOF

# Install wget and gcc
%{ if redis_version == "6.0.9" ~}
yum install -y wget devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-binutils
scl enable devtoolset-9 bash
#source /opt/rh/devtoolset-9/enable
echo "source /opt/rh/devtoolset-9/enable" >> /etc/profile
%{ else ~}
yum install -y wget gcc
%{ endif ~}

# Download and compile Redis
wget http://download.redis.io/releases/redis-${redis_version}.tar.gz
tar xvzf redis-${redis_version}.tar.gz
cd redis-${redis_version}
#%{ if redis_version == "6.0.9" ~}
#make MALLOC=libc
#%{ endif ~}
make install

mkdir -p /u01/redis_data
mkdir -p /var/log/redis/

# Configure Redis
cat << EOF > $REDIS_CONFIG_FILE
port ${redis_port1}
logfile /var/log/redis/redis.log
dir /u01/redis_data
pidfile /var/run/redis/redis.pid
%{ if redis_deployment_type == "Redis Cluster" ~}
cluster-enabled yes
cluster-config-file /etc/nodes.conf
cluster-node-timeout 5000
cluster-slave-validity-factor 0
cluster-announce-ip $EXTERNAL_IP
cluster-migration-barrier 2
%{ endif ~}
%{ if redis_config_is_use_rdb ~}
save 900 1
save 300 10
save 60 10000
dbfilename dump.rdb
%{ endif ~}
%{ if redis_config_is_use_aof ~}
appendonly yes
%{ else ~}
appendonly no
%{ endif ~}
requirepass ${redis_password}
masterauth ${redis_password}
EOF

cat << EOF > /etc/systemd/system/redis.service
[Unit]
Description=Redis

[Service]
User=root
ExecStart=/usr/local/bin/redis-server /etc/redis.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable redis.service

mkdir -p /var/run/redis/
# Configure Sentinel
cat << EOF > $SENTINEL_CONFIG_FILE
port ${sentinel_port}
logfile "/var/log/redis/sentinel.log"
dir "/tmp"
pidfile "/var/run/redis/sentinel.pid"
protected-mode no
sentinel deny-scripts-reconfig yes
%{ for i in range(1) ~}
sentinel monitor ${master_fqdn[0]}.${redis_domain} ${master_private_ips[0]} ${redis_port1} 2
sentinel down-after-milliseconds ${master_fqdn[0]}.${redis_domain} 60000
sentinel failover-timeout ${master_fqdn[0]}.${redis_domain} 180000
sentinel auth-pass ${master_fqdn[0]}.${redis_domain} ${redis_password}
sentinel parallel-syncs ${master_fqdn[0]}.${redis_domain} 1
%{ endfor ~}
EOF

cat << EOF > /etc/systemd/system/sentinel.service
[Unit]
Description=Redis

[Service]
User=root
ExecStart=/usr/local/bin/redis-sentinel /etc/sentinel.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

# Install Redis Exporter
%{ if is_use_prometheus ~}
useradd --no-create-home --shell /bin/false redis-exporter
wget https://github.com/oliver006/redis_exporter/releases/download/v1.37.0/redis_exporter-v1.37.0.linux-amd64.tar.gz
tar xvfz redis_exporter-v1.37.0.linux-amd64.tar.gz
chmod +x redis_exporter-v1.37.0.linux-amd64/redis_exporter
mv redis_exporter-v1.37.0.linux-amd64/redis_exporter /usr/local/bin/redis_exporter
cat << EOF > /etc/systemd/system/redis-exporter.service
[Unit]
Description=Redis Exporter

[Service]
User=redis-exporter
ExecStart=/usr/local/bin/redis_exporter -redis.addr redis://127.0.0.1:${redis_port1} -redis.password ${redis_password}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable redis-exporter.service
systemctl start redis-exporter.service
%{ endif ~}

# Install s3fs
yum install -y s3fs-fuse
chmod +x /usr/bin/fusermount
echo "${s3_access_key}:${s3_secret_key}" > /root/.passwd-s3fs
chmod 600 /root/.passwd-s3fs
s3fs RedisBucket /u01/redis_backup_snapshot -o endpoint=ap-chuncheon-1 -o passwd_file=/root/.passwd-s3fs -o url=https://sehubjapacprod.compat.objectstorage.ap-chuncheon-1.oraclecloud.com/ -o nomultipart -o use_path_request_style
echo "RedisBucket /u01/redis_backup_snapshot fuse.s3fs _netdev,allow_other,multipart,use_path_request_style,endpoint=ap-chuncheon-1,url=https://sehubjapacprod.compat.objectstorage.ap-chuncheon-1.oraclecloud.com/ 0 0" >> /etc/fstab

sleep 30

%{ if redis_version == "6.0.9" ~}
sleep 600
%{ endif ~}