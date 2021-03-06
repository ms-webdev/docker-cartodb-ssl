#
# Cartodb container
# https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst
#
FROM ubuntu:16.04
LABEL maintainer="Marco Schwochow <m.schwochow@gmx.net>"

# ENVs
ENV RAILS_ENV production

# OS Cleanup
RUN apt-get clean && apt-get update

# Build essentials + System Locales
# [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#system-locales]
RUN apt-get install -y -q apt-utils software-properties-common locales make pkg-config curl && \
    dpkg-reconfigure locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# GIT [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#git]
RUN apt-get install -y -q git

# PostgreSQL [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#postgresql]
RUN add-apt-repository ppa:cartodb/postgresql-10 && apt-get update && \
    apt-get install -y -q postgresql-10 \
        postgresql-plpython-10 \
        postgresql-server-dev-10 && \
    sed -i 's/\(peer\|md5\)/trust/' /etc/postgresql/10/main/pg_hba.conf && \
    service postgresql start && \
    createuser publicuser --no-createrole --no-createdb --no-superuser -U postgres && \
    createuser tileuser --no-createrole --no-createdb --no-superuser -U postgres && \
    service postgresql stop && \
    git clone https://github.com/CartoDB/cartodb-postgresql.git && \
    cd cartodb-postgresql && \
    make all install

# GIS dependencies [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#gis-dependencies]
RUN add-apt-repository ppa:cartodb/gis && apt-get update && \
    apt-get install -y -q gdal-bin libgdal-dev

# PostGIS [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#postgis]
RUN apt-get install -y -q postgis && \
    service postgresql start && \
    createdb -T template0 -O postgres -U postgres -E UTF8 template_postgis && \
    psql -U postgres template_postgis -c 'CREATE EXTENSION postgis;CREATE EXTENSION postgis_topology;' && \
    service postgresql stop && \
    ldconfig

# Redis [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#redis]
RUN add-apt-repository ppa:cartodb/redis-next && apt-get update && \
    apt-get install -y -q redis

# Node.js [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#nodejs]
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash && \
    apt-get install -y -q nodejs && \
    node -v && npm -v

# SQL API [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#sql-api]
RUN git clone git://github.com/CartoDB/CartoDB-SQL-API.git && \
    cd CartoDB-SQL-API && \
    npm install && \
    # wrong node version or stupid devs, i dont know
    npm audit fix

# MAPS API [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#maps-api]
RUN git clone git://github.com/CartoDB/Windshaft-cartodb.git && \
    cd Windshaft-cartodb && \
    npm install && \
    # wrong node version or stupid devs, i dont know
    npm audit fix && \
    mkdir logs

# Ruby [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#ruby]

RUN apt-add-repository ppa:brightbox/ruby-ng && apt-get update && \
    apt-get install -y -q ruby2.4 ruby2.4-dev ruby-bundler && \
    gem install compass

# Builder [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#builder]
RUN git clone --recursive https://github.com/CartoDB/cartodb.git && \
    cd cartodb && \
    apt-get install -y -q python-pip imagemagick unp zip libicu-dev && \
    bundle install && \
    CPLUS_INCLUDE_PATH=/usr/include/gdal C_INCLUDE_PATH=/usr/include/gdal PATH=$PATH:/usr/include/gdal \
        pip install --no-binary :all: -r python_requirements.txt && \
    npm install
ADD ./config/grunt_production.json /cartodb/config/grunt_production.json
RUN cd cartodb && npm run carto-node && npm run build:static && npm run build

# Configs
ADD ./config/cartodb-sql-api.production.js /CartoDB-SQL-API/config/environments/production.js
ADD ./config/cartodb-windschaft.production.js /Windshaft-cartodb/config/environments/production.js
ADD ./config/app_config.yml /cartodb/config/app_config.yml
ADD ./config/database.yml /cartodb/config/database.yml
ADD ./script/setup_admin.sh /cartodb/script/setup_admin.sh
ADD ./config/nginx/http.conf /etc/nginx/sites-enabled/default
ADD ./config/nginx/https.openssl.conf /etc/nginx/sites-enabled/https

# Server + Tools
RUN apt-get install -y -q \
    openssl \
    nginx-light \
    redis-tools \
    nano \
    htop

# Redis: change configs
RUN perl -pi.bak -e 's/^bind 127.0.0.1 ::1$/bind 0.0.0.0/' /etc/redis/redis.conf
RUN perl -pi.bak -e 's/^save /#save /' /etc/redis/redis.conf

# Fonts
ADD ./fonts /usr/share/fonts/
RUN apt-get install -y -q \
    ttf-dejavu \
    fonts-lato \
    ttf-unifont

# Fixes
RUN cp /cartodb/public/favicons/favicon.ico /cartodb/public/

# Install dataservices
#RUN git clone https://github.com/CartoDB/dataservices-api.git && \
#    cd dataservices-api && \
#    cd client && make install && \
#    cd - && \
#    cd server/extension && make install
#RUN cd dataservices-api/server/lib/python/cartodb_services && pip install -r requirements.txt && pip install . --upgrade
#RUN service postgresql start && service redis-server start && \
#    psql -U postgres -c "CREATE DATABASE dataservices_db ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';" && \
#    psql -U postgres -c "CREATE USER geocoder_api;" && \
#    psql -U postgres -d dataservices_db -c "BEGIN;CREATE EXTENSION IF NOT EXISTS plproxy; COMMIT" -e && \
#    psql -U postgres -d dataservices_db -c "BEGIN;CREATE EXTENSION IF NOT EXISTS cdb_dataservices_server; COMMIT" -e && \
#    service postgresql stop && service redis-server stop


# Init Database & Create Admin
RUN service postgresql start && service redis-server start && \
    cd cartodb && \
    bundle exec rake db:create && bundle exec rake db:migrate && \
    bash -l -c "cd /cartodb && bash script/setup_admin.sh" && \
    service postgresql stop && service redis-server stop

EXPOSE 80

ADD ./startup.sh /opt/startup.sh

CMD ["/bin/bash", "/opt/startup.sh"]
HEALTHCHECK CMD curl -f http://localhost || exit 1