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

}
