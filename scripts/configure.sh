#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

GREEN='\033[1;32m'
BOLD='\033[1m'
NC='\033[0m'

IMPORTER_ENV_FILE="importer-module.docker.env"
MAPPING_ENV_FILE="mapping-module.docker.env"

AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
AWS_REGION=""
AWS_BUCKET_NAME=""

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

replace_aws_environment_file () {
 cp importer-module.docker.env tmp.env

  sed "s|IMPORTER_AWS_ACCESS_KEY=.*$|IMPORTER_AWS_ACCESS_KEY=${AWS_ACCESS_KEY_ID}|;
       s|IMPORTER_AWS_SECRET_KEY=.*$|IMPORTER_AWS_SECRET_KEY=${AWS_SECRET_ACCESS_KEY}|;
       s|IMPORTER_AWS_REGION=.*$|IMPORTER_AWS_REGION=${AWS_REGION}|;
       s|IMPORTER_AWS_S3_BUCKET=.*$|IMPORTER_AWS_S3_BUCKET=${AWS_BUCKET_NAME}|; 
       " \
      tmp.env > "$IMPORTER_ENV_FILE"

 rm tmp.env
}

prepare_storage_environment () {
    checkup_environment_file

    read -p "Do you want to setup your AWS S3 bucket now? (yes/no) ?: " isAutoCompleteAWSCredential
    if [[ "$isAutoCompleteAWSCredential" == "yes" || "$isAutoCompleteAWSCredential" == "y" ]]; then
        read -p "Please enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
        : ${AWS_ACCESS_KEY_ID:=""}
        read -p "Please enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
        : ${AWS_SECRET_ACCESS_KEY:=""}
        read -p "Please enter your AWS Region (default: us-east-1): " AWS_REGION
        : ${AWS_REGION:="us-east-1"}
        read -p "Please enter your S3 Bucket Name: " AWS_BUCKET_NAME
        : ${AWS_BUCKET_NAME:=""}
        
        replace_aws_environment_file
    fi
    
}

prepare_storage_environment
ask_license_key
setup_route

docker compose up -d