{% if aws.dns is defined and aws.dns.nameserver is defined %}
cat <<- EOF > /etc/resolv.conf
domain ec2.internal
search ec2.internal
nameserver {{ aws.dns.nameserver }}
EOF
chattr +i /etc/resolv.conf
{% endif %}

