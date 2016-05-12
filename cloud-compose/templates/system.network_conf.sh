# system.network_conf.sh
cat << EOF > /etc/sysctl.d/network.conf
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.nf_conntrack_max = 512000
net.ipv4.tcp_keepalive_intvl = 60 
net.ipv4.tcp_keepalive_probes = 10 
net.ipv4.tcp_keepalive_time = 600
net.netfilter.nf_conntrack_tcp_timeout_established = 1800
EOF
echo 128000 > /sys/module/nf_conntrack/parameters/hashsize
sysctl --system
