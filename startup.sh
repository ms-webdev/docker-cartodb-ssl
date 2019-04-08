#!/bin/bash

export RAILS_ENV=production
export CARTO_HOSTNAME=${CARTO_HOSTNAME:=$HOSTNAME}

# hostname injects
perl -pi -e 's/cartodb\.localhost/$ENV{"CARTO_HOSTNAME"}/g' /cartodb/config/app_config.yml /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/https

# start services
service postgresql start
service redis-server start
# /opt/varnish/sbin/varnishd -a :6081 -T localhost:6082 -s malloc,256m -f /etc/varnish.vcl

if [ "$HTTPS" == "1" ]; then

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

# start nginx
service nginx start

cd /cartodb
bundle exec script/restore_redis
bundle exec script/resque > resque.log 2>&1 &
#script/sync_tables_trigger.sh &

# Recreate api keys in db and redis, so sql api is authenticated
echo 'delete from api_keys' | psql -U postgres -t carto_db_production
bundle exec rake carto:api_key:create_default

# Run Server
bundle exec rails server