#!/bin/bash

source ./params.sh
./create_cert_keys.sh
cp webgateway* iris-webgateway-example/
./build.sh
./up.sh