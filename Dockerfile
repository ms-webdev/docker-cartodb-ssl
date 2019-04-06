#
# Cartodb container
# https://github.com/CartoDB/cartodb/blob/master/doc/manual/source/install.rst
#
FROM ubuntu:16.04
LABEL maintainer="Marco Schwochow <m.schwochow@gmx.net>"

# ENVs
ENV RAILS_ENV production

# OS Cleanup + System Locales
RUN apt-get clean && apt-get update && apt-get install -y -q locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Build essentials
RUN apt-get install make pkg-config

# GIT
RUN apt-get install git

# PostgreSQL
RUN add-apt-repository ppa:cartodb/postgresql-10 && apt-get update && \
    apt-get install postgresql-10 \
        postgresql-plpython-10 \
        postgresql-server-dev-10