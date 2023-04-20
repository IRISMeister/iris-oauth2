/// 製品提供のクラスの同メソッドの引数がApp側で取得できない型(OAuth2.AccessToken)だったため作成。
Class %ZSYS.OAuth2.Authorization Extends %RegisteredObject [ System = 4 ]
{

/// AzureはRefreshトークンリクエストにSCOPEが必要
ClassMethod GetAccessTokenRefreshByIdAzure(applicationName As %String, sessionId As %String = "", scopes As %String = "", Output refreshed As %Boolean, Output error As %OAuth2.Error) As %Status
{
	$$$AddAllRoleTemporary
	New $namespace
	Set $namespace="%SYS"

	Do ##class(%OAuth2.Utils).GetDefaultSessionId(.sessionId)
	Set accessToken=##class(OAuth2.AccessToken).OpenForSession(applicationName,sessionId,.sc)
	If $$$ISERR(sc) {
		$$$SysLog(3,"OAuth2","[%ZSYS.OAuth2.Authorization:GetLogoutEndpoint]","Error opening access token for client "_applicationName_" and session "_sessionId)
		Quit sc
	}
	If '$isobject(accessToken) {
		$$$SysLog(3,"OAuth2","[%ZSYS.OAuth2.Authorization:GetLogoutEndpoint]","Access token not found for client "_applicationName_" and session "_sessionId)
		Quit '$$$OK
	}
	
	//Quit ##class(%SYS.OAuth2.Authorization).GetAccessTokenRefresh(accessToken,.refreshed, .error)
	Quit ##class(%ZSYS.OAuth2.Authorization).GetAccessTokenRefresh(accessToken, scopes,.refreshed, .error)
}

ClassMethod GetAccessTokenRefresh(accessToken As OAuth2.AccessToken, scopes As %String = "", Output refreshed As %Boolean, Output error As %OAuth2.Error) As %Status [ Final ]
{
	Set sc=$$$OK
	Set error=""
	Set refreshed=0
	$$$AddAllRoleTemporary ; verified 9/26/16 STC
	New $namespace
	Set $namespace="%SYS"
	
	Try {
		$$$SysLog(3,"OAuth2","[%SYS.OAuth2.Authorization:GetAccessTokenRefresh]","applicationName="_accessToken.ApplicationName_", sessionId="_accessToken.SessionId_", hasRefreshToken="_(accessToken.RefreshToken'=""))
		// If no refresh token, then nothing to do
		If accessToken.RefreshToken="" Quit
				
		// Find the access token object
		// Get http request object and add authentication per RFC 6750
		Set httpRequest=##class(%Net.HttpRequest).%New()
		Set httpRequest.ContentType="application/x-www-form-urlencoded"_$select($$$IsUnicode:"", 1:"; charset=utf-8")
		Set sc=##class(%SYS.OAuth2.AccessToken).AddAuthentication(accessToken.ApplicationName,httpRequest)
		If $$$ISERR(sc) Quit
		
		Set client=##class(OAuth2.Client).Open(accessToken.ApplicationName,.sc)
		If client="" Quit
		
		Do httpRequest.InsertFormData("grant_type","refresh_token")
		Do httpRequest.InsertFormData("refresh_token",accessToken.RefreshToken)
		Do httpRequest.InsertFormData("scope",scopes)
		
		If $$$SysLogLevel>=3 {
			Set formData("grant_type")="refresh_token"
			Set formData("refresh_token")=accessToken.RefreshToken
			Do ##class(%OAuth2.Utils).LogHTTPRequest("[%SYS.OAuth2.Authorization:GetAccessTokenRefresh]",0,
				httpRequest,"POST",client.ServerDefinition.Metadata."token_endpoint",.formData)
		}

		Set sc=httpRequest.Post(client.ServerDefinition.Metadata."token_endpoint")
		
		If $$$ISOK(sc) {
			Set sc=##class(OAuth2.Response).ProcessResponse(httpRequest,accessToken.ApplicationName,accessToken.Scope,accessToken.SessionId,,,.error)
		}
		
		If $$$ISOK(sc) Set refreshed=1
		
	} Catch ex {
		Set sc=ex.AsStatus()
	}
	
	If $$$ISERR(sc) Do ##class(%OAuth2.Utils).LogError("[%SYS.OAuth2.AccessToken:GetAccessTokenRefresh]",0,sc)
	Quit sc
}

ClassMethod GetAccessTokenRefreshById(applicationName As %String, sessionId As %String = "", Output refreshed As %Boolean, Output error As %OAuth2.Error) As %Status
{
	$$$AddAllRoleTemporary
	New $namespace
	Set $namespace="%SYS"

	Do ##class(%OAuth2.Utils).GetDefaultSessionId(.sessionId)
	Set accessToken=##class(OAuth2.AccessToken).OpenForSession(applicationName,sessionId,.sc)
	If $$$ISERR(sc) {
		$$$SysLog(3,"OAuth2","[%ZSYS.OAuth2.Authorization:GetLogoutEndpoint]","Error opening access token for client "_applicationName_" and session "_sessionId)
		Quit sc
	}
	If '$isobject(accessToken) {
		$$$SysLog(3,"OAuth2","[%ZSYS.OAuth2.Authorization:GetLogoutEndpoint]","Access token not found for client "_applicationName_" and session "_sessionId)
		Quit '$$$OK
	}
	
	Quit ##class(%SYS.OAuth2.Authorization).GetAccessTokenRefresh(accessToken, .refreshed, .error)
}

