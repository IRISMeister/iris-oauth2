Include MyApp.common

Class MyApp.Login Extends %CSP.Page
{

Parameter SCOPES = "openid profile offline_access ";

ClassMethod OnPage() As %Status
{

  &html<<html>
<head>
  <style>
  
  .portalLogo {
    color: rgb(53,107,141);
    position: relative;
    font-weight: bold;
    font-size: 12pt;
    top: 0px;
    right: 0px;
    border: 2px solid rgb(53,107,141);
    padding: 2px;
    padding-left: 5px;
    padding-right: 5px;
    border-radius: 4px;
    background: #E0E0F0;
  }

  .portalLogoBox {
      position: static;
      padding: 10px;
      padding-bottom: 4px;
      padding-right: 30px;
      text-align: center;
  }

  .portalLogoSub {
      position: relative;
      color: #808080;
      font-size: 8pt;
      top: 3px;
      right: 0px;
  }
  
  </style>
  
</head>
<body>
  <h1>Authenticating and Authorizing against InterSystems IRIS OAuth2 provider</h1>
  <p>このページのデモでは、OAuth2 認証を使用して InterSystems IRIS API 関数を呼び出す方法について説明します。
  <p>InterSystems IRIS 認証および認可サーバを呼び出して、別の InterSystems IRIS サーバに格納されているデータへのアクセスをアプリケーションに許可します。 
>
  
  Set config={}.%FromJSON(^config)
  Set scope=..#SCOPES_config.apps.%Get($$$APP).SCOPES
  Set ns=$ZCVT($NAMESPACE,"L") 
  set url=##class(%SYS.OAuth2.Authorization).GetAuthorizationCodeEndpoint(
    $$$APP,
    scope,
    "https://webgw.localdomain/"_##class(%SYSTEM.INetInfo).LocalHostName()_"/csp/"_ns_"/MyApp.AppMain.cls",
    .properties,
    .isAuthorized,
    .sc)
  if $$$ISERR(sc) {
    write "GetAuthorizationCodeEndpoint Error="
    write ..EscapeHTML($system.Status.GetErrorText(sc))_"<br>",!
  } 
  
  &html<
  <div class="portalLogoBox"><a class="portalLogo" href="#(url)#">oAuth2認証を行う</a></div>
  </body></html>>
  Quit $$$OK
}

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
  Set config={}.%FromJSON(^config)

  #dim %response as %CSP.Response

  Set scope=..#SCOPES_config.apps.%Get($$$APP).SCOPES
  if ##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,,scope,.accessToken,.idtoken,.responseProperties,.error) {
    set %response.Redirect="MyApp.AppMain.cls"
  }
  Return $$$OK
}

}
