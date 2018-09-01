#!/bin/bash

# Installs Nginxe as reverse proxy for PHP-FPM
#
_FUNC="Nginx-PHP7"

FQDN=$(get_tag ${INSTANCE_ID} "FQDN" $(hostname -f))

apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 4F4EA0AAE5267A6C
add-apt-repository -y ppa:ondrej/php

apt-get update -q
apt-get upgrade -qy
apt autoremove -qy

# PHP FPM
install_nginx_php_fpm() {
    apt-get install -qy nginx
    log "Installed Nginx"

    # PHP
    apt-get install -qy php7.1-fpm php7.1-mysql php7.1-mbstring php7.1-mcrypt php7.1-zip php7.1-xml php7.1-gd 
    log "Installed PHP 7.1"

    cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers  HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;
    gzip_disable "msie6";

    real_ip_header X-Forwarded-For;
    # We allow only traffic from the ELB via SGs, so this is acceptable
    set_real_ip_from 0.0.0.0/0;

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        location /healthcheck {
            access_log off;
            return 200;
        }

        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    server {
        listen 443;
        server_name $FQDN;

        ssl                  on;
        ssl_certificate      /etc/ssl/cert.pem;
        ssl_certificate_key  /etc/ssl/cert.key;

        root /var/www/html;

        index index.html index.htm index.debian-default.html index.php;

        location / {
            try_files \$uri \$uri/ /index.php\$is_args\$args;
        }

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php7.1-fpm.sock;
        }
    }
}
EOF
    # Create certs
    openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/cert.key -out /etc/ssl/cert.pem -days 3650 -subj "/CN=$FQDN" -nodes

    sed -i -e 's/;opcache.enable=0/opcache.enable=1/' /etc/php/7.1/fpm/php.ini
    sed -i -e 's/short_open_tag = Off/short_open_tag = On/' /etc/php/7.1/fpm/php.ini

    # Some server tuning
    cat <<EOF > /etc/php/7.1/fpm/pool.d/www.conf
[www]
user = www-data
group = www-data
listen = /run/php/php7.1-fpm.sock

listen.owner = www-data
listen.group = www-data

pm.status_path = /status
ping.path = /ping

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 15
pm.max_requests = 10000
EOF

    service nginx restart
    service php7.1-fpm restart

    # Fix buggy logrotate
    sed -i -e "s/daily/size 128M/; s/rotate [0-9]*/rotate 8/" /etc/logrotate.d/nginx
}

install_nginx_php_fpm

# Add hello work php.info page

echo '<?php phpinfo(); ?>' > /var/www/html/index.php

### end Nginx-PHP