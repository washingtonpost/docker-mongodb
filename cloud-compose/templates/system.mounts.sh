# system.mounts.sh
{%- for volume in aws.volumes %}
{%- if volume.block is defined %}
VOLUME_BLOCK="{{ volume.block }}"
if [ ! -e ${VOLUME_BLOCK} ]
then 
  # lookup NVME device since they are renamed
  yum -y install nvme-cli
  VOLUME_BLOCK_DEVICE_NAME=$(echo "${VOLUME_BLOCK}" | cut -d'/' -f 3)
  for device in $(nvme list | grep '^\/dev\/nvme' | cut -d' ' -f 1)
  do
    if nvme id-ctrl -v ${device} |grep -q $VOLUME_BLOCK_DEVICE_NAME
    then
      VOLUME_BLOCK="${device}"
    fi
  done
fi
{%- endif %}

{%- if volume.meta is defined and volume.meta.format is defined and volume.snapshot is not defined %}
mkfs -t {{ volume.file_system }} ${VOLUME_BLOCK}
{%- endif %}

{%- if volume.meta is defined and volume.meta.mount is defined %}
echo -e ${VOLUME_BLOCK}'\t{{ volume.meta.mount }}\t{{ volume.file_system }}\t{{ volume.meta.options|default("defaults,noatime", true) }}\t0\t0' >> /etc/fstab
mkdir -p {{ volume.meta.mount }}
mount {{ volume.meta.mount }}
{%- endif %}

{%- if volume.snapshot is defined %}
resize2fs ${VOLUME_BLOCK}
{%- endif %}

{%- if volume.file_system is defined and volume.file_system == "lvm2" %}
systemctl enable lvm2-lvmetad.service
systemctl enable lvm2-lvmetad.socket
systemctl start lvm2-lvmetad.service
systemctl start lvm2-lvmetad.socket
pvcreate ${VOLUME_BLOCK}
vgcreate {{ volume.meta.group}} ${VOLUME_BLOCK}
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
