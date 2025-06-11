#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

GREEN='\033[1;32m'
BOLD='\033[1m'
BUCKET_NAME="importer-files"
ALIAS_NAME="local"
NC='\033[0m'

default_storage="AWS"
minio_default_username="minioadmin"
minio_default_password="minioadmin"
base_minio_url=http://0.0.0.0:9000
IMPORTER_ENV_FILE="importer-module.docker.env"
MAPPING_ENV_FILE="mapping-module.docker.env"

get_minio_service_url() {
    local ip
    case "$(uname -s)" in
        Darwin)
            ip=$(ipconfig getifaddr en0)
            if [ -z "$ip" ]; then
                ip=$(ipconfig getifaddr en1)
            fi
            ;;

        Linux)
            ip=$(hostname -I | awk '{print $1}')
            ;;

        MINGW*|MSYS*|CYGWIN*)
            ip=$(ipconfig | grep -E "IPv4 Address|IPv4-adresse" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
            ;;
        *)
            echo "Unsupported OS"
            exit 1
            ;;
    esac

    read -p "MinIO base service url (default="http://$ip:9000"): " base_minio_url
       : ${base_minio_url:="http://$ip:9000"}
}

setup_route () {
# create importer-service
curl -i -X POST --url http://localhost:8001/services/ \
  --data 'name=importer-service' \
  --data 'url=http://importer-module:3000'

# create importer route
curl -i -X POST --url http://localhost:8001/services/importer-service/routes \
  --data 'name=importer-route' \
  --data 'paths[]=/sdk/v1' \
  --data 'strip_path=false'

# create mapping-service
curl -i -X POST --url http://localhost:8001/services/ \
  --data 'name=mapping-service' \
  --data 'url=http://mapping-module:3001'

# add cors origin to mapping service
curl -i -X POST --url http://localhost:8001/services/mapping-service/plugins/ \
  --data 'name=cors'

# create mapping route
curl -i -X POST --url http://localhost:8001/services/mapping-service/routes \
  --data 'name=mapping-route' \
  --data 'paths[]=/sdk/mapping' \
  --data 'strip_path=true'

# setup minio's ui service
curl -i -X POST --url 'http://localhost:8001/services' \
  --data 'name=minio-ui-service' \
  --data 'url=http://minio:9001'

# setup minio's ui route
curl -i -X POST --url http://localhost:8001/services/minio-ui-service/routes \
  --data 'name=minio-ui-route' \
  --data 'paths[]=/minio' \
  --data 'strip_path=true'
}

ask_license_key() {
  importer_env=$(<"$IMPORTER_ENV_FILE")
  if [[ "$importer_env" != *"IMPORTER_LICENSE_KEY"* ]]; then
      echo "IMPORTER_LICENSE_KEY=""" >> $IMPORTER_ENV_FILE
  fi
  mapping_env=$(<"$MAPPING_ENV_FILE")
  if [[ "$mapping_env" != *"MAPPING_LICENSE_KEY"* ]]; then
      echo "\nMAPPING_LICENSE_KEY=""" >> $MAPPING_ENV_FILE
  fi

  while true; do
    read -p "Do you want to enter your license key for the BE side? (yes/no): " answer
    case "$answer" in
      yes|y)
        read -s -p "Please enter your license key: " be_license_key

        cp importer-module.docker.env tmp.env
        sed "s|IMPORTER_LICENSE_KEY=.*$|IMPORTER_LICENSE_KEY=${be_license_key}|;" \
             tmp.env > "$IMPORTER_ENV_FILE"
        rm tmp.env

        cp mapping-module.docker.env tmp.env
        sed "s|MAPPING_LICENSE_KEY=.*$|MAPPING_LICENSE_KEY=${be_license_key}|;" \
             tmp.env > "$MAPPING_ENV_FILE"
        rm tmp.env
        
        break
        ;;
      no|n)
        break
        ;;
      *)
        echo "Invalid response. Please answer yes or no."
        ;;
    esac
  done
}

checkup_environment_file () {
    echo -e "${BOLD}Fixing Env file..."
    EXAMPLE_ENV_FILE="example.${IMPORTER_ENV_FILE}"
    if [ ! -f "$IMPORTER_ENV_FILE" ]; then
        echo "File $IMPORTER_ENV_FILE does not exist."
        cp $EXAMPLE_ENV_FILE $IMPORTER_ENV_FILE
    fi
    echo -e "${BOLD}Done"
}

