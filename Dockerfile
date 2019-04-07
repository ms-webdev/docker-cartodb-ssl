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

# Configs
# ADD SQL API + MAPS API