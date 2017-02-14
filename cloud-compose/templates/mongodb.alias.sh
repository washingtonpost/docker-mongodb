# mongodb.alias.sh 
cat <<- EOF > /etc/yum.repos.d/mongodb.repo
[mongodb-org-${MONGODB_VERSION:-3.2}]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/7/mongodb-org/${MONGODB_VERSION:-3.2}/x86_64/
gpgcheck=0
enabled=1
EOF
yum -y install mongodb-org-shell
{%- if secrets is defined and secrets.MONGODB_ADMIN_PASSWORD is defined %}
cat <<- EOF > /etc/profile.d/mongo.sh
alias mongo='mongo -u admin -p ${MONGODB_ADMIN_PASSWORD} --authenticationDatabase admin'
EOF
{%- elif MONGODB_ADMIN_PASSWORD is defined %}
cat <<- 'EOF' > /etc/profile.d/mongo.sh
alias mongo='mongo -u admin -p {{ MONGODB_ADMIN_PASSWORD }} --authenticationDatabase admin'
EOF
{%- endif %}
