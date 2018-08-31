#!/bin/bash

apt-get install -y nginx
apt-get install -y curl

sudo curl -sL https://deb.nodesource.com/setup_8.x | sudo bash -
sudo apt-get install -y nodejs

sudo echo "server {
        listen 80;
        location / {
          proxy_pass http://localhost:3000;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection keep-alive;
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;
        }
      }" > /etc/nginx/sites-available/default

sudo chown www-data:www-data /etc/nginx/sites-available/default

sudo echo "var express = require('express')
      var app = express()
      var os = require('os');
      app.get('/', function (req, res) {
        res.send('Hello World from host ' + os.hostname() + '!')
      })
      app.listen(3000, function () {
        console.log('Hello world app listening on port 3000!')
      })" > /home/jae/myapp/index.js

sudo chown jae:jae /home/jae/myapp/index.js

sudo service nginx restart
cd "/home/jae/myapp"
sudo npm init
sudo npm install express -y
sudo nodejs index.js
