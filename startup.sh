#!/bin/bash

export RAILS_ENV=production
export CARTO_HOSTNAME=${CARTO_HOSTNAME:=$HOSTNAME}

perl -pi -e 's/cartodb\.localhost/$ENV{"CARTO_HOSTNAME"}/g' /etc/nginx/sites-enabled/default /cartodb/config/app_config.yml /Windshaft-cartodb/config/environments/production.js /etc/nginx/sites-enabled/https

service postgresql start
service redis-server start
redis-cli info
# /opt/varnish/sbin/varnishd -a :6081 -T localhost:6082 -s malloc,256m -f /etc/varnish.vcl

if [ "$HTTPS" == "1" ]; then
# TODO Configure carto for https

# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/cartodb_openssl.key -out /etc/ssl/cartodb_openssl.crt
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
    -keyout /etc/ssl/cartodb.key  -out /etc/ssl/cartodb.crt

cd /Windshaft-cartodb && node app.js production &
cd /CartoDB-SQL-API && node app.js production &

if [ "$LETSENCRYPT_EMAIL" != "" ]; then
# Request cert
certbot certonly --standalone --preferred-challenges tls-sni -d $CARTO_HOSTNAME --email $LETSENCRYPT_EMAIL --agree-tos 
# TODO test it
# TODO Config nginx
fi
else
rm /etc/nginx/sites-enabled/https

cd /Windshaft-cartodb
node app.js development &

cd /CartoDB-SQL-API
node app.js development &
fi

service nginx start

cd /cartodb
bundle exec rake db:create
bundle exec rake db:migrate
# bundle exec rails server
bundle exec script/resque > resque.log 2>&1 &


SUBDOMAIN="dev"
PASSWORD="pass1234"
ADMIN_PASSWORD="pass1234"
EMAIL="dev@example.com"

echo "--- Create '${SUBDOMAIN}' user"
bundle exec  rake cartodb:db:create_user --trace SUBDOMAIN="${SUBDOMAIN}" \
	PASSWORD="${PASSWORD}" ADMIN_PASSWORD="${ADMIN_PASSWORD}" \
	EMAIL="${EMAIL}"
# # Update your quota to 100GB
echo "--- Updating quota to 100GB"
bundle exec  rake cartodb:db:set_user_quota["${SUBDOMAIN}",102400]

# # Allow unlimited tables to be created
echo "--- Allowing unlimited tables creation"
bundle exec  rake cartodb:db:set_unlimited_table_quota["${SUBDOMAIN}"]

# # Allow user to create private tables in addition to public
echo "--- Allowing private tables creation"
bundle exec  rake cartodb:db:set_user_private_tables_enabled["${SUBDOMAIN}",'true']

# # Set the account type
echo "--- Setting cartodb account type"
bundle exec  rake cartodb:db:set_user_account_type["${SUBDOMAIN}",'[DEDICATED]']

#bundle exec script/restore_redis
#bundle exec script/resque > resque.log 2>&1 &
#script/sync_tables_trigger.sh &

# Recreate api keys in db and redis, so sql api is authenticated
#echo 'delete from api_keys' | psql -U postgres -t carto_db_production
#bundle exec rake carto:api_key:create_default

# bundle exec rake carto:api_key:create_default
#bundle exec rails server
bundle exec thin start --threaded -p 3000 --threadpool-size 5
