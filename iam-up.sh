#!/bin/bash
source ./params.sh
docker compose -p iam -f docker-compose-iam.yml up -d irisauth
docker compose -p iam -f docker-compose-iam.yml exec -T irisauth bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"
docker compose -p iam -f docker-compose-iam.yml up -d webgw irisrsc irisrsc2
docker compose -p iam -f docker-compose-iam.yml exec -T irisrsc bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"
docker compose -p iam -f docker-compose-iam.yml exec -T irisrsc2 bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"

echo "Applying IRIS config to resource servers"
docker compose -p iam -f docker-compose-iam.yml exec -T irisrsc iris session iris -U MYRSC "LoadConfigIRIS^OP.Config"
docker compose -p iam -f docker-compose-iam.yml exec -T irisrsc2 iris session iris -U MYRSC "LoadConfigIRIS^OP.Config"

docker compose -p iam -f docker-compose-iam.yml exec -T irisrsc iris session iris -U MYRSC "Register^API.Register"
docker compose -p iam -f docker-compose-iam.yml exec -T irisrsc2 iris session iris -U MYRSC "Register^API.Register"

docker compose -p iam -f docker-compose-iam.yml exec irisauth cat environment.prod.ts > client/environment.prod.ts
docker compose -p iam -f docker-compose-iam.yml exec irisauth cat environment.prod2.ts > client/environment.prod2.ts
docker compose -p iam -f docker-compose-iam.yml exec irisauth cat environment.ts > client/environment.ts

docker compose -p iam -f docker-compose-iam.yml exec irisauth cat credentials_iam.json > client/credentials_iam.json
docker compose -p iam -f docker-compose-iam.yml up -d iam-migrations iam

./iam-register.sh

echo "Web Gateway | http://${HOST_NAME}/csp/bin/Systems/Module.cxw"
echo "Auth Server SMP | http://${HOST_NAME}/irisauth/csp/sys/%25CSP.Portal.Home.zen"
echo "RSC #1 SMP | http://${HOST_NAME}/irisrsc/csp/sys/%25CSP.Portal.Home.zen"
echo "RSC #2 SMP | http://${HOST_NAME}/irisrsc2/csp/sys/%25CSP.Portal.Home.zen"
echo "Angular based clien App | https://$HOST_NAME:8443/myapp/#/home"
echo "IAM Portal | http://localhost:8002"

