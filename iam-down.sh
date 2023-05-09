#!/bin/bash
source ./params.sh
docker compose -p iam -f docker-compose-iam.yml down --volumes

