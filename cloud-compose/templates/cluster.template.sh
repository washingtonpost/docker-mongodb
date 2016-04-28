#!/bin/bash
{%- if _node_id is defined %}
NODE_ID={{ _node_id }}
{%- endif %}

## Disable transparent huge pages for Mongo.
cat <<- 'EOF' >> /etc/rc.local
if test -f /sys/kernel/mm/transparent_hugepage/khugepaged/defrag; then
  echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
EOF

# system.mounts
{%- for volume in aws.volumes %}

{%- if volume.meta and volume.meta.format and not volume.snapshot %}
mkfs -t {{ volume.file_system }} {{ volume.block }}
{%- endif %}

{%- if volume.meta and volume.meta.mount %}
echo -e '{{ volume.block }}\t{{ volume.meta.mount }}\t{{ volume.file_system }}\t{{ volume.meta.options|default("defaults,noatime", true) }}\t0\t0' >> /etc/fstab
mkdir -p {{ volume.meta.mount }}
mount {{ volume.meta.mount }}
{%- endif %}

{%- if volume.snapshot %}
resize2fs {{ volume.block }}
{%- endif %}

{%- if volume.file_system and volume.file_system == "lvm2" %}
systemctl enable lvm2-lvmetad.service
systemctl enable lvm2-lvmetad.socket
systemctl start lvm2-lvmetad.service
systemctl start lvm2-lvmetad.socket
pvcreate {{ volume.block }}
vgcreate {{ volume.meta.group}}  {{ volume.block }}
{%- for logical_volume in volume.meta.volumes %}
lvcreate -L {{ logical_volume.size }} -n {{ logical_volume.name }} -Z n {{ volume.meta.group }}
{%- endfor %}
udevadm control --reload-rules
udevadm trigger

cat << EOF > /etc/sysconfig/docker-storage
DOCKER_STORAGE_OPTIONS='--storage-driver=devicemapper --storage-opt dm.datadev=/dev/{{ volume.meta.group }}/data --storage-opt dm.metadatadev=/dev/{{ volume.meta.group }}/metadata {% if volume.size %} --storage-opt dm.basesize={{ volume.size }}{% endif %}'
EOF
{%- endif %}

{%- endfor %}

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

# mongodb_datadog
cat <<- 'EOF' > /etc/dd-agent/conf.d/mongo.yaml
init_config:

instances:
  # Specify the MongoDB URI, with database to use for reporting (defaults to "admin")
{%- if MONGODB_ADMIN_PASSWORD %}
  - server: mongodb://admin:{{MONGODB_ADMIN_PASSWORD}}@localhost:27018/admin
{% else %}
  - server: mongodb://localhost:27018/admin
{%- endif %}
EOF
{%- for node in aws.nodes %}
echo '{{node.ip}} node{{node.id}}' >> /etc/hosts
{%- endfor %}

# datadog.start
sh -c "sed 's/api_key:.*/api_key: {{DATADOG_API_KEY}}/' /etc/dd-agent/datadog.conf.example > /etc/dd-agent/datadog.conf"
{%- if DATADOG_BIND_HOST %}
echo 'bind_host: {{ DATADOG_BIND_HOST }}' >> /etc/dd-agent/datadog.conf
{%- endif %}
service datadog-agent restart

# install docker-compose
curl -L https://github.com/docker/compose/releases/download/1.7.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

cat << EOF > /tmp/docker-compose.yml
{{ docker_compose.yaml }}
EOF

cat << EOF > /tmp/docker-compose.override.yml
{{ docker_compose.override_yaml }}
EOF

runuser -l {{ username }} -c "/usr/local/bin/docker-compose -f /tmp/docker-compose.yml -f /tmp/docker-compose.override.yml up -d"
