# APACHE-PHP-FPM

[![pipeline status](https://gitlab.byperiscope.com/docker/apache-php-fpm/badges/master/pipeline.svg)](https://gitlab.byperiscope.com/docker/apache-php-fpm/commits/master)

Docker image ready for Kubernetes to run Wordpress, Drupal, Symfony and more...

* Production ready.
* Lightweight image based on [alpine](https://hub.docker.com/_/alpine)
* Highly configurable using env variables

# Description

Contains :
* Apache 2.4 (with FCGI)
* PHP 7.4
* Xdebug 2.7

# Test it

Run this image to serve current directory on http://localhost
```
docker run -p 80:80 -v $(pwd)/www:/var/www/html registry.byperiscope.com/docker/apache-php-fpm:apache2.4-php7.3
```

# Configuration

By using environment variables, you can :
* run PHP as your user to avoid permissions issues
* set a basic http authentication
* block bots from indexing content
* define a specific htaccess file by environment

You can handle any type of deployment with this single image.

# Available tags

* apache2.4-php8.0.11
* apache2.4-php7.3
* apache2.4-php7.2-alpine3.11
* apache2.4-php7.4
* apache2.4-php7.3.19
* apache2.4-php7.3.22
* apache2.4-php7.3.25
* apache2.4.54-php8.1.13
* apache2.4.54-php8.1.14
* apache2.4.54-php8.2.1
* apache2.4.57-php8.2.6

There is no *latest* image to avoid updating accidentally.

# Documentation

Configuration is done by passing env variables at run command :

| variable                 | Description                                                       | Default value |
|--------------------------|-------------------------------------------------------------------|---------------|
| USER_ID                  | www-data will use this id both for apache and php-fpm             | 82            |
| DOCUMENT_ROOT            | Directory root for apache2 and php                                | /var/www/html |
| FPM_PM                   | PHP-FPM pm (ondemand, dynamic or static)                          | ondemand      |
| FPM_PM_MAX_CHILDREN      | PHP-FPM pm.max children                                           | 5             |
| FPM_PM_START_SERVERS     | PHP_FPM pm.start_servers                                          | 2             |
| FPM_PM_MIN_SPARE_SERVERS | PHP_FPM pm.min_spare_servers                                      | 1             |
| FPM_PM_MAX_SPARE_SERVERS | PHP_FPM pm.max_spare_servers                                      | 3             |
| FPM_PM_MAX_REQUESTS      | PHP_FPM pm.max_requests                                           | 500           |
| FPM_MEMORY_LIMIT         | PHP_FPM memory_limit                                              | 128M          |
| APACHE_ROBOTS_TXT        | If true, a robots.txt is used to forbid access to search engines. | true          |
| APACHE_AUTH_PASSWORD     | If defined, an authorization is required to access server.        | (empty)       |
| APACHE_AUTH_LOGIN        | Default login used only if a password is defined.                 | anonymous     |
| APACHE_TIMEOUT           | The Apache timeout value in seconds.                              | 600           |
| OPCACHE                  | PHP cache system to optimise the server performances.             | true          |
| APACHE_HTACCESS_DEV      | If defined, the dev htaccess files is used.                       | false         |
| APACHE_HTACCESS_PREPROD  | If defined, the preprod htaccess files is used.                   | false         |
| APACHE_HTACCESS_PROD     | If defined, the prod htaccess files is used.                      | false         |

# Xdebug (still experimental)

To use [Xdebug](https://xdebug.org/), you must set a cookie named *XDEBUG_SESSION* 
and listen for Xdebug on port 9000 in your favourite IDE.

# Build image

In current directory :

```
docker build . -t apache-php-fpm
```
