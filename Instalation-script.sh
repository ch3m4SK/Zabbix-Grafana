#!/bin/bash

# Variables
DB_ROOT_PASSWORD="root"
DB_NAME="zabbix"
DB_USER="zabbix"
DB_PASSWORD="zabbix"

# Configurar sistema operativo

# Update system
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl make gnupg

# Configure locales
echo "Configurando los locales..."
sudo apt install -y locales
sudo sed -i '/^#.*es_ES.UTF-8/s/^# //' /etc/locale.gen
sudo sed -i '/^#.*en_US.UTF-8/s/^# //' /etc/locale.gen
sudo dpkg-reconfigure -f noninteractive locales
sudo update-locale LANG=en_US.UTF-8

# instalar ODBC para monitoreo SQL
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install msodbcsql18 unixodbc-dev -y
sudo apt-get install unixodbc-dev libsnmp-dev libevent-dev libpcre3-dev -y


# Zabbix Server MySQL Apache2 instalation 

# Install Apache, MySQL, and PHP
echo "Instalando Apache, MySQL, y PHP..."
sudo apt install -y apache2 mysql-server php libapache2-mod-php php-mysql php-xml php-bcmath php-mbstring php-gd

# Add Zabbix repository
echo "Agregando el repositorio de Zabbix..."
wget wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_7.0-1+ubuntu22.04_all.deb
sudo apt update

# Install Zabbix server, frontend, and agent
echo "Instalando Zabbix server, frontend y agente..."
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Configure MySQL
echo "Configurando MySQL..."
sudo mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8 COLLATE utf8_bin;"
sudo mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "set global log_bin_trust_function_creators = 1;"
sudo mysql -e "FLUSH PRIVILEGES;"

# Import initial schema and data
echo "Importando el esquema inicial y datos a MySQL..."
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u$DB_USER -p$DB_PASSWORD $DB_NAME

# Configure Zabbix server  
echo "Configurando Zabbix server..."
sudo sed -i "s/# DBPassword=/DBPassword=$DB_PASSWORD/" /etc/zabbix/zabbix_server.conf
sudo systemctl restart zabbix-server zabbix-agent
sudo systemctl enable zabbix-server zabbix-agent

#
wget https://cdn.zabbix.com/zabbix/sources/stable/7.0/zabbix-7.0.0.tar.gz
tar -zxvf zabbix-7.0.0.tar.gz
cd zabbix-7.0.0
./configure --enable-server --with-mysql --with-unixodbc
make install

sudo systemctl restart zabbix-server


# Configure PHP for Zabbix frontend
echo "Configurando PHP para Zabbix frontend..."
sudo sed -i "s/^post_max_size = .*/post_max_size = 16M/" /etc/php/*/apache2/php.ini
sudo sed -i "s/^max_execution_time = .*/max_execution_time = 300/" /etc/php/*/apache2/php.ini
sudo sed -i "s/^max_input_time = .*/max_input_time = 300/" /etc/php/*/apache2/php.ini
sudo sed -i "s/^; date.timezone =.*/date.timezone = Europe\/Riga/" /etc/php/*/apache2/php.ini

# Enable and restart Apache
echo "Habilitando y reiniciando Apache..."
sudo systemctl restart apache2
sudo systemctl enable apache2

#Install Grafana

# Install depencies
sudo apt-get install -y apt-transport-https software-propierties-common wget

# Install gpg
sudo apt install gpg -y

# Import GPG key
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# Añadir el repositorio
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

# Actualizar paquetes e instalar grafana
sudo apt-get update
sudo apt-get -y install grafana

# Enable and restart grafana
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable grafana-server

sudo /bin/systemctl start grafana-server

sudo mv /etc/odbc.ini /etc/odbc.default.ini
sudo mv ./odbc.ini /etc/odbc.ini
sudo mv ./odbcinst.ini /etc/odbcinst.ini


# Get the server IP address
SERVER_IP=$(hostname -I | awk '{print $1}')

# Finishing up
sudo clear

echo "                       #######################################################################################################"
echo "                                               Instalación y configuración de Zabbix & Grafana completada."
echo "                               Abra su navegador web y acceda a la interfaz web de Zabbix para completar la configuración"
echo "                                                        Zabbix server http://$SERVER_IP/zabbix" 
echo "                                                           Grafana http://$SERVER_IP:3000"
echo "                       #######################################################################################################"