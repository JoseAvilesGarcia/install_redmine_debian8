#!/bin/bash
## Install Redmine 3.3.2 Integrated with ISPConfig
## On Debian 64Bits
## Author: Nilton OS -- www.linuxpro.com.br
## Version: 0.1
### Tested on Debian 8.7 64Bits

apt-get install -y ruby ruby-dev libmysqlclient-dev libmagickwand-dev
gem install unicorn
gem install bundler
gem install rake

## Enable Modules in Apacha2
a2enmod proxy
a2enmod proxy_balancer
a2enmod proxy_http
a2enmod rewrite

### Or Create Database/User in admin ISPConfig
echo "CREATE DATABASE redmine CHARACTER SET utf8;
CREATE USER 'redmine'@'localhost' IDENTIFIED BY 'RedminePasswd';
GRANT ALL PRIVILEGES ON redmine.* TO 'redmine'@'localhost';" >  /tmp/mysql_redmine.sql

mysql -p < /tmp/mysql_redmine.sql

adduser --disabled-login --gecos 'Redmine' redmine

cd /home/redmine/
wget http://www.redmine.org/releases/redmine-3.3.2.tar.gz
tar -xvf redmine-3.3.2.tar.gz && rm -f redmine-3.3.2.tar.gz
mv redmine-3.3.2 redmine

cd /home/redmine/redmine
echo "gem 'unicorn'" >> /home/redmine/redmine/Gemfile

### Configure Unicorn for Redmine
FILE_UNICORN=/home/redmine/redmine/config/unicorn.rb
wget https://raw.github.com/defunkt/unicorn/master/examples/unicorn.conf.rb -O $FILE_UNICORN

sed -i 's|listen 8080|listen 5000|' $FILE_UNICORN
sed -i 's|/path/to/app/current|/home/redmine/redmine|' $FILE_UNICORN
sed -i 's|/path/to/.unicorn.sock|/home/redmine/redmine/tmp/sockets/redmine.socket|' $FILE_UNICORN
sed -i 's|/path/to/app/shared/pids/unicorn.pid|/home/redmine/redmine/tmp/pids/unicorn.pid|' $FILE_UNICORN
sed -i 's|/path/to/app/shared/log/unicorn.stderr.log|/home/redmine/redmine/log/unicorn.stderr.log|' $FILE_UNICORN
sed -i 's|/path/to/app/shared/log/unicorn.stdout.log|/home/redmine/redmine/log/unicorn.stdout.log|' $FILE_UNICORN


cp config/database.yml.example config/database.yml
sed -i 's|username: root|username: redmine|' /home/redmine/redmine/config/database.yml
sed -i 's|password: ""|password: RedminePasswd|' /home/redmine/redmine/config/database.yml

sudo -u redmine -H bundle install --without development test
sudo -u redmine -H bundle exec rake generate_secret_token
sudo -u redmine -H RAILS_ENV=production bundle exec rake db:migrate
sudo -u redmine -H RAILS_ENV=production REDMINE_LANG=pt-BR bundle exec rake redmine:load_default_data

mkdir -p /home/redmine/redmine/tmp/pids
chown -R redmine:redmine /home/redmine


echo '[Unit]
Description=Redmine Unicorn Server
Wants=mysql.service
After=mysql.service

[Service]
User=redmine
WorkingDirectory=/home/redmine/redmine
Environment=RAILS_ENV=production
SyslogIdentifier=redmine-unicorn
PIDFile=/home/redmine/redmine/tmp/pids/unicorn.pid

ExecStart=/usr/local/bin/bundle exec "unicorn_rails -D -c /home/redmine/redmine/config/unicorn.rb -E production"

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/redmine.service

systemctl daemon-reload
systemctl start redmine
systemctl enable redmine

## Open in web browser:
## http://server_IP_address:5000


### Config Apache2
# ProxyPreserveHost On
# ProxyRequests off
# ProxyPass / http://127.0.0.1:5000/
# ProxyPassReverse / http://127.0.0.1:5000/