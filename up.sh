#!/bin/bash
# Set IP Address of this host (where webgw container runs)
# oAuth Client定義でdiscovery(IRISコンテナからhttps://webgw.localdomain/にアクセスする)の実行を成功させるために必要。
source ./params.sh
docker compose up -d irisauth
docker compose exec -T irisauth bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"
docker compose up -d webgw irisrsc irisrsc2 irisclient irisclient2
docker compose exec -T irisrsc bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"
docker compose exec -T irisrsc2 bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"
docker compose exec -T irisclient bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"
docker compose exec -T irisclient2 bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"

echo "Setting up an oAuth client for resource servers."
./register_oauth2_client.sh

rm -fR client/*
# display client_id and client_secret
echo "For a python(native) client. Copy&paste these into credentials_python.json"
docker compose exec irisauth cat credentials_python.json | jq
docker compose exec irisauth cat credentials_python.json > client/credentials_python.json
echo "For curl. Use them as parameters for curl."
docker compose exec irisauth cat credentials_curl.json | jq
docker compose exec irisauth cat credentials_curl.json > client/credentials_curl.json
echo "For an angular client."
docker compose exec irisauth cat credentials_angular.json | jq
docker compose exec irisauth cat credentials_angular.json > client/credentials_angular.json
docker compose exec irisauth cat credentials_angular2.json | jq
docker compose exec irisauth cat credentials_angular2.json > client/credentials_angular2.json
docker compose exec irisauth cat environment.prod.ts > client/environment.prod.ts
docker compose exec irisauth cat environment.prod2.ts > client/environment.prod2.ts
docker compose exec irisauth cat environment.ts > client/environment.ts
#echo "For an IRIS client. Just FYI."
#docker compose exec irisclient cat credentials_CLIENT_APP.json | jq
#docker compose exec irisclient cat credentials_CLIENT_APP.json > client/credentials_CLIENT_APP.json
#echo "For an IRIS client2. Just FYI."
#docker compose exec irisclient2 cat credentials_CLIENT_APP2.json | jq
#docker compose exec irisclient2 cat credentials_CLIENT_APP2.json > client/credentials_CLIENT_APP2.json

./endpoints.sh

