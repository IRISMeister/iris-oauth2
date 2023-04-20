#!/bin/bash

# リソースサーバはirisclient*とは異なり、同じサービスを共用しているので環境変数(OP)での切り替えが出来ないため
# その代わりとして下記を実行
echo "Applying IRIS config to resource servers"
docker compose exec -T irisrsc iris session iris -U MYRSC "LoadConfigIRIS^OP.Config"
docker compose exec -T irisrsc2 iris session iris -U MYRSC "LoadConfigIRIS^OP.Config"

docker compose exec -T irisclient iris session iris -U USER "LoadConfig^OP.Config"
docker compose exec -T irisclient iris session iris -U USER2 "LoadConfig^OP.Config"
docker compose exec -T irisclient iris session iris -U BFF "LoadConfig^OP.Config"
docker compose exec -T irisclient iris session iris -U BFF2 "LoadConfig^OP.Config"

docker compose exec -T irisrsc iris session iris -U MYRSC "Register^API.Register"
docker compose exec -T irisrsc2 iris session iris -U MYRSC "Register^API.Register"

echo "Setting up an oAuth client for RP."
docker compose exec -T irisclient iris session iris -U USER "Register^MyApp.RegisterAll"
docker compose exec -T irisclient2 iris session iris -U USER "Register^MyApp.RegisterAll"
