#
# Cartodb container
# https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst
#
FROM ubuntu:16.04
LABEL maintainer="Marco Schwochow <m.schwochow@gmx.net>"

# ENVs
ENV RAILS_ENV production
ENV CARTODB_PSQL=master

# OS Cleanup
RUN apt-get clean && apt-get update

# System Locales + Build essentials
RUN apt-get install -y -q apt-utils software-properties-common locales make pkg-config && \
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
    git checkout $CARTODB_PSQL && \
    make all install

# GIS dependencies [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#gis-dependencies]
RUN add-apt-repository ppa:cartodb/gis && apt-get update && \
    apt-get install -y -q gdal-bin libgdal-dev

# PostGIS [https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst#postgis]
RUN apt-get install -y -q postgis && \
    createdb -T template0 -O postgres -U postgres -E UTF8 template_postgis && \
    psql -U postgres template_postgis -c 'CREATE EXTENSION postgis;CREATE EXTENSION postgis_topology;' && \
    ldconfig && \
    PGUSER=postgres make installcheck