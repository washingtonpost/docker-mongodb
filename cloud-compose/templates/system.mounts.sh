# system.mounts.sh
{%- for volume in aws.volumes %}

{%- if volume.meta is defined and volume.meta.format is defined and volume.snapshot is not defined %}
mkfs -t {{ volume.file_system }} {{ volume.block }}
{%- endif %}

{%- if volume.meta is defined and volume.meta.mount is defined %}
echo -e '{{ volume.block }}\t{{ volume.meta.mount }}\t{{ volume.file_system }}\t{{ volume.meta.options|default("defaults,noatime", true) }}\t0\t0' >> /etc/fstab
mkdir -p {{ volume.meta.mount }}
mount {{ volume.meta.mount }}
{%- endif %}

{%- if volume.snapshot is defined %}
resize2fs {{ volume.block }}
{%- endif %}

{%- if volume.file_system is defined and volume.file_system == "lvm2" %}
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
