FROM php:8.2.6-fpm-alpine3.18

#Update the Alpine packages
RUN apk update

# Install apache 2.4.54 and packages for composer
RUN apk add --no-cache \
	apache2-proxy \
	shadow \
	git \
	subversion \
	openssh \
	mercurial \
	tini \
	bash \
	patch \
	make \
	zip \
	unzip \
	mysql-client

#Install ModSecurity Dependencies
RUN apk add --no-cache \
	--virtual \
	.build-modsec \
	automake \
	autoconf \
	build-base \
	libxml2-dev \
	libtool \
	linux-headers \
	pcre-dev \
	apache2-dev \
	libmaxminddb-dev
    
# Install php extensions : gd, zip, mysqli opcache ...
RUN apk add --no-cache --virtual .build-deps \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
		zlib-dev \
		#zlib1g-dev \
		jpeg-dev \
		freetype-dev \
		libxpm-dev \
		libwebp-dev \
		libavif-dev \
		$PHPIZE_DEPS \
	&& docker-php-ext-configure gd --enable-gd --with-webp --with-jpeg --with-xpm --with-freetype --with-avif \
	&& docker-php-ext-configure zip \
	&& docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) gd mysqli opcache zip pdo pdo_mysql \
	#&& pecl install -f xdebug \
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		)" \
	&& apk add --virtual .aphp-phpexts-rundeps $runDeps \
	&& apk del .build-deps

# Configure apache to run as www-data and send logs to docker
RUN sed -ri \
		-e 's/User apache/User www-data/g' \
		-e 's/Group apache/Group www-data/g' \
		-e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
		-e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
		/etc/apache2/httpd.conf

EXPOSE 80

# ACTIVATE rewrite, proxy, proxy_http, proxy_fcgi, deflate & expires modules.
RUN sed -i \
  -e 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' \
  -e 's/#LoadModule proxy_module/LoadModule proxy_module/g' \
  -e 's/#LoadModule proxy_http_module/LoadModule proxy_http_module/g' \
  -e 's/#LoadModule proxy_fcgi_module/LoadModule proxy_fcgi_module/g' \
  -e 's/#LoadModule deflate_module/LoadModule deflate_module/g' \
  -e 's/#LoadModule expires_module/LoadModule expires_module/g' \
  /etc/apache2/httpd.conf

# Apache & PHP FPM configuration
ENV DOCUMENT_ROOT=/var/www/html \
  FPM_PM=ondemand \
  FPM_PM_MAX_CHILDREN=5 \
  FPM_PM_START_SERVERS=2 \
  FPM_PM_MIN_SPARE_SERVERS=1 \
  FPM_PM_MAX_SPARE_SERVERS=3 \
  FPM_PM_MAX_REQUESTS=500 \
  FPM_MEMORY_LIMIT=128M \
  FPM_PM_MAX_REQUESTS=500 \
  FPM_MEMORY_LIMIT=128M \
  FPM_UPLOAD_MAX_FILESIZE=10M \
  FPM_POST_MAX_SIZE=10M \
  APACHE_ROBOTS_TXT=true \
  APACHE_AUTH_LOGIN=anonymous \
  APACHE_AUTH_PASSWORD= \
  APACHE_TIMEOUT=600 \
  APACHE_HTACCESS_DEV=FALSE \
  APACHE_HTACCESS_PREPROD=FALSE \
  APACHE_HTACCESS_PROD=FALSE \
  OPCACHE=TRUE

# Generate robots.txt file to disallow search engine accesses
RUN { \
    echo 'User-agent: *'; \
    echo 'Disallow: /'; \
  } > /etc/apache2/robots.txt

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Install Xdebug in php-xdebug.ini file outside default ini scan dir
RUN { \
		echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)"; \
    echo "xdebug.remote_enable=on"; \
    echo "xdebug.remote_autostart=on"; \
    echo "xdebug.remote_connect_back=on"; \
	} > /usr/local/etc/php-xdebug.ini

#Implement the ModSecurity Configuration File
COPY config/modsecurity/modsecurity.conf /opt/modsecurity.conf

#Install ModSecurity libraries
RUN cd /opt && \
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurity && \
    git submodule init && \
    git submodule update && \
	rm -f /opt/ModSecurity/modsecurity.conf-recommended && \
	mv /opt/modsecurity.conf /opt/ModSecurity/modsecurity.conf && \
	/opt/ModSecurity/build.sh && \
	/opt/ModSecurity/configure && \ 
	make && \
	make install

#Install the ModSecurity Apache Connector
RUN cd /opt && \
	git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-apache.git && \
	cd ModSecurity-apache && \
	/opt/ModSecurity-apache/autogen.sh && \
	/opt/ModSecurity-apache/configure --with-libmodsecurity=/usr/local/modsecurity/ && \
	make && \
	make install

#Download the Core Rule Set Rules of the OWASP for ModSecurity
RUN git clone https://github.com/coreruleset/coreruleset.git /etc/apache2/modsecurity.d
RUN mv /etc/apache2/modsecurity.d/crs-setup.conf.example /etc/apache2/modsecurity.d/crs-setup.conf
RUN mv /etc/apache2/modsecurity.d/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example /etc/apache2/modsecurity.d/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
RUN mv /etc/apache2/modsecurity.d/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example /etc/apache2/modsecurity.d/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf

#Add the ModSecurity Bundle
RUN echo -e "\nErrorLog /var/log/apache2/error.log\nCustomLog /var/log/apache2/access.log combined\nLoadModule security3_module modules/mod_security3.so\nmodsecurity_rules_file /opt/ModSecurity/modsecurity.conf" >> /etc/apache2/httpd.conf

# Copy PHP-FPM config file.
COPY config/fpm/* /usr/local/etc/php-fpm.d/all/

# Set default performance configuration
COPY config/apache/performance.conf /etc/apache2/conf.d/performance.conf

# Include our vhost with php-fpm
COPY config/apache/vhost.conf /etc/apache2/conf.d/vhost.conf

# No entrypoint used by this image
ENTRYPOINT []
COPY config/apache-php-fpm /usr/local/bin/
CMD ["apache-php-fpm"]
