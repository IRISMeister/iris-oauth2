/// Specify this class as an Authenticate class in customization screen of Auth server.
Class %ZOAuth2.Server.MyAuthenticate Extends %OAuth2.Server.Authenticate
{

Parameter DOMAIN = "%OAuth2Login";

ClassMethod BeforeAuthenticate(scope As %ArrayOfDataTypes, properties As %OAuth2.Server.Properties) As %Status
{
	// This scope will be added if scope2 is requested.
#If 1
	If scope.IsDefined("scope2") {
		Do scope.SetAt("scope99. scope2が要求された際に自動追加されます","scope99")
	}
#endif
	Quit $$$OK
}

ClassMethod AfterAuthenticate(scope As %ArrayOfDataTypes, properties As %OAuth2.Server.Properties) As %Status
{
	// Client app can receive these values.
	// Probably you want to use some kind of lookup table or external service to return appropriate value for the authenticated user.
	Do properties.ResponseProperties.SetAt("12345","accountno")

	Quit $$$OK
}

}
