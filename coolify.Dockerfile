FROM ubuntu:22.04
LABEL maintainer="deploy@coolify.io"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies and PHP 8.1
RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:ondrej/php && \
    apt-get update && \
    apt-get install -y \
    curl \
    git \
    unzip \
    apache2 \
    php8.1 \
    libapache2-mod-php8.1 \
    php8.1-common \
    php8.1-xml \
    php8.1-imap \
    php8.1-mysql \
    php8.1-mailparse \
    php8.1-curl \
    php8.1-gd \
    php8.1-mbstring \
    php8.1-intl \
    php8.1-zip \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure Apache
RUN a2enmod rewrite
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
# Fix potential permission issues with apache logs
RUN mkdir -p /var/log/apache2 && chown -R www-data:www-data /var/log/apache2

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/uvdesk

# Copy application files
COPY . .

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions
RUN chown -R www-data:www-data /var/www/uvdesk/var /var/www/uvdesk/config /var/www/uvdesk/public

# Configure Apache VHost
COPY .docker/config/apache2/vhost.conf /etc/apache2/sites-available/000-default.conf

COPY .docker/bash/coolify-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/coolify-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/coolify-entrypoint.sh"]
