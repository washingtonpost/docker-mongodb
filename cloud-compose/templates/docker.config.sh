# docker.config.sh
groupadd docker
usermod -aG docker {{ aws.username }}
cat << EOF > /usr/lib/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/docker
EnvironmentFile=-/etc/sysconfig/docker-storage
EnvironmentFile=-/etc/sysconfig/docker-network
Environment=GOTRACEBACK=crash
ExecStart=/usr/bin/docker daemon --exec-opt native.cgroupdriver=cgroupfs \$other_args \$DOCKER_STORAGE_OPTIONS \$DOCKER_NETWORK_OPTIONS
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
MountFlags=slave

[Install]
WantedBy=multi-user.target
EOF

# docker.start
systemctl daemon-reload
chkconfig docker on
systemctl enable docker
service docker start

