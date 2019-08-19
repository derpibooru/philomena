#!/usr/bin/env bash

APP_USER=vagrant
APP_DIR="/home/$APP_USER/philomena"

echo "debconf debconf/frontend select noninteractive" | sudo debconf-set-selections
sed -i -e 's/\(AcceptEnv LANG LC_\*\)/#\1/' /etc/ssh/sshd_config
service sshd restart

add_key() {
    wget -qO - "$1" | apt-key add - &>/dev/null
}

install_packages() {
    apt-get install -y $@
}

# Vagrant setup, if necessary
if [ -e /vagrant ]; then
  ln -s /vagrant "$APP_DIR"
  chown -R "$APP_USER:$APP_USER" "/home/$APP_USER"
fi

# Necessary for apt and elasticsearch to succeed
install_packages apt-transport-https default-jre-headless

if [ ! -f /etc/apt/sources.list.d/elasticsearch-6.x.list ]; then
    add_key https://packages.elastic.co/GPG-KEY-elasticsearch
    echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" > /etc/apt/sources.list.d/elasticsearch-6.x.list
fi

if [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
    add_key https://www.postgresql.org/media/keys/ACCC4CF8.asc
    echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" > /etc/apt/sources.list.d/pgdg.list
fi

if [ ! -f /etc/apt/sources.list.d/nginx.list ]; then
    add_key http://nginx.org/keys/nginx_signing.key
    echo "deb http://nginx.org/packages/debian/ buster nginx" > /etc/apt/sources.list.d/nginx.list
fi

if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
    add_key https://deb.nodesource.com/gpgkey/nodesource.gpg.key
    echo 'deb https://deb.nodesource.com/node_12.x buster main' > /etc/apt/sources.list.d/nodesource.list
fi

if [ ! -f /etc/apt/sources.list.d/erlang.list ]; then
    add_key https://packages.erlang-solutions.com/debian/erlang_solutions.asc
    echo 'deb http://binaries.erlang-solutions.com/debian buster contrib' > /etc/apt/sources.list.d/erlang.list
fi

apt-get update

if ! install_packages build-essential postgresql-11 libpq-dev nginx nodejs \
                      elasticsearch esl-erlang elixir inotify-tools git \
                      redis-server automake libtool zlib1g-dev ffmpeg \
                      libavutil-dev libavcodec-dev libavformat-dev ; then
    >&2 echo "Installation of dependencies failed."
    exit 1
fi

sed -i -e 's/\(-Xm[sx]\)1g/\1256m/' /etc/elasticsearch/jvm.options
systemctl enable elasticsearch 2>/dev/null
service elasticsearch start

sed -i -e 's/md5/trust/' /etc/postgresql/11/main/pg_hba.conf
service postgresql restart

sudo -u postgres createuser -s "$APP_USER"

# nginx configuration
cp "$APP_DIR/vagrant/philomena-nginx.conf" /etc/nginx/conf.d/default.conf
sed -i -e "s|APP_DIR|$APP_DIR|g" /etc/nginx/conf.d/default.conf
service nginx restart

sudo -u "$APP_USER" bash "$APP_DIR/vagrant/app_setup.bash" "$APP_DIR"
