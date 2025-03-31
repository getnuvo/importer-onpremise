#!/bin/bash

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

