Include BFF.common

Class BFF.REST Extends %CSP.REST
{

Parameter CHARSET = "utf-8";

Parameter RESOURCEROOT = "https://webgw.localdomain/";

Parameter SSLCONFIG = "client";

Parameter SCOPES = "openid profile email offline_access ";

Parameter SESSIONCOOKIE = "sessionid";

/// 開発中、NG serverからのアクセスを許可するためhttpを許容。
Parameter SECURECOOKIE = 0;

Parameter COOKIEPATH;

Parameter CONTENTTYPE = "application/json";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/getversion" Method="GET" Call="GetVersion" Cors="false" />
<Route Url="/getserverinfo" Method="GET" Call="GetServerInfo" Cors="false" />
<Route Url="/userinfo" Method="GET" Call="GetUserInfo" Cors="false" />
<Route Url="/getauthurl" Method="POST" Call="GetAuthorizationCodeEndpoint" Cors="false" />
<Route Url="/logout" Method="POST" Call="GetLOEndpoint" Cors="false" />
<Route Url="/call" Method="POST" Call="CallResourceServer" Cors="false" />
<Route Url="/isauth" Method="GET" Call="IsAuthorized" Cors="false" />
<Route Url="/refresh" Method="GET" Call="DoRefreshToken" Cors="false" />
<Route Url="/revocation" Method="GET" Call="DoRevoke" Cors="false" />
</Routes>
}

