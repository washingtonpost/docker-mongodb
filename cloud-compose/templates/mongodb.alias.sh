{%- if MONGODB_ADMIN_PASSWORD is defined %}
cat <<- 'EOF' > /etc/profile.d/mongo.sh
alias mongo='mongo -u admin -p {{ MONGODB_ADMIN_PASSWORD }} --authenticationDatabase admin'
EOF
{%- endif %}
