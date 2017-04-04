FROM linode/lamp
ARG mysql_root_pw=mysqlrootpassword


# Create user
RUN adduser --disabled-password --gecos "" bcproxy && \
    echo "bcproxy ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER bcproxy
WORKDIR /home/bcproxy

# Install git
RUN sudo apt-get update && \
	sudo apt-get install -y \
		git && \
	sudo apt-get clean && \
	sudo rm -rf /var/lib/apt/lists/*

# Download proxy from github
RUN cd /home/bcproxy && \
	git clone https://www.github.com/cdhowie/bitcoin-mining-proxy

# Get configuration
COPY htdocs/config.inc.php /home/bcproxy/bitcoin-mining-proxy/htdocs/config.inc.php
RUN cd /home/bcproxy/bitcoin-mining-proxy/htdocs && \
    sudo chmod 755 config.inc.php

# Setup MySQL
RUN sudo service mysql start && \
    cd /home/bcproxy/bitcoin-mining-proxy/htdocs && \
    export db_user=$(awk '/db_user/ { print $3 }' < config.inc.php | sed "s/'//g" | sed 's/,//g') && \
    export db_name=$(awk '/db_connection_string/ {print $3}' < config.inc.php | cut -d';' -f2 | cut -d'=' -f2 | sed "s/',//g") && \
	mysql -u root --password=Admin2015 -e "UPDATE mysql.user SET Password=PASSWORD('${mysql_root_pw}') WHERE User='root'; FLUSH PRIVILEGES;" && \
	mysql -u root --password=$mysql_root_pw -e "CREATE DATABASE ${db_name};" && \
	mysql -u root --password=$mysql_root_pw -e "CREATE USER 'bcproxy'@'localhost' IDENTIFIED BY '$(awk '/db_password/ { print $3 }' < config.inc.php | sed "s/'//g" | sed 's/,//g')';" && \
	mysql -u root --password=$mysql_root_pw -e "GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on ${db_name}.* to 'bcproxy'@'localhost'; FLUSH PRIVILEGES;" && \
	mysql -u root --password=$mysql_root_pw $db_name < /home/bcproxy/bitcoin-mining-proxy/database/schema.sql

# Setup apache
RUN cd /etc/apache2/sites-available && \
    sudo cp 000-default.conf bitproxy.conf && \
	sudo sed -i 's/#ServerName www.example.com/ServerName localhost/g' bitproxy.conf && \
	sudo sed -i 's/webmaster@localhost/bcproxy@localhost/g' bitproxy.conf && \
    sudo sed -i 's/html/bitproxy/g' bitproxy.conf && \
    sudo mkdir /var/www/bitproxy && \
	sudo cp -r -f /home/bcproxy/bitcoin-mining-proxy/htdocs/* /var/www/bitproxy/ && \
    sudo rm ../sites-enabled/example.com.conf && \
    sudo ln -s /etc/apache2/sites-available/bitproxy.conf /etc/apache2/sites-enabled/bitproxy.conf