replace_minio_environment_file () {
    read -p "MinIO username (default=$minio_default_username): " minio_username
        : ${minio_username:=$minio_default_username}
        
    read -p "MinIO password (default=$minio_default_password): " minio_password
        : ${minio_password:=$minio_default_password}

    get_minio_service_url

    echo "Starting storage services..."
    docker-compose up -d minio

    echo "Logging in as admin..."
    docker-compose exec minio mc alias set $ALIAS_NAME http://localhost:9000 $minio_username $minio_password
    echo "\n\t${GREEN}MinIO server is running on http://localhost:9000"
    echo "\tMinIO UI is running on http://localhost:9001${NC}\n"

    echo "Creating bucket..."
    docker-compose exec minio mc mb "$ALIAS_NAME/$BUCKET_NAME" || true

    echo -e "${BOLD}Setup lifecycle..."
    docker-compose exec minio mc ilm rule add "$ALIAS_NAME/$BUCKET_NAME" --expire-days "1"

    filename="temp.txt"

    echo -e "${BOLD}Generating API Key..."
    docker exec -it minio mc admin accesskey create ${ALIAS_NAME} ${minio_username} | grep 'Key' | awk '{print $3}' > $filename 
    
    declare -a keys
    while read -r line; do
        keys+=("$line")
    done < "$filename"

    echo "AccessKey: ${keys[0]}\n \
SecretKey: ${keys[1]}\n \
MinIO Service: ${base_minio_url}\n \
MinIO UI/Console: http://localhost:8000/minio/browser
        " > minio-credential.txt

    echo -e "${GREEN}Here is your keys save it in the save place and please don't share it in public zone:"
    echo -e "\tAccessKey: ${keys[0]}"
    echo -e "\tSecretKey: ${keys[1]}${NC}"
    rm temp.txt

    echo -e "${BOLD}Fixing Env file..."
    EXAMPLE_ENV_FILE="example.${IMPORTER_ENV_FILE}"
    if [ -f "$IMPORTER_ENV_FILE" ]; then

        message=$(<"$IMPORTER_ENV_FILE")
        if [[ "$message" != *"IMPORTER_AWS_ENDPOINT"* ]]; then
            echo "IMPORTER_AWS_ENDPOINT={}" >> $IMPORTER_ENV_FILE
        fi

        cp importer-module.docker.env tmp.env
        sed "s|IMPORTER_AWS_ENDPOINT=.*$|IMPORTER_AWS_ENDPOINT=${base_minio_url}|; \
             s|IMPORTER_AWS_ACCESS_KEY=.*$|IMPORTER_AWS_ACCESS_KEY=${keys[0]}|; \
             s|IMPORTER_AWS_SECRET_KEY=.*$|IMPORTER_AWS_SECRET_KEY=${keys[1]}|" \
             tmp.env > "$IMPORTER_ENV_FILE"
        rm tmp.env
    else
        echo "File $IMPORTER_ENV_FILE does not exist."
        cp example.importer-module.docker.env importer-module.docker.env
        sed "s|IMPORTER_AWS_ENDPOINT=.*$|IMPORTER_AWS_ENDPOINT=${base_minio_url}|; \
             s|IMPORTER_AWS_ACCESS_KEY=.*$|IMPORTER_AWS_ACCESS_KEY=${keys[0]}|; \
             s|IMPORTER_AWS_SECRET_KEY=.*$|IMPORTER_AWS_SECRET_KEY=${keys[1]}|" \
             "$EXAMPLE_ENV_FILE" > "$IMPORTER_ENV_FILE"
    fi
    echo -e "${BOLD}Done"
}

replace_aws_environment_file () {
 cp importer-module.docker.env tmp.env
 sed "s|IMPORTER_AWS_ENDPOINT=.*$||;" \
      tmp.env > "$IMPORTER_ENV_FILE"
 rm tmp.env
}

prepare_storage_environment () {
    checkup_environment_file

    read -p "Which File Storage do you want? [AWS/MinIO]: " storage
        : ${storage:=$default_storage}

    storage=$(echo "$storage" | tr '[:upper:]' '[:lower:]')

    if [[ "$storage" != "aws" && "$storage" != "minio" ]]; then
        storage="AWS"
        echo "Invalid input! Defaulting to AWS."
    fi

    if [[ "$storage" == "minio" ]]; then
    replace_minio_environment_file
    else
    replace_aws_environment_file
    fi
}

prepare_storage_environment
ask_license_key
setup_route

docker compose up -d
