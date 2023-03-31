Class MyApps.Installer
{

ClassMethod setup(ByRef tVars) As %Status
{
  Set tSC='$$$OK
  Set Namespace="MYAPP"
  If $D(tVars("Namespace")) { Set Namespace=tVars("Namespace") }
  Set home="/home/irisowner/"
  set origin="https://webgw.localdomain/"
  Set dbgorigin="http://webgw.localdomain:4200/"
  Set iamorigin="https://webgw.localdomain:8443/"
  Try {
    Set oldns=$NAMESPACE
    New $NAMESPACE

    Set $NAMESPACE="USER"
    Do ##class(%SYSTEM.OBJ).Load(home_"src/API/Util.mac","ck")

    Set $NAMESPACE="%SYS"

    #; Loading customization classes
    Do ##class(%SYSTEM.OBJ).ImportDir(home_"src/%ZOAuth2","*","ck",,1)
    #; wonder if Cpf merge does this or not. 
    Do ##class(Security.Users).UnExpireUserPasswords("*")

    #; Accept /irisauth/ as CSP path.
    Do ##class(%SYSTEM.CSP).SetConfig("CSPConfigName","irisauth")

    #; SSL/TLS Configuration
    Kill props
    Set props("CertificateFile")=home_"ssl/auth/server.crt"
    Set props("Description")="oAuth2 Authserver"
    Set props("PrivateKeyFile")=home_"ssl/auth/server.key"
    Set tSC = ##Class(Security.SSLConfigs).Create("authserver",.props)
    $$$ThrowOnError(tSC)

    #; https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GOAUTH_authz#GOAUTH_authz_code_flow
    #; https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GOAUTH_configprog
    #; When configuring IRIS as an authorization server:
    #; authorization server configuration -> client description 

    #; authorization server configuration
    #; to open existing, 
    #; $ docker compose exec irisauth iris session iris -U%SYS
    #; %SYS> s cnf=##class(OAuth2.Server.Configuration).%OpenId("singleton")
    Set cnf=##class(OAuth2.Server.Configuration).%New()
    Set cnf.AccessTokenInterval = 3600
    Set cnf.AllowPublicClientRefresh = 1
    Set cnf.AllowUnsupportedScope = 0
    Set cnf.AudRequired = 0
    Set cnf.AuthenticateClass = "%ZOAuth2.Server.MyAuthenticate" 
    Set cnf.AuthorizationCodeInterval = 60
    Set cnf.ClientSecretInterval = 86400
    Set cnf.CustomizationNamespace = "%SYS"
    Set cnf.CustomizationRoles = "%DB_IRISSYS,%Manager"
    Set cnf.DefaultScope = ""
    Set cnf.Description = "Demo auth server"
    Set cnf.EncryptionAlgorithm = ""
    Set cnf.ForcePKCEForConfidentialClients = 0
    Set cnf.ForcePKCEForPublicClients = 1
    #; see link below about this class. 
    #; https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GOAUTH_authz#GOAUTH_authz_oauth2serverjwt
    Set cnf.GenerateTokenClass = "%OAuth2.Server.JWT"
    Set issuer=##class(OAuth2.Endpoint).%New()
    Set issuer.Host = "webgw.localdomain"
    Set issuer.Prefix = "irisauth/authserver"
    Set issuer.UseSSL = 1
    Set cnf.IssuerEndpoint = issuer
    Set cnf.JWKSFromCredentials = 0
    Set cnf.KeyAlgorithm = ""
    Set cnf.RefreshTokenInterval = 86400
    Set cnf.ReturnRefreshToken = "a"
    Set cnf.SSLConfiguration = "authserver"
    Set cnf.ServerCredentials = ""
    Set cnf.ServerPassword = ""
    Set cnf.SessionClass = "OAuth2.Server.Session"
    Set cnf.SessionInterval = 86400
    Set cnf.SigningAlgorithm = "RS512"
    Set cnf.SupportedGrantTypes="APJ" ; "J" is https://www.rfc-editor.org/rfc/rfc7523.html#section-2.1
    Set cnf.SupportSession = 1
    Do cnf.SupportedScopes.SetAt("first scope","scope1")
    Do cnf.SupportedScopes.SetAt("2nd scope","scope2")
    
    #;Set cnf.ValidateUserClass = "%OAuth2.Server.Validate"
    Set cnf.ValidateUserClass = "%ZOAuth2.Server.MyValidate"
    Set cnf.Metadata."grant_types_supported"=$LISTBUILD("password","authorization_code","jwt_authorization","refresh_token")

    #; support front channel logout with sid 
    Set cnf.Metadata."frontchannel_logout_session_supported" = 1
    Set cnf.Metadata."frontchannel_logout_supported" = 1

    Set tSC=cnf.%Save()
    $$$ThrowOnError(tSC)

    #; コンテナを起動するたびにclient_idやclient_secretが変わるのを避けるため、可能な範囲のクライアント登録をビルド時に行う。
    #;
    #; client description for python code
    #;
    Set c=##class(OAuth2.Server.Client).%New()
    Set c.ClientCredentials = ""
    Set c.ClientType = "confidential"
    Set c.DefaultScope = ""
    Set c.Description = "python demo"
    Set c.LaunchURL = ""
    Set c.Metadata."grant_types" = $lb("authorization_code","jwt_authorization","refresh_token")
    Set c.Metadata."response_types" = $lb("code")
    Set c.Metadata."token_endpoint_auth_method" = "client_secret_basic"
    Set c.Metadata."token_endpoint_auth_signing_alg" = "RS512"
    Set c.Metadata."access_token_signed_response_alg" = "RS512"
    Set c.Metadata."id_token_signed_response_alg" = "RS512"
    Set c.Metadata."frontchannel_logout_uri" = "https://localhost:8080/fclogout"
    Set c.Name = "python"
    Do c.RedirectURL.SetAt("http://localhost:8080/","1") ; this is where python client's webserver is listeing to.
    Set tSC=c.%Save()
    $$$ThrowOnError(tSC)
    #; Save a client id and a secret into a json file
    Set issueruri="https://"_issuer.Host_"/"_issuer.Prefix_"/oauth2"
    Set j1={"client_id":(c.ClientId),"client_secret":(c.ClientSecret),"issuer_uri":(issueruri)}
    Set file=home_"credentials_python.json" o file:"nws" u file w j1.%ToJSON() c file
    Set file=home_"clientid.txt" o file:"nws" u file w c.ClientId,! c file

    #;
    #; client description for curl (RFC 6749 Resource Owner Password Credentials)
    #;
    Set c=##class(OAuth2.Server.Client).%New()
    Set c.ClientCredentials = ""
    Set c.ClientType = "public"
    Set c.DefaultScope = ""
    Set c.Description = "curl + RO password test"
    Set c.LaunchURL = ""
    Set c.Metadata."grant_types" = $lb("password")
    Set c.Metadata."response_types" = $lb("code","id_token","id_token token","token")
    Set c.Metadata."token_endpoint_auth_method" = "client_secret_basic"
    Set c.Metadata."token_endpoint_auth_signing_alg" = "RS512"
    Set c.Metadata."access_token_signed_response_alg" = "RS512"
    Set c.Metadata."id_token_signed_response_alg" = "RS512"
    Set c.Name = "curl"
    Do c.RedirectURL.SetAt("http://localhost:8080/","1") ; this is dummy. Not used by RFC 6749. 
    Set tSC=c.%Save()
    $$$ThrowOnError(tSC)
    #; Save a client id and a secret into a json file
    Set issueruri="https://"_issuer.Host_"/"_issuer.Prefix_"/oauth2"
    Set j1={"client_id":(c.ClientId),"client_secret":(c.ClientSecret),"issuer_uri":(issueruri)}
    Set file=home_"credentials_curl.json" o file:"nws" u file w j1.%ToJSON() c file
    Set file=home_"clientid_curl.txt" o file:"nws" u file w c.ClientId,! c file

    #;
    #; client description for angular client (SPA) for /myapp/
    #;
    Set c=##class(OAuth2.Server.Client).%New()
    Set c.ClientCredentials = ""
    Set c.ClientType = "public"
    Set c.DefaultScope = ""
    Set c.Description = "Angular demo"
    Set c.LaunchURL = ""
    Set c.Metadata."grant_types" = $lb("authorization_code","jwt_authorization","refresh_token")
    Set c.Metadata."response_types" = $lb("code")
    Set c.Metadata."token_endpoint_auth_method" = "client_secret_post"
    Set c.Metadata."token_endpoint_auth_signing_alg" = "RS512"
    Set c.Metadata."access_token_signed_response_alg" = "RS512"
    Set c.Metadata."id_token_signed_response_alg" = "RS512"
    Set c.Metadata."frontchannel_logout_uri" = origin_"myapp/#/logout"
    Set c.Metadata."post_logout_redirect_uris" = $LB(origin_"myapp/#/home",origin_"myapp/",dbgorigin_"myapp/#/home",dbgorigin_"myapp/")
    Set c.Name = "angular"
    Do c.RedirectURL.SetAt(origin_"myapp/#/callback","1")
    Do c.RedirectURL.SetAt(origin_"myapp/#/callback-bff","2") // for BFF
    Do c.RedirectURL.SetAt(dbgorigin_"myapp/#/callback","3") // for debugging via ng serve 
    Do c.RedirectURL.SetAt(dbgorigin_"myapp/#/callback-bff","4") // for debugging via ng serve 
    Set tSC=c.%Save()
    $$$ThrowOnError(tSC)
    #; Save a client id and a secret into a json file
    Set issueruri="https://"_issuer.Host_"/"_issuer.Prefix_"/oauth2"
    Set j1={"clientId":(c.ClientId),"clientSecret":(c.ClientSecret),"issuer_uri":(issueruri)}
    Set file=home_"credentials_angular.json" o file:"nws" u file w j1.%ToJSON() c file
    Set file=home_"clientid_angular.txt" o file:"nws" u file w c.ClientId,! c file

    #; Export Angular environment.ts just for convenience
    Set authUri=origin_"irisauth/authserver/oauth2/authorize"
    Set logoutUri=origin_"irisauth/authserver/oauth2/logout"
    Set tokenUri=origin_"irisauth/authserver/oauth2/token"
    Set redirectUri=origin_"myapp/#/callback"
    Set scope="openid scope1"
    Set resourceServerUri=origin_"irisrsc/csp/myrsc/private"
    Set resourceServer2Uri=origin_"irisrsc2/csp/myrsc/private"
    Set auth={"clientId":(c.ClientId),"authUri":(authUri),"logoutUri":(logoutUri),"tokenUri":(tokenUri),"redirectUri":(redirectUri),"scope":(scope),"frontchannel_logout_uri":(c.Metadata."frontchannel_logout_uri" ),"post_logout_redirect_uri":($LIST(c.Metadata."post_logout_redirect_uris",1))}
    Set rsc={"resourceServerUri":(resourceServerUri),"resourceServer2Uri":(resourceServer2Uri)}

    #; ++このエントリは現在未使用だが、無いとAngularアプリが落ちるので、残しておく++
    Set iamresourceServerInfo=iamorigin_"MYAPP/"
    Set iamresourceServerUri=iamorigin_"MYAPP/public"
    Set iamresourceServer2Uri=iamorigin_"MYAPP2/public"
    Set iam={"resourceServerInfo":(iamresourceServerInfo),"resourceServerUri":(iamresourceServerUri),"resourceServer2Uri":(iamresourceServer2Uri)}
    #; --このエントリは現在未使用だが、無いとAngularアプリが落ちるので、残しておく--

    #; Angular用のBFF関連の設定。異なるClient_idを持つ、アプリ群を1個のBFFで処理する構造とする。
    Set bff={"BFFServer":"/irisclient/csp/bffapi","redirectUri":"https://webgw.localdomain/myapp/#/callback-bff"}
    Set j1={"production":"true","env":"production","auth":(auth),"rsc":(rsc),"iam":(iam),"bff":(bff)}
    Set file=home_"environment.prod.ts" o file:"nws" u file
    Set formatter = ##class(%JSON.Formatter).%New()
    Set json="" Do formatter.FormatToString(j1,.json) 
    w "export const environment = ",!,json,! c file

    #; for debug (ng serve)
    Set redirectUri=dbgorigin_"myapp/#/callback"
    Set auth={"clientId":(c.ClientId),"authUri":(authUri),"logoutUri":(logoutUri),"tokenUri":(tokenUri),"redirectUri":(redirectUri),"scope":(scope),"frontchannel_logout_uri":"http://webgw.localdomain:4200/myapp/#/logout","post_logout_redirect_uri":"http://webgw.localdomain:4200/myapp/#/home"}
    Set bff={"BFFServer":"/irisclient/csp/bffapi","redirectUri":"http://webgw.localdomain:4200/myapp/#/callback-bff"}
    Set j1={"production":"false","auth":(auth),"rsc":(rsc),"iam":(iam),"bff":(bff)}
    Set file=home_"environment.ts" o file:"nws" u file
    Set formatter = ##class(%JSON.Formatter).%New()
    Set json="" Do formatter.FormatToString(j1,.json) 
    w "export const environment = ",!,json,! c file


    #;
    #; client description for angular client (SPA) for /myapp2/
    #;
    Set c=##class(OAuth2.Server.Client).%New()
    Set c.ClientCredentials = ""
    Set c.ClientType = "public"
    Set c.DefaultScope = ""
    Set c.Description = "Angular demo 2"
    Set c.LaunchURL = ""
    Set c.Metadata."grant_types" = $lb("authorization_code","jwt_authorization","refresh_token")
    Set c.Metadata."response_types" = $lb("code")
    Set c.Metadata."token_endpoint_auth_method" = "client_secret_post"
    Set c.Metadata."token_endpoint_auth_signing_alg" = "RS512"
    Set c.Metadata."access_token_signed_response_alg" = "RS512"
    Set c.Metadata."id_token_signed_response_alg" = "RS512"
    Set c.Metadata."frontchannel_logout_uri" = origin_"myapp2/#/logout"
    Set c.Metadata."post_logout_redirect_uris" = $LB(origin_"myapp2/#/home",origin_"myapp2/",dbgorigin_"myapp2/#/home",dbgorigin_"myapp2/")
    Set c.Name = "angular"
    Do c.RedirectURL.SetAt(origin_"myapp2/#/callback","1")
    Do c.RedirectURL.SetAt(origin_"myapp2/#/callback-bff","2") // for BFF
    Do c.RedirectURL.SetAt(dbgorigin_"myapp2/#/callback","3") // for debugging via ng serve 
    Do c.RedirectURL.SetAt(dbgorigin_"myapp2/#/callback-bff","4") // for debugging via ng serve 
    Set tSC=c.%Save()
    $$$ThrowOnError(tSC)
    #; Save a client id and a secret into a json file
    Set issueruri="https://"_issuer.Host_"/"_issuer.Prefix_"/oauth2"
    Set j1={"clientId":(c.ClientId),"clientSecret":(c.ClientSecret),"issuer_uri":(issueruri)}
    Set file=home_"credentials_angular2.json" o file:"nws" u file w j1.%ToJSON() c file
    Set file=home_"clientid_angular2.txt" o file:"nws" u file w c.ClientId,! c file

    #; Export Angular environment.ts just for convenience
    Set authUri=origin_"irisauth/authserver/oauth2/authorize"
    Set logoutUri=origin_"irisauth/authserver/oauth2/logout"
    Set tokenUri=origin_"irisauth/authserver/oauth2/token"
    Set redirectUri=origin_"myapp2/#/callback"
    Set scope="openid scope1"
    Set resourceServerUri=origin_"irisrsc/csp/myrsc/private"
    Set resourceServer2Uri=origin_"irisrsc2/csp/myrsc/private"
    Set auth={"clientId":(c.ClientId),"authUri":(authUri),"logoutUri":(logoutUri),"tokenUri":(tokenUri),"redirectUri":(redirectUri),"scope":(scope),"frontchannel_logout_uri":(c.Metadata."frontchannel_logout_uri" ),"post_logout_redirect_uri":($LIST(c.Metadata."post_logout_redirect_uris",1))}
    Set rsc={"resourceServerUri":(resourceServerUri),"resourceServer2Uri":(resourceServer2Uri)}

    #; ++このエントリは現在未使用だが、無いとAngularアプリが落ちるので、残しておく++
    Set iamresourceServerInfo=iamorigin_"MYAPP/"
    Set iamresourceServerUri=iamorigin_"MYAPP/public"
    Set iamresourceServer2Uri=iamorigin_"MYAPP/public"
    Set iam={"resourceServerInfo":(iamresourceServerInfo),"resourceServerUri":(iamresourceServerUri),"resourceServer2Uri":(iamresourceServer2Uri)}
    #; --このエントリは現在未使用だが、無いとAngularアプリが落ちるので、残しておく--

    #; /myapp2/用のBFF
    Set bff2={"BFFServer":"/irisclient/csp/bff2api","redirectUri":"https://webgw.localdomain/myapp2/#/callback-bff"}
    Set j1={"production":"true","env":"production2","auth":(auth),"rsc":(rsc),"iam":(iam),"bff":(bff2)}
    Set file=home_"environment.prod2.ts" o file:"nws" u file
    Set formatter = ##class(%JSON.Formatter).%New()
    Set json="" Do formatter.FormatToString(j1,.json) 
    w "export const environment = ",!,json,! c file


    #; (irisauthが存在しない)ビルド時には実行できないため、CSPベースのWebAppやIRISベースのリソースサーバはOpenID Connect Discovery and Dynamic Client Registrationを使用して登録する。
    #; コンテナ起動時に下記コードを実行する。
    #; 実装コード: irisrsc/src/API/Register.mac

    #; ADD REST End point for authorization server 
    #; User Cookie Scopeをlaxに変更する
    kill props
    Set props("AutheEnabled")=64
    Set props("Description")="OAuth 2.0 Authorization Server."
    Set props("DispatchClass")="OAuth2.Server.REST"
    Set props("Enabled")=1
    Set props("MatchRoles")=":%All"
    Set props("NameSpace")="%SYS"
    Set props("Type")=2
    Set props("UserCookieScope")=1
    Set tSC = ##Class(Security.Applications).Create("/authserver/oauth2",.props)
    $$$ThrowOnError(tSC)

    #; Add sample users

    Set tSC=##class(Security.Users).Create("test",,"test","テスト太郎",,,,0,1,"sample user",,"01234567",,,1,1)
    kill prop Set tSC=##class(Security.Users).Get("test",.prop)
    Set prop("EmailAddress")="test@examples.com"
    Set tSC=##class(Security.Users).Modify("test",.prop)

    Set tSC=##class(Security.Users).Create("demo",,"demo","デモ次郎",,,,0,1,"sample user",,"01234999",,,1,1)
    kill prop Set tSC=##class(Security.Users).Get("test",.prop)
    Set prop("EmailAddress")="demo@examples.com"
    Set tSC=##class(Security.Users).Modify("demo",.prop)

    Set $NAMESPACE=oldns

  } Catch(e) {
	  Set tSC=e.AsStatus()
    zw tSC
    #;Do ##class(%SYS.System).WriteToConsoleLog(e.DisplayString())
  }
  Return tSC
}

}
