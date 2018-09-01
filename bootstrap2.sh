#!/bin/bash

sudo apt-get update
sudo apt-get install -y nginx
sudo apt-get install -y php-fpm 

sed -i -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/7.0/fpm/php.ini

sudo systemctl restart php7.0-fpm

sudo echo "server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name server_domain_or_IP;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.0-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}" > /etc/nginx/sites-available/default

sudo systemctl reload nginx

echo "<?php
    phpinfo();
?>" > /var/www/html/index.php