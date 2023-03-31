/// 製品提供のクラスの同メソッドの引数がApp側で取得できない型(OAuth2.AccessToken)だったため作成。
Class %ZSYS.OAuth2.Authorization Extends %RegisteredObject [ System = 4 ]
{

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
