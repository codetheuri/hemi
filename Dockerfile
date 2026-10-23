FROM php:8.4-fpm-alpine

# Maintainer and image metadata
LABEL maintainer="Joseph Theuri <theurij113@gmail.com>" \
      org.opencontainers.image.authors="theurij113@gmail.com" \
      org.opencontainers.image.title="Hemi PHP 8.4 Engine" \
      org.opencontainers.image.description="Hardened, high-output PHP 8.4 + Nginx + Composer production engine"

# 1. System packages & build dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    bash \
    curl \
    git \
    zip \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    libxml2-dev \
    postgresql-dev \
    oniguruma-dev

# 2. Configure & install essential PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        exif \
        gd \
        intl \
        mbstring \
        mysqli \
        opcache \
        pdo_mysql \
        pdo_pgsql \
        soap \
        xml \
        zip

# 3. PECL Redis installation
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# 4. Copy Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 5. Configurations
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/http.d/default.conf
COPY php.ini /usr/local/etc/php/conf.d/99-hemi.ini
COPY php-fpm.conf /usr/local/etc/php-fpm.d/zz-hemi.conf

# 6. PHP-FPM process manager defaults, sized for a 2 GB host shared with a
#    queue worker and database (~50 MB per worker => ~600 MB at max_children).
#    Override at runtime, e.g. `-e PHP_FPM_MAX_CHILDREN=24`.
ENV PHP_FPM_PM=dynamic \
    PHP_FPM_MAX_CHILDREN=12 \
    PHP_FPM_START_SERVERS=3 \
    PHP_FPM_MIN_SPARE_SERVERS=2 \
    PHP_FPM_MAX_SPARE_SERVERS=5 \
    PHP_FPM_MAX_REQUESTS=500

WORKDIR /var/www/html
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
