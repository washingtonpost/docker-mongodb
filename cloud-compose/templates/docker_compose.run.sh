# docker_compose.run.sh 
curl -L https://github.com/docker/compose/releases/download/1.7.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

cat << EOF > /tmp/docker-compose.yml
{{ docker_compose.yaml }}
EOF

cat << EOF > /tmp/docker-compose.override.yml
{{ docker_compose.override_yaml }}
EOF

runuser -l {{ username }} -c "/usr/local/bin/docker-compose -f /tmp/docker-compose.yml -f /tmp/docker-compose.override.yml up -d"

