#!/bin/bash

echo "Hi! I'm here to help you set up docker environments."
echo "Creating mapping-module env file..."
cp ./example.mapping-module.docker.env ./mapping-module.docker.env
cp ./example.sdk-management.docker.env ./sdk-management.docker.env

# importer_port=3000
# importer_db_name=importer
# importer_db_host=mongodb://mongo:27017
# importer_db_username=importer
# importer_db_password=importer

# echo "Hi! I'm here to help you set up docker environments."

# if [ -f ! ./sdk-management.docker.env ]; then
#   echo "Importer environment:"
#   echo which port do you use to run the service
#   read -p "Enter it here: (default is ${importer_port}) " port
#   echo what database name do you use
#   read -p "Enter it here: (default is ${importer_db_name}) " db_name
#   echo what mongo uri do you use
#   read -p "Enter it here: (default is ${importer_db_host}) " db_host
#   echo what database username do you use
#   read -p "Enter it here: (default is ${importer_db_username}) " db_username
#   echo what database password do you use
#   read -p "Enter it here: (default is ${importer_db_password}) " db_password

#   if [ -z "$port" ]; then
#     port=$importer_port
#   fi

#   if [ -z "$db_name" ]; then
#     db_name=$importer_db_name
#   fi

#   if [ -z "$db_host" ]; then
#     db_host=$importer_db_host
#   fi

#   if [ -z "$db_username" ]; then
#     db_username=$importer_db_username
#   fi

#   if [ -z "$db_password" ]; then
#     db_password=$importer_db_password
#   fi

#   touch sdk-management.docker.env

#   echo "IMPORTER_PORT=\"${port}\"" >> sdk-management.docker.env
#   echo "IMPORTER_DB_NAME=\"${db_name}\"" >> sdk-management.docker.env
#   echo "IMPORTER_DB_HOST=\"${db_host}\"" >> sdk-management.docker.env
#   echo "IMPORTER_DB_USERNAME=\"${db_username}\"" >> sdk-management.docker.env
#   echo "IMPORTER_DB_PASSWORD=\"${db_password}\"" >> sdk-management.docker.env
# fi

# if [ -f ! ./mapping-module.docker.env ]; then
#   touch mapping-module.docker.env

# fi


echo "Cool! Now added the environment keys then run 'docker compose up -d' to launch services."
