#!/bin/bash
# Set IP Address of this host (where webgw container runs)
# oAuth Client定義でdiscovery(IRISコンテナからhttps://webgw.localdomain/にアクセスする)の実行を成功させるために必要。
source ./params.sh
docker compose up -d webgw irisrsc irisrsc2 irisclient3
docker compose exec -T irisrsc bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"
docker compose exec -T irisrsc2 bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"
docker compose exec -T irisclient3 bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 120"

# リソースサーバはirisclient*とは異なり、同じサービスを共用しているので環境変数(OP)での切り替えが出来ないため
# その代わりとして下記を実行
echo "Applying Azure config to resource servers"
docker compose exec -T irisrsc iris session iris -U MYRSC "LoadConfigAzure^OP.Config"
docker compose exec -T irisrsc2 iris session iris -U MYRSC "LoadConfigAzure^OP.Config"

docker compose exec -T irisclient3 iris session iris -U USER "LoadConfig^OP.Config"
docker compose exec -T irisclient3 iris session iris -U USER2 "LoadConfig^OP.Config"
docker compose exec -T irisclient3 iris session iris -U BFF "LoadConfig^OP.Config"
docker compose exec -T irisclient3 iris session iris -U BFF2 "LoadConfig^OP.Config"

echo "Setting up an oAuth client for resource servers."
docker compose exec -T irisrsc iris session iris -U MYRSC "Register^API.Register"
docker compose exec -T irisrsc2 iris session iris -U MYRSC "Register^API.Register"

echo "Setting up an oAuth client for RP."
docker compose exec -T irisclient3 iris session iris -U USER "Register^MyApp.RegisterAll"

rm -fR client/*
docker compose exec irisclient3 cat environment.prod.ts > client/environment.prod.ts
docker compose exec irisclient3 cat environment.prod2.ts > client/environment.prod2.ts
docker compose exec irisclient3 cat environment.ts > client/environment.ts

./endpoints-azure.sh



