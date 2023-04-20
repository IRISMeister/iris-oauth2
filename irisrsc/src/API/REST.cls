Include common

/// from https://github.com/dkutac/cache-auth-demo-2/blob/master/src/server/REST.cls
Class API.REST Extends %CSP.REST
{

Parameter AUD = "https://webgw.localdomain/irisrsc/csp/myrsc";

Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/" Method="GET" Call="GetVersion" Cors="true" />
<Route Url="/public" Method="POST" Call='GetDealsPublic' Cors="true" />
<Route Url="/public" Method="GET" Call='GetDealsPublic' Cors="true" />
<Route Url="/private" Method="POST" Call='GetDealsPrivate' Cors="true" />
<Route Url="/private" Method="GET" Call='GetDealsPrivate' Cors="true" />
</Routes>
}

ClassMethod GetVersion() As %Status
{
	set %response.ContentType="application/json"
	w "{ ""version"":"""_$zv_""" }"
	return $$$OK
}

ClassMethod GetDealsPublic() As %Status
{
	return ..GetDeals("public")
}

ClassMethod GetDealsPrivate() As %Status
{
	return ..GetDeals("private")
}

ClassMethod GetDeals(pType As %String) As %Status
{
	#dim %response as %CSP.Response
	#dim e as %Exception.AbstractException
	set %response.ContentType="application/json"
	
	#dim tSC as %Status = $$$OK
	try {
		set reason=..#HTTP500INTERNALSERVERERROR
		if pType="private" {
			// extract access token
			set accessToken=##class(%SYS.OAuth2.AccessToken).GetAccessTokenFromRequest(.tSC)
			$$$ThrowOnError(tSC)
			If accessToken="" {
				set reason=..#HTTP401UNAUTHORIZED
				throw ##class(%Exception.General).%New("NoAccessToken","5001","GetDeals")
			}
			
			Set config="" If $D(^config) {
        		Set config={}.%FromJSON(^config)
    		}

			// Azure(OP)の場合、ATの"aud"クレームには送信元のRPのAppId(クライアントID)のみが格納されているので
			// 自分宛てに発行されたかどうかの確認にならないため、チェックしない。
			If config.OP="azure"{
				Set aud=""
			}
			else {
				Set aud=..#AUD
			}
			// validate signed access token (JWT)
			if '(##class(%SYS.OAuth2.Validation).ValidateJWT($$$APP,accessToken,,aud,.jsonObjectJWT,.securityParameters,.tSC)) {
				set reason=..#HTTP401UNAUTHORIZED
				$$$ThrowOnError(tSC)
			}
			// 署名の有無の確認
			Set sigalg=$G(securityParameters("sigalg"))
			if sigalg="" { 
				set reason=..#HTTP401UNAUTHORIZED
				$$$ThrowOnError(tSC)				
			}

			// check whether the request is asking for proper scope for this service
			// MS's scope is "scp"
			If config.OP="azure" {
				Set scope=jsonObjectJWT.%Get("scp")
			}
			Else {
				Set scope=jsonObjectJWT.%Get("scope")
			}
			if '(scope_" "["scope1 ") { set reason=..#HTTP404NOTFOUND throw }

			// irisauthへの通信を伴うGetIntrospection()実行は、opaqueなトークンであれば必須だがJWTの場合は任意。
#if 0
			$$$THROWONERROR(tSC,##class(%SYS.OAuth2.AccessToken).GetIntrospection($$$APP,accessToken,.jsonObjectAT))
			/* service specific check */

			// check if aud includes this recipient(URL)
			// see https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.3
			Set audmatch=0
			Set iterator=jsonObjectAT.aud.%GetIterator()
			While iterator.%GetNext(.key,.value) {
				If (value=..#AUD) { Set audmatch=1 Quit }
			}
			If audmatch=0 {
				set reason=..#HTTP401UNAUTHORIZED
				throw ##class(%Exception.General).%New("NoAccessToken","5001","GetDeals")
			}

			// check whether the request is asking for proper scope for this service
			if '(jsonObjectJWT.scope_" "["scope1 ") { set reason=..#HTTP404NOTFOUND throw }
#endif
		}
		Else {
			Set sigalg=""
			Set jsonObjectJWT={}
		}

		Set exp=jsonObjectJWT.exp
        Set info={"HostName":(##class(%SYSTEM.INetInfo).LocalHostName()),"UserName":($USERNAME),"sub":(jsonObjectJWT.sub),"aud":(jsonObjectJWT.aud),"sigalg":(sigalg),"Status":"OK","TimeStamp":($ZDATETIME($H)),"exp":(exp_"("_$ZDATETIME($ZDATETIMEH(exp,-2),3)_")")}
		Set info.debug=jsonObjectJWT
		write info.%ToJSON()
	} catch (e) {
		set tSC=..ReportHttpStatusCode(reason,e.AsStatus())	
		Do e.Log()
	}
	return $$$OK
}

}
