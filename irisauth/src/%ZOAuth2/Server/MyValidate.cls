/// Specify this class as an Authenticate class in customization screen of Auth server.
Class %ZOAuth2.Server.MyValidate Extends %OAuth2.Server.Validate
{

ClassMethod ValidateUser(username As %String, password As %String, scope As %ArrayOfDataTypes, properties As %OAuth2.Server.Properties, Output sc As %Status) As %Boolean
{
	New $Namespace
	Set $Namespace = "%SYS"
	
	If '##super(username, password, scope, properties, .sc) {
		Quit '$$$OK
	}

	#; add custom claims to access_token and introspection.
	Set newclaim = ##class(%OAuth2.Server.Claim).%New()

	Set claimName="customer_id",claimValue="RSC-00001"
	Do properties.SetClaimValue(claimName, claimValue)
	Do properties.JWTClaims.SetAt("",claimName)
	Do properties.IntrospectionClaims.SetAt(newclaim, claimName)

	#; these claims are handled by SuperClass (%OAuth2.Server.Validate.cls). Just making them visible here.
	For claimName="phone_number","email" {
		If properties.GetClaimValue(claimName,.type)'="" {
			Do properties.JWTClaims.SetAt("",claimName)
			Do properties.IntrospectionClaims.SetAt(newclaim, claimName)
		}
	}

	#; https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.3
	#; Each principal intended to process the JWT MUST
   	#; identify itself with a value in the audience claim.  If the principal
   	#; processing the claim does not identify itself with a value in the
    #; "aud" claim when this claim is present, then the JWT MUST be
    #; rejected.
	#; 上記仕様に沿って、audにclient_idとリソースサーバを識別するURLを付与。
#if 1
	Set claimName="aud"
	Set clientid=properties.RequestProperties.GetAt("client_id")
	Set claimValue=$LB("https://webgw.localdomain/irisrsc/csp/myrsc","https://webgw.localdomain/irisrsc2/csp/myrsc",clientid)

	Do properties.SetClaimValue(claimName, claimValue)
	#; "aud" クレームはフレームワーク側で自動的に追加されるので、下記のAPI呼び出しは不要
	#;Do properties.JWTClaims.SetAt("",claimName) 
	#;Do properties.IntrospectionClaims.SetAt(newclaim, claimName)
#endif
	
	Set sc=$$$OK ; need try...catch

	Quit sc
}

}