ClassMethod GetVersion() As %Status
{
	/// just a test 
	Do %response.SetCookie("IRIS-version",$zv,,"/",,..#SECURECOOKIE,1) ; httponly

	w "{ ""version"":"""_$zv_""" }"
	return $$$OK
}

ClassMethod GetServerInfo() As %Status
{
	Set tSC='$$$OK
	Set resp={}
	Set ServerInfo={}
    Set config={}.%FromJSON(^config)

	Try {
		Set sessionid=%request.GetCookie(..#SESSIONCOOKIE)
		Set scopes=config.apps.%Get($$$APP).SCOPES
		Set isAuthorized=##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,sessionid,scopes,.accessToken,.idtoken,.responseProperties,.error)

		Set ServerInfo.isAuthorized=isAuthorized
		Set ServerInfo.NameSpace=$NAMESPACE
		Set ServerInfo.UserName=$USERNAME
		Set ServerInfo.Roles=$ROLES
		Set ServerInfo.SessionID=sessionid
		Set ServerInfo.CSPSessionID=%session.SessionId
		Set ServerInfo.Counter=$INCREMENT(%session.Data("COUNTER"))
		Set ServerInfo.AT=accessToken
		Set ServerInfo.IDT=idtoken
		Set ServerInfo.RFT=$G(responseProperties("refresh_token"),"none")
		Set resp.ServerInfo=ServerInfo
		Set tSC=$$$OK
	}
	Catch(e) {
		Do e.Log()
		Set tSC=e.AsStatus()
	}
	
	Do resp.%ToJSON()
	Return tSC
}

ClassMethod GetUserInfo() As %Status
{
	Set tSC='$$$OK
	Set resp={}
    Set config={}.%FromJSON(^config)

	Try {
		Set sessionid=%request.GetCookie(..#SESSIONCOOKIE)
		If sessionid="" {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}
		If config.OP="iris" { Set scopes=..#SCOPES_config.apps.%Get($$$APP).SCOPES } Elseif config.OP="azure" {Set scopes=config.apps.%Get($$$APP).SCOPES}

		Set isAuthorized=##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,sessionid,scopes,.accessToken,.idtoken,.responseProperties,.error)
		If 'isAuthorized {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}

		If config.OP="iris" {
			Set tSC=##class(%SYS.OAuth2.AccessToken).GetUserinfo(
				$$$APP,
				accessToken,,
				.jsonObject)
			$$$ThrowOnError(tSC)
			Set resp.Userinfo=jsonObject
		}
		Elseif config.OP="azure" {
			Set expectedaud=config.apps.%Get($$$APP).ClientId
            Set valid=##class(%SYS.OAuth2.Validation).ValidateIDToken(
                $$$APP,
                idtoken,
                accessToken,
                scopes,
                expectedaud, 
                .jsonObject,
                .securityParameters,
                .sc)

			#; ID Tokenに含まれるクレームから取得する。
			Set resp.Userinfo=jsonObject
		}
		Set tSC=$$$OK
	}
	Catch(e) {
		Do e.Log()
		Set tSC=e.AsStatus()
	}
	
	Do resp.%ToJSON()
	Return tSC
}

ClassMethod IsAuthorized() As %Status
{
	Set tSC='$$$OK
	Set resp={}
    Set config={}.%FromJSON(^config)
	Try {
		Set sessionid=%request.GetCookie(..#SESSIONCOOKIE)
		If sessionid="" {
			Set resp.IsAuthorized=0
		}
		Else {
			If config.OP="iris" { Set scopes=..#SCOPES_config.apps.%Get($$$APP).SCOPES } Elseif config.OP="azure" {Set scopes=config.apps.%Get($$$APP).SCOPES}
			Set isAuthorized=##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,sessionid,scopes,.accessToken,.idtoken,.responseProperties,.error)
			Set resp.IsAuthorized=isAuthorized
		}
		Set tSC=$$$OK
	}
	Catch(e) {
		Do e.Log()
		Set tSC=e.AsStatus()
	}

	Do resp.%ToJSON()
	Return tSC
}

ClassMethod CallResourceServer() As %Status
{
	Set tSC='$$$OK
	Set resp={}
    Set config={}.%FromJSON(^config)

	Try {
		Set content=%request.Content.Read()
		set contentJSON = {}.%FromJSON(content)

		Set sessionid=%request.GetCookie(..#SESSIONCOOKIE)
		If sessionid="" {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}

		If config.OP="iris" { Set scopes=..#SCOPES_config.apps.%Get($$$APP).SCOPES } Elseif config.OP="azure" {Set scopes=config.apps.%Get($$$APP).SCOPES}
		Set isAuthorized=##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,sessionid,scopes,.accessToken,.idtoken,.responseProperties,.error)
		If 'isAuthorized {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}
		Set resp.isAuthorized=isAuthorized
		/***************************************************
		*                                                  *
		*   Call the resource server and return result.    *
		*                                                  *
		***************************************************/
		set httpRequest=##class(%Net.HttpRequest).%New()
		// AddAccessToken adds the current access token to the request.
		set tSC=##class(%SYS.OAuth2.AccessToken).AddAccessToken(
			httpRequest,,
			..#SSLCONFIG,
			$$$APP,
			sessionid)
		$$$ThrowOnError(tSC)

		Set url=contentJSON.endpoint
		Set tSC=httpRequest.Get(url)
		$$$ThrowOnError(tSC)

		Set body=httpRequest.HttpResponse.Data
		if $isobject(body) {
			do body.Rewind()
			set bodystr=body.Read()
		}
		w bodystr,!  // this should be alrady in JSON string

	}
	Catch(e) {
		Do e.Log()
		Set tSC=e.AsStatus()
	}

	Return $$$OK
}

ClassMethod DoRefreshToken() As %Status
{
	Set tSC='$$$OK
	Set resp={}
    Set config={}.%FromJSON(^config)
	Try {
		Set sessionid=%request.GetCookie(..#SESSIONCOOKIE)
		If sessionid="" {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}

		Set refreshed=0,error=""
		If config.OP="iris" { Set scopes=..#SCOPES_config.apps.%Get($$$APP).SCOPES } Elseif config.OP="azure" {Set scopes=config.apps.%Get($$$APP).SCOPES}
		if ##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,sessionid,scopes,.accessToken,.idtoken,.responseProperties,.error) {

			If config.OP="iris" {
				Set tSC=##class(%ZSYS.OAuth2.Authorization).GetAccessTokenRefreshById($$$APP,sessionid, .refreshed, .error) 
			}
			ElseIf config.OP="azure" {
				Set tSC=##class(%ZSYS.OAuth2.Authorization).GetAccessTokenRefreshByIdAzure($$$APP,sessionid,scopes, .refreshed, .error) 
			}        
			$$$ThrowOnError(tSC)
		}
		Else {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}
		Set tSC=$$$OK
	}
	Catch(e) {
		Do e.Log()
		Set tSC=e.AsStatus()
		Do ..ReportHttpStatusCode(500)
	}

	Return tSC
}

ClassMethod DoRevoke() As %Status
{
	Set tSC='$$$OK
	Set resp={}
    Set config={}.%FromJSON(^config)
	Try {
		If config.OP="iris" { Set scopes=..#SCOPES_config.apps.%Get($$$APP).SCOPES } Elseif config.OP="azure" {Set scopes=config.apps.%Get($$$APP).SCOPES}
		Set sessionid=%request.GetCookie(..#SESSIONCOOKIE)
		If sessionid="" {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}
		Do %response.SetCookie(..#SESSIONCOOKIE,"","Thr, 1 Jan 1970 00:00:00 GMT",..#COOKIEPATH,,..#SECURECOOKIE,1) ;secure, httponly

		Set error=""

		if ##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,sessionid,scopes,.accessToken,.idtoken,.responseProperties,.error) {
			Set tSC=##class(%SYS.OAuth2.AccessToken).RevokeToken($$$APP, accessToken) 
			$$$ThrowOnError(tSC)
		}
		Else {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}
		Set tSC=$$$OK
	}
	Catch(e) {
		Do e.Log()
		Set tSC=e.AsStatus()
		Do ..ReportHttpStatusCode(500)
	}

	Return tSC
}

ClassMethod GetAuthorizationCodeEndpoint() As %Status
{
	Set tSC='$$$OK
	Set resp={}
    Set config={}.%FromJSON(^config)
	Try {	

		Set content=%request.Content.Read()
		Set contentJSON = {}.%FromJSON(content)
		Set redirectURI = contentJSON.redirectURI

		#; CSP(staefull)前提の%session.SessionIdは使用しづらい。
		#; かと言ってUseSessionは(何となくではあるが)避けたい。
		#; サーバでユーザ独自のセッションIDを発行して、SPAとのセッション維持に使用する事とする。
		#; 認証が成功した場合、AT,RT等は%SYSのテーブル OAuth2.AccessTokenに保存されている。
		#; select * from OAuth2.AccessToken where SessionId=:sessionid and ApplicationName=:$$$APP)
		#; ただし%SYSへのアクセス権が要るので、参照には既存APIを使用する。

		Set sessionid=%request.GetCookie(..#SESSIONCOOKIE)

		Set authURL=""
		Set IsAuthorized=0
		Set url=""
		Set scopes=..#SCOPES_config.apps.%Get($$$APP).SCOPES

		if ##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,sessionid,scopes,.accessToken,.idtoken,.responseProperties,.error) {
			Set IsAuthorized=1
		}
		Else {
			Set sessionid=##class(%OAuth2.Utils).Base64UrlEncode($system.Encryption.GenCryptRand(12))  // 要変更
			set authURL=##class(%SYS.OAuth2.Authorization).GetAuthorizationCodeEndpoint(
				$$$APP,
				scopes,
				redirectURI,
				.properties,
				.isAuthorized,
				.tSC,,sessionid)
			$$$ThrowOnError(tSC)
		}
		#; return sessionid 
		Do %response.SetCookie(..#SESSIONCOOKIE,sessionid,,..#COOKIEPATH,,..#SECURECOOKIE,1) ; secure,httponly 
		Set resp.authURL=authURL
		Set resp.IsAuthorized=IsAuthorized
		Set tSC=$$$OK
	}
	Catch(e) {
		Do e.Log()
		Set tSC=e.AsStatus()
	}

	Do resp.%ToJSON()
	Return tSC
}

ClassMethod GetLOEndpoint() As %Status
{
	Set tSC='$$$OK
	Set resp={}
    Set config={}.%FromJSON(^config)
	Try {
		Set sessionid=%request.GetCookie(..#SESSIONCOOKIE)
		If sessionid="" {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}

		Set content=%request.Content.Read()
		Set contentJSON = {}.%FromJSON(content)
		Set postLogoutRedirectURI = contentJSON.postLogoutRedirectURI

		Set IsAuthorized=0
		Set url=""
		If config.OP="iris" { Set scopes=..#SCOPES_config.apps.%Get($$$APP).SCOPES } Elseif config.OP="azure" {Set scopes=config.apps.%Get($$$APP).SCOPES}

		If ##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,sessionid,scopes,.accessToken,.idtoken,.responseProperties,.error) {
			Set IsAuthorized=1
			Set url=##class(%ZSYS.OAuth2.Authorization).GetLogoutEndpoint($$$APP,postLogoutRedirectURI,sessionid) ;; need DP-421492
        	#; このURLは、WebGWのpathを考慮していない。本例では/irisclient（もしくは/irisclient2）が必要なので追加する。
        	Set url=$REPLACE(url,"/csp/sys/","/"_##class(%SYSTEM.INetInfo).LocalHostName()_"/csp/sys/")

			#; ユーザエージェントのcookieからsessionidを削除
			Do %response.SetCookie(..#SESSIONCOOKIE,"","Thr, 1 Jan 1970 00:00:00 GMT",..#COOKIEPATH,,..#SECURECOOKIE,1) ;secure, httponly
		}
		If IsAuthorized=0 {
			Do ..ReportHttpStatusCode(401)
			Return $$$OK
		}

		Set resp.logoutURL=url
		Set resp.IsAuthorized=IsAuthorized
		Set tSC=$$$OK
	}
	Catch(e) {
		Do e.Log()
		Set tSC=e.AsStatus()
	}
	Do resp.%ToJSON()
	Return tSC
}

}
