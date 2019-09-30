ARG CI_COMMIT_REF_NAME=master
FROM php:7.3-apache-stretch

# @KRN we use a custom base image - with all the goods for apache and co. - based on php:....
#FROM gitlab.krone.at:5000/krn/docker_base:$CI_COMMIT_REF_NAME

ARG FORCE_COMPOSER_UPDATE=no
ARG CI_COMMIT_REF_NAME

# Which WP version to use
ENV WORDPRESS_VERSION 5.2.3

ENV WORDPRESS_LANG_VERSION dev
ENV FORCE_COMPOSER_UPDATE=$FORCE_COMPOSER_UPDATE



# PARTS OF DOCKER_BASE

# Add group and user
RUN groupadd -g 20100 deploy && \
    useradd -m -u 20100 -g deploy -G www-data deploy

RUN apt-get update && apt-get install -y gnupg 2>&1 >> build.log


# Install basics
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        imagemagick \
        graphicsmagick \
        sudo \
        zlib1g-dev \
        libssl-dev \
        mongodb-clients \
        libmagickwand-6.q16-dev \
        default-libmysqlclient-dev \
        nodejs \
        git \
        libpng-dev \
        libjpeg-dev \
        libxml2-dev \
        mariadb-client \
        unzip \
        zip \
        librabbitmq-dev \
        exim4 \
        vim \
        ssh \
        wget \
        redis-server \
        authbind \
        libyaml-dev \
        less \
        rabbitmq-server \
        subversion \
        ruby-dev \
        ruby \
        libzip-dev \
        gnupg  2>&1 >> build.log

RUN wget -O /usr/bin/composer https://getcomposer.org/download/1.8.0/composer.phar && chmod a+rwx /usr/bin/composer



# END PARTS / SINCE usually this comes from krn/docker_base

# ###### SESSIONS to redis

# RUN echo "session.save_handler = redis" >> /usr/local/etc/php/conf.d/redis.ini
# RUN echo 'session.save_path = "tcp://redis.krn.krone.at:6379"' >> /usr/local/etc/php/conf.d/redis.ini

# palce non-git-based plugins here
ADD deploy/DOCKER/LOCAL_PLUGINS /LOCAL_PLUGINS
# Add configs to docker
ADD deploy/DOCKER/000-default.conf /etc/apache2/sites-enabled/000-default.conf

# php - some global php.ini settings
# ADD deploy/DOCKER/php/base-backend.ini /usr/local/etc/php/conf.d/

# Clone WP-source into app-dir and symlink /var/www/html to it
RUN git clone --depth 1 --branch $WORDPRESS_VERSION git://core.git.wordpress.org/ /app
RUN rm -fr /var/www/html \
    && ln -s /app /var/www/html

# get language
RUN mkdir /app/wp-content/languages/ &&  \
    curl -L -o /app/wp-content/languages/de_DE.mo https://translate.wordpress.org/projects/wp/${WORDPRESS_LANG_VERSION}/de/formal/export-translations?format=mo && \
    curl -L  -o /app/wp-content/languages/admin-de_DE.mo https://translate.wordpress.org/projects/wp/${WORDPRESS_LANG_VERSION}/admin/de/formal/export-translations?format=mo && \
    curl -L -o /app/wp-content/languages/admin-network-de_DE.mo https://translate.wordpress.org/projects/wp/${WORDPRESS_LANG_VERSION}/admin/network/de/formal/export-translations?format=mo && \
    curl -L -o /app/wp-content/languages/continents-cities-de_DE.mo https://translate.wordpress.org/projects/wp/${WORDPRESS_LANG_VERSION}/cc/de/formal/export-translations?format=mo

# Install wp-cli
RUN curl -L -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# add composer.json
ADD "composer.json" /app/composer.json

## @KRN we use a modified/forked version of LudicrousDB Drop-IN
# ADD "db-config.php" /app/db-config.php

ADD "composer.lock" /app/composer.lock


#### To be able to run crons
#### ADD deploy/DOCKER/wp_cron.sh /wp_cron.sh
###RUN chmod a+rwx /wp_cron.sh

# copy frontend-disabled theme
# aint no theme in prod
###ADD deploy/DOCKER/themes/krn-disabled /app/wp-content/themes/krn-disabled

# for K8s Health Check
RUN echo probe > /app/probe.txt

# Set working directory
WORKDIR /app

# Add php to load mu plugins
# MU plugins
# internal one that loads all mu-plugins
# ADD mu-plugins/load.php /app/wp-content/mu-plugins/load.php
# official sentry
# ADD mu-plugins/sentry.php /app/wp-content/mu-plugins/sentry.php

# 💣 just for the sake of it
RUN rm /app/xmlrpc.php

# add build file
ADD "deploy/DOCKER/plugin_shared.sh" /plugin_shared.sh
ADD "deploy/DOCKER/install_plugins.sh" /install_plugins.sh

RUN chmod a+rwx /plugin_shared.sh /install_plugins.sh

# potential build cache
# in CI we pre-populate the vendor folder - so composer update is faster
### ADD wp_vendor /wp_vendor

ADD "deploy/DOCKER/build.sh" /build.sh
RUN chmod +x /build.sh
RUN /build.sh


# add startup file and set permissions
ADD "deploy/DOCKER/run.sh" /run.sh
RUN chmod +x /run.sh

### @KRN we block all non-internal traffic with htacces
### ADD deploy/DOCKER/harden/admin/.htpasswd /.htpasswd
### ADD deploy/DOCKER/harden/admin/.htaccess /app/.htaccess

#### PROD via KRN/DOCKER_BASE

# Enable apache mods
RUN a2enmod \
        rewrite \
        expires \
        proxy \
        proxy_http


# Install php extensions
RUN docker-php-ext-install \
        exif \
        gd \
        mysqli \
        opcache \
        soap  2>&1 >> build.log

#####



# Run the server
EXPOSE 80 443
CMD ["/run.sh"]



