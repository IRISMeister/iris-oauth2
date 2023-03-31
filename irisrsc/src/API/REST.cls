Include common

/// from https://github.com/dkutac/cache-auth-demo-2/blob/master/src/server/REST.cls
Class API.REST Extends %CSP.REST
{

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
	#;How to add cookie 
	#;Do %response.SetCookie("CookieTest",%session.SessionId,,"/",,,1) ; httponly
	
	#dim tSC as %Status = $$$OK
	try {
		set reason=..#HTTP500INTERNALSERVERERROR
		if pType="private" {
			/* common check */
			// extract access token
			set accessToken=##class(%SYS.OAuth2.AccessToken).GetAccessTokenFromRequest(.tSC)
			$$$ThrowOnError(tSC)
			If accessToken="" {
				set reason=..#HTTP401UNAUTHORIZED
				throw ##class(%Exception.General).%New("NoAccessToken","5001","GetDeals")
			}

			// validate signed access token (JWT)
			if '(##class(%SYS.OAuth2.Validation).ValidateJWT($$$APP,accessToken,,,.jsonObjectJWT,.securityParameters,.tSC)) {
				set reason=..#HTTP401UNAUTHORIZED
				$$$ThrowOnError(tSC)
			}

			Set audmatch=0
			Set iterator=jsonObjectJWT.aud.%GetIterator()
			While iterator.%GetNext(.key,.value) {
				If (value="https://webgw.localdomain/irisrsc/csp/myrsc") { Set audmatch=1 Quit }
			}
			If audmatch=0 {
				set reason=..#HTTP401UNAUTHORIZED
				throw ##class(%Exception.General).%New("NoAccessToken","5001","GetDeals")
			}

			// check whether the request is asking for proper scope for this service
			if '((jsonObjectJWT.scope["scope1")||(jsonObjectJWT.scope["scope2")) set reason=..#HTTP404NOTFOUND throw

#if 0
			// irisauthへの通信を伴うGetIntrospection()実行は、opaqueなトークンであれば必須だがJWTの場合は任意。
			$$$THROWONERROR(tSC,##class(%SYS.OAuth2.AccessToken).GetIntrospection($$$APP,accessToken,.jsonObjectAT))
			/* service specific check */

			// check if aud includes this recipient(URL)
			// see https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.3
			Set audmatch=0
			Set iterator=jsonObjectAT.aud.%GetIterator()
			While iterator.%GetNext(.key,.value) {
				If (value="https://webgw.localdomain/irisrsc/csp/myrsc") { Set audmatch=1 Quit }
			}
			If audmatch=0 {
				set reason=..#HTTP401UNAUTHORIZED
				throw ##class(%Exception.General).%New("NoAccessToken","5001","GetDeals")
			}

			// check whether the request is asking for proper scope for this service
			if '((jsonObjectJWT.scope["scope1")||(jsonObjectJWT.scope["scope2")) set reason=..#HTTP404NOTFOUND throw
#endif
		}
		Else {
			Set jsonObjectJWT={}
		}

		Set exp=jsonObjectJWT.exp
        Set info={"HostName":(##class(%SYSTEM.INetInfo).LocalHostName()),"UserName":($USERNAME),"sub":(jsonObjectJWT.sub),"aud":(jsonObjectJWT.aud),"Status":"OK","TimeStamp":($ZDATETIME($H)),"exp":(exp_"("_$ZDATETIME($ZDATETIMEH(exp,-2),3)_")")}
		Set info.debug=jsonObjectJWT
		write info.%ToJSON()
	} catch (e) {
		set tSC=..ReportHttpStatusCode(reason,e.AsStatus())	
	}
	return $$$OK
}

}
