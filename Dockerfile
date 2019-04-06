#
# Cartodb container
#
FROM ubuntu:16.04
LABEL maintainer="Marco Schwochow <m.schwochow@gmx.net>"

# ENVs
ENV RAILS_ENV production

# Cleanup + Locales
RUN apt-get clean && apt-get update && apt-get install -y -q locales && /
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8