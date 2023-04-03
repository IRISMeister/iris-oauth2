Class MyApp.OAuth2Login Extends %OAuth2.Login
{

/// MyApp.common.incのAPPマクロと合わせること
Parameter APPLICATION As %String = "USER_CLIENT_APP2";

Parameter SCOPE As %String = "openid profile scope1";

}
