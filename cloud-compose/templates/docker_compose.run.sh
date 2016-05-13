# docker_compose.run.sh 
cat << EOF > /tmp/docker-compose.yml
{{ docker_compose.yaml }}
EOF

cat << EOF > /tmp/docker-compose.override.yml
{{ docker_compose.override_yaml }}
EOF

runuser -l {{ aws.username }} -c "docker-compose -f /tmp/docker-compose.yml -f /tmp/docker-compose.override.yml up -d"