/// 第3引数(sessionId)が無かったので追加 See DP-421492
/// /// GetLogoutEndpoint returns the URL to be used to redirect logout requests to the
/// Authorization Server according to OpenID Connect RP-Initiated Logout.
/// This URL should be used for a button, anchor or in Javascript code in a page.<br>
/// The applicationName argument is the name of the application for which the current session is to be logged out.
/// The redirectURL argument is the URL of the CSP page which should be redirected to after the logout request
/// is completed on the server.<br>
ClassMethod GetLogoutEndpoint(applicationName As %String, redirectURL As %String = "", sessionId As %String = "") As %String
{
	Set url=""
	$$$AddAllRoleTemporary
	New $namespace
	Set $namespace="%SYS"

	// Open the client
	Set client = ##class(OAuth2.Client).Open(applicationName,.sc)
	If $$$ISERR(sc) || '$isobject(client) {
		$$$SysLog(3,"OAuth2","[%SYS.OAuth2.Authorization:GetLogoutEndpoint]","Client not found with name '"_applicationName_"' sc="_$System.Status.GetErrorText(sc))
		Return url
	}
	
	If client.ServerDefinition.Metadata."end_session_endpoint"="" {
		$$$SysLog(3,"OAuth2","[%SYS.OAuth2.Authorization:GetLogoutEndpoint]","Server for client '"_applicationName_"' does not support front-channel logout.")
		Return url
	}

	// Get the client's access token for the current session
	Do ##class(%OAuth2.Utils).GetDefaultSessionId(.sessionId)
	Set accessToken=##class(OAuth2.AccessToken).OpenForSession(applicationName,sessionId,.sc)
	If $$$ISERR(sc) || '$isobject(accessToken) {
		$$$SysLog(3,"OAuth2","[%SYS.OAuth2.Authorization:GetLogoutEndpoint]","Error opening access token for client '"_applicationName_"' and session '"_sessionId_"' sc="_$System.Status.GetErrorText(sc))
		Return url
	}

	// If there's no ID token for the current session, then there is no OpenID Connect session to logout
	If accessToken.IDToken="" {
		$$$SysLog(3,"OAuth2","[%SYS.OAuth2.Authorization:GetLogoutEndpoint]","No ID token for client "_applicationName_" and session "_sessionId)
		Return url
	}

	If redirectURL="" Set redirectURL=%request.URL

	If (accessToken.LogoutState="") || (accessToken.LogoutRedirectURL'=redirectURL) {
		Set accessToken.LogoutState = ##class(%SYS.OAuth2.Authorization).CreateState()
		Set accessToken.LogoutRedirectURL = redirectURL
		Set sc = accessToken.%Save()
		If $$$ISERR(sc) {
			$$$SysLog(3,"OAuth2","[%SYS.OAuth2.Authorization:GetLogoutEndpoint]","Error saving logout redirect URL for client "_applicationName_" and session "_sessionId)
			Return url
		}
	}

	// Construct the url to return
	Set url = ##class(OAuth2.Server.Configuration).GetCSPApplication(0)_"/OAuth2.PostLogoutRedirect.cls?register="_accessToken.LogoutState
	Return url
}

}
