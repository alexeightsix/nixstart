if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi

# PHP
dnf install https://rpms.remirepo.net/fedora/remi-release-42.rpm && \
dnf module enable php:remi-8.4 && \
dnf install php php-cli && \
curl -sS https://getcomposer.org/installer | php && \
mv composer.phar /usr/local/bin/composer && \
chmod +x /usr/local/bin/composer

