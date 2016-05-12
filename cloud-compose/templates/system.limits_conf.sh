ulimit -n 1048576
cat <<- 'EOF' >> /etc/security/limits.conf
*                soft    nofile         1048576
*                hard    nofile         1048576
EOF
