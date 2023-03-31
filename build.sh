#!/bin/bash

source ./params.sh
rm client/*
docker compose build --progress plain --parallel  #--no-cache
