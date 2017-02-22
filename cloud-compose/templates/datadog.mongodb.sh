# datadog.mongodb.sh 
cat <<- 'EOF' > /etc/dd-agent/conf.d/mongo.yaml
init_config:

instances:
  # Specify the MongoDB URI, with database to use for reporting (defaults to "admin")
{%- if secrets is defined and secrets.MONGODB_ADMIN_PASSWORD is defined %}
  - server: mongodb://admin:${MONGODB_ADMIN_PASSWORD}@localhost:27018/admin
{%- elif MONGODB_ADMIN_PASSWORD is defined %}
  - server: mongodb://admin:{{MONGODB_ADMIN_PASSWORD}}@localhost:27018/admin
{% else %}
  - server: mongodb://localhost:27018/admin
{%- endif %}
EOF
{%- for node in aws.nodes %}
echo '{{node.ip}} node{{node.id}}' >> /etc/hosts
{%- endfor %}

# datadog.start
{%- if secrets is defined and secrets.DATADOG_API_KEY is defined %}
sh -c "sed 's/api_key:.*/api_key: $DATADOG_API_KEY/' /etc/dd-agent/datadog.conf.example > /etc/dd-agent/datadog.conf"
{%- else %}
sh -c "sed 's/api_key:.*/api_key: {{DATADOG_API_KEY}}/' /etc/dd-agent/datadog.conf.example > /etc/dd-agent/datadog.conf"
{%- endif %}
echo 'bind_host: 0.0.0.0' >> /etc/dd-agent/datadog.conf
service datadog-agent restart
