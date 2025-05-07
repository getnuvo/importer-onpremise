#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

GREEN='\033[1;32m'
BOLD='\033[1m'
BUCKET_NAME="sdk-files-prod"
ALIAS_NAME="local"
MINIO_DEFAULT_USERNAME="minioadmin"
MINIO_DEFAULT_PASSWORD="minioadmin"
NC='\033[0m'
LOCAL_IP=0.0.0.0

#!/bin/bash

get_ip() {
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

    LOCAL_IP="$ip"
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

# create mapping route
curl -i -X POST --url http://localhost:8001/services/mapping-service/routes \
  --data 'name=mapping-route' \
  --data 'paths[]=/sdk/mapping' \
  --data 'strip_path=true'
}

checkup_environment_file () {
    echo -e "${BOLD}Fixing Env file..."
    ENV_FILE="importer-module.docker.env"
    EXAMPLE_ENV_FILE="example.${ENV_FILE}"
    if [ ! -f "$ENV_FILE" ]; then
        echo "File $ENV_FILE does not exist."
        cp $EXAMPLE_ENV_FILE $ENV_FILE
    fi
    echo -e "${BOLD}Done"
}

replace_environment_file () {
    filename="temp.txt"

    echo -e "${BOLD}Generating API Key..."
    docker exec -it minio mc admin accesskey create ${ALIAS_NAME} ${MINIO_DEFAULT_USERNAME} | grep 'Key' | awk '{print $3}' > $filename 
    
    declare -a keys
    while read -r line; do
        keys+=("$line")
    done < "$filename"

    echo -e "${GREEN}Here is your keys save it in the save place and please don't share it in public zone:"
    echo -e "\tAccessKey: ${keys[0]}"
    echo -e "\tSecretKey: ${keys[1]}${NC}"
    rm temp.txt

    echo -e "${BOLD}Fixing Env file..."
    ENV_FILE="importer-module.docker.env"
    EXAMPLE_ENV_FILE="example.${ENV_FILE}"
    if [ -f "$ENV_FILE" ]; then
        cp importer-module.docker.env tmp.env
        sed "s|IMPORTER_AWS_ENDPOINT=.*$|IMPORTER_AWS_ENDPOINT=http://${LOCAL_IP}:9000|; \
             s|IMPORTER_AWS_ACCESS_KEY=.*$|IMPORTER_AWS_ACCESS_KEY=${keys[0]}|; \
             s|IMPORTER_AWS_SECRET_KEY=.*$|IMPORTER_AWS_SECRET_KEY=${keys[1]}|" \
             tmp.env > "$ENV_FILE"
        rm tmp.env
    else
        echo "File $ENV_FILE does not exist."
        cp example.importer-module.docker.env importer-module.docker.env
        sed "s|IMPORTER_AWS_ENDPOINT=.*$|IMPORTER_AWS_ENDPOINT=http://${LOCAL_IP}:9000|; \
             s|IMPORTER_AWS_ACCESS_KEY=.*$|IMPORTER_AWS_ACCESS_KEY=${keys[0]}|; \
             s|IMPORTER_AWS_SECRET_KEY=.*$|IMPORTER_AWS_SECRET_KEY=${keys[1]}|" \
             "$EXAMPLE_ENV_FILE" > "$ENV_FILE"
    fi
    echo -e "${BOLD}Done"
}

prepare_storage_environment () {
   checkup_environment_file

    echo "Starting storage services..."
    docker-compose up -d minio

    echo "Logging in as admin..."
    docker-compose exec minio mc alias set "$ALIAS_NAME" http://localhost:9000 "$MINIO_DEFAULT_USERNAME" "$MINIO_DEFAULT_PASSWORD"
    echo -e "\n\t${GREEN}MinIO server is running on http://localhost:9000"
    echo -e "\tMinIO UI is running on http://localhost:9001${NC}\n"

    echo "Creating bucket..."
    docker-compose exec minio mc mb "$ALIAS_NAME/$BUCKET_NAME" || true

    echo -e "${BOLD}Setup lifecycle..."
    docker-compose exec minio mc ilm rule add "$ALIAS_NAME/$BUCKET_NAME" --expire-days "1"

    replace_environment_file
}

get_ip
setup_route
prepare_storage_environment
