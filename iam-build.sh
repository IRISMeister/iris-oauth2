#!/bin/bash

source ./params.sh
rm client/*
docker compose -p iam -f docker-compose-iam.yml build --progress plain --parallel  #--no-cache
