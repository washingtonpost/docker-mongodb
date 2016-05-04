{%- if MONGODB_ADMIN_PASSWORD is defined %}
alias mongo='mongo -u admin -p {{ MONGODB_ADMIN_PASSWORD }} --authenticationDatabase admin'
{%- endif %}
