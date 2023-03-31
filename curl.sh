#!/bin/bash

export client_id=$(cat client/credentials_curl.json | jq -r .client_id)
export client_secret=$(cat client/credentials_curl.json | jq -r .client_secret)
export access_token=$(curl --cacert ssl/web/all.crt -u ${client_id}:${client_secret} -XPOST https://webgw.localdomain/irisauth/authserver/oauth2/token --data-urlencode 'grant_type=password' --data-urlencode 'username=_SYSTEM' --data-urlencode 'password=SYS' --data-urlencode 'scope=openid profile scope1 scope2' -s | jq -r .access_token)
echo ""

curl --cacert ssl/web/all.crt -H "Authorization: Bearer ${access_token}" -H 'Content-Type:application/json;charset=utf-8' https://webgw.localdomain/irisauth/authserver/oauth2/userinfo -s | jq
echo ""

curl --cacert ssl/web/all.crt -H "Authorization: Bearer ${access_token}" -H 'Content-Type:application/json;charset=utf-8' https://webgw.localdomain/irisrsc/csp/myrsc/private -s | jq
echo ""
