#!/bin/bash

source ./params.sh

client_id_iam=$(cat client/credentials_iam.json | jq -r .client_id)
client_secret_iam=$(cat client/credentials_iam.json | jq -r .client_secret)

while [ -z "$iam_hostname" ]
do
  sleep 1
  iam_hostname=$(curl -s http://localhost:8001/ | jq -r '.hostname')
done

# KONGからアップストリーム(リソースサーバ)へのアクセスをhttps化するために使用
result=$(curl -s -X POST -F "cert=$(cat ssl/web/server.crt)" -F "key=$(cat ssl/web/server.key)" http://localhost:8001/certificates)
certificate_id=$(echo $result | jq -r '.id')
echo $certificate_id
if [ -z "$certificate_id" ] || [ "$certificate_id" = "null" ] ; then
  echo "certificate_id is null. Quitting."
  echo $result
  exit 
fi

# Add SNI
result=$(curl -s -X POST -F "name=$HOST_NAME" http://localhost:8001/certificates/$certificate_id/snis)
sni_id=$(echo $result | jq -r '.id')
echo $sni_id
if [ -z "$sni_id" ] || [ "$sni_id" = "null" ] ; then
  echo "sni_id is null. Quitting."
  echo $result
  exit 
fi

# Add service HOME, will handle
# https://webgw.localdomain:8443/myapp/
# https://webgw.localdomain:8443/myapp/#/home
# https://webgw.localdomain:8443/#/callback
# https://webgw.localdomain:8443/#/info-iam
# https://webgw.localdomain:8443/irisauth/authserver/oauth2/authorize
# 
# See this why this is needed
# https://infi.nl/nieuws/spa-necromancy/
result=$(curl -s -X POST -d "name=HOME" -d "host=$HOST_NAME" -d "protocol=https" -d "port=443" -d "client_certificate.id=$certificate_id" -d "path=/" http://localhost:8001/services)
service_id=$(echo $result | jq -r '.id')
if [ -z "$service_id" ] || [ "$service_id" = "null" ] ; then
  echo "service_id is null. Quitting."
  echo $result
  exit 
fi

# Add route HOMERoute
result=$(curl -s -X POST -d "name=HOMERoute" -d "paths[]=/" -d "strip_path=false" http://localhost:8001/services/HOME/routes)
route_id=$(echo $result | jq -r '.id')
if [ -z "$route_id" ] || [ "$route_id" = "null" ] ; then
  echo "route_id is null. Quitting."
  echo $result
  exit 
fi

# Add service myrsc for Resource Server #1
result=$(curl -s -X POST -d "name=myrsc" -d "host=$HOST_NAME" -d "protocol=https" -d "port=443" -d "client_certificate.id=$certificate_id" -d "path=/irisrsc/csp/myrsc" http://localhost:8001/services)
service_id=$(echo $result | jq -r '.id')
if [ -z "$service_id" ] || [ "$service_id" = "null" ] ; then
  echo "service_id is null. Quitting."
  echo $result
  exit 
fi

# Add route myrscRoute
result=$(curl -s -X POST -d "name=myrscRoute" -d "paths[]=/myrsc" -d "strip_path=true" http://localhost:8001/services/myrsc/routes)
route_id=$(echo $result | jq -r '.id')
if [ -z "$route_id" ] || [ "$route_id" = "null" ] ; then
  echo "route_id is null. Quitting."
  echo $result
  exit 
fi
# この段階で、下記URLで、IAM経由で/irisrsc/csp/myapp/publicにアクセス出来る。元々/CSP/myapp/は認証無しのみが有効なので、認証はされない。
# curl -X POST https://webgw.localdomain:8443/myapp/public

# Add service myrsc2 for Resource Server #2
result=$(curl -s -X POST -d "name=myrsc2" -d "host=$HOST_NAME" -d "protocol=https" -d "port=443" -d "client_certificate.id=$certificate_id" -d "path=/irisrsc2/csp/myrsc" http://localhost:8001/services)
service_id=$(echo $result | jq -r '.id')
if [ -z "$service_id" ] ; then
  echo "service_id is null. Quitting."
  echo $result
  exit 
fi

# Add route myrsc2Route
result=$(curl -s -X POST -d "name=myrsc2Route" -d "paths[]=/myrsc2" -d "strip_path=true" http://localhost:8001/services/myrsc2/routes)
route_id=$(echo $result | jq -r '.id')
if [ -z "$route_id" ] ; then
  echo "route_id is null. Quitting."
  echo $result
  exit 
fi

# Add CORS plugin globally.
#result=$(curl -X POST -d "name=cors" http://localhost:8001/plugins)
#plugin_cors_id=$(echo $result | jq -r '.id')
#if [ -z "$plugin_cors_id" ] ; then
#  echo "plugin_cors_id is null. Quitting."
#  exit 
#fi

# ルートに設定したかったが、1つのルートから複数のサービスに転送する仕組みが無い
# Globalに設定してもうまくいかない。
# https://github.com/Kong/kong/issues/522
# The OpenID Connect Logout plugin implements the OpenID Connect Back-Channel Logout as specified here:
# http://openid.net/specs/openid-connect-backchannel-1_0.html
# IRISはBack-Channel Logoutは未サポートなので、logout_revoke=trueに設定してRevokeしている。その関係で/logoutでエラーになる。
# またback-channelなので、CSPOAuthTokenクッキーをクリアするチャンスが無いので、2回目以降のログインはスキップされる。

result=$(curl -s -X POST \
    -d "name=openid-connect" \
    -d "config.issuer=https://$HOST_NAME/irisauth/authserver/oauth2/.well-known/openid-configuration" \
    -d "config.client_id=$client_id_iam" \
    -d "config.client_secret=$client_secret_iam" \
    -d "config.auth_methods=authorization_code" \
    -d "config.auth_methods=session" \
    -d "config.logout_redirect_uri=https://$HOST_NAME:8443/myapp/#/home" \
    -d "config.logout_uri_suffix=/logout" \
    -d "config.logout_methods=GET" \
    -d "config.logout_revoke=true" \
    -d "config.ssl_verify=false" \
    -d "config.redirect_uri=https://$HOST_NAME:8443/myapp/#/info-iam" \
    -d "config.authorization_endpoint=https://$HOST_NAME/irisauth/authserver/oauth2/authorize" \
    -d "config.consumer_optional=true" \
    -d "config.scopes=openid+profile+scope1" \
    -d "config.upstream_access_token_jwk_header=x_access_token_jwk" \
    -d "config.upstream_id_token_header=x_id_token" \
    -d "config.upstream_id_token_jwk_header=x_id_token_jwk" \
    -d "config.upstream_refresh_token_header=x_refresh_token" \
    -d "config.upstream_user_info_header=x_user_info" \
    -d "config.upstream_introspection_header=x_introspection" \
    -d "config.downstream_access_token_jwk_header=x_access_token_jwk" \
    -d "config.downstream_id_token_header=x_id_token" \
    -d "config.downstream_id_token_jwk_header=x_id_token_jwk" \
    -d "config.downstream_refresh_token_header=x_refresh_token" \
    -d "config.downstream_user_info_header=x_user_info" \
    -d "config.downstream_introspection_header=x_introspection" \
     http://localhost:8001/routes/myrscRoute/plugins 
)

plugin_oidc_id=$(echo $result | jq -r '.id')
if [ -z "$plugin_oidc_id" ] ; then
  echo "plugin_oidc_id is null. Quitting."
  echo $result
  exit 
fi

result=$(curl -s -X POST \
    -d "name=openid-connect" \
    -d "config.issuer=https://$HOST_NAME/irisauth/authserver/oauth2/.well-known/openid-configuration" \
    -d "config.client_id=$client_id_iam" \
    -d "config.client_secret=$client_secret_iam" \
    -d "config.auth_methods=authorization_code" \
    -d "config.auth_methods=session" \
    -d "config.logout_redirect_uri=https://$HOST_NAME:8443/myapp/#/home" \
    -d "config.logout_uri_suffix=/logout" \
    -d "config.logout_methods=GET" \
    -d "config.logout_revoke=true" \
    -d "config.ssl_verify=false" \
    -d "config.redirect_uri=https://$HOST_NAME:8443/myapp/#/info-iam" \
    -d "config.authorization_endpoint=https://$HOST_NAME/irisauth/authserver/oauth2/authorize" \
    -d "config.consumer_optional=true" \
    -d "config.scopes=openid+profile+scope1" \
    -d "config.upstream_access_token_jwk_header=x_access_token_jwk" \
    -d "config.upstream_id_token_header=x_id_token" \
    -d "config.upstream_id_token_jwk_header=x_id_token_jwk" \
    -d "config.upstream_refresh_token_header=x_refresh_token" \
    -d "config.upstream_user_info_header=x_user_info" \
    -d "config.upstream_introspection_header=x_introspection" \
    -d "config.downstream_access_token_jwk_header=x_access_token_jwk" \
    -d "config.downstream_id_token_header=x_id_token" \
    -d "config.downstream_id_token_jwk_header=x_id_token_jwk" \
    -d "config.downstream_refresh_token_header=x_refresh_token" \
    -d "config.downstream_user_info_header=x_user_info" \
    -d "config.downstream_introspection_header=x_introspection" \
     http://localhost:8001/routes/myrsc2Route/plugins 
)

plugin_oidc_id=$(echo $result | jq -r '.id')
if [ -z "$plugin_oidc_id" ] ; then
  echo "plugin_oidc_id is null. Quitting."
  echo $result
  exit 
fi

#
# ToDo:
# -d "config.scopes_required=kong_api_access" が機能しない模様。
# 以下のclaimsという機能を使ってカスタムクレームを利用していると思われるが詳細不明。ひとまず利用しない。
# https://qiita.com/TakahikoKawasaki/items/185d34814eb9f7ac7ef3#15-%E3%82%AF%E3%83%AC%E3%83%BC%E3%83%A0-claim
#
# ssl_verifyがfalseになってるのを直したい
# ssl_verify:  Whether or not should Kong verify SSL Certificates when communicating to OP(IdP).
#
# ログアウトなんとかしたい
