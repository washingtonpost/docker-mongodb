# docker.config.sh
groupadd docker
usermod -aG docker {{ aws.username }}
{%- if ami is defined and ami == "docker:1.10" %}
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
{%- else %}
cat << EOF > /usr/lib/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network.target

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/docker-storage
ExecStart=/usr/bin/dockerd \$DOCKER_STORAGE_OPTIONS
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
{%- endif %}

# docker.start
systemctl daemon-reload
chkconfig docker on
systemctl enable docker
service docker start
