# datadog.mongodb.sh 
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
