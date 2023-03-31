Class MyApps.Installer
{

XData setup [ XMLNamespace = INSTALLER ]
{
<Manifest>
  <Namespace Name="USER" Create="no">
    <Import File="${SRCDIR}/API/" Flags="ck" Recurse="true"/>
    <Import File="${SRCDIR}/MyApp/" Flags="ck" Recurse="true"/>
  </Namespace>
</Manifest>
}

ClassMethod setupMethod(ByRef pVars, pLogLevel As %Integer = 3, pInstaller As %Installer.Installer, pLogger As %Installer.AbstractLogger) As %Status [ CodeMode = objectgenerator, Internal ]
{
  Quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "setup")
}

ClassMethod setup(ByRef tVars) As %Status
{
  Set tSC='$$$OK
  Try {
    Set Namespace="MYAPP"
    Set webapp="/csp/"_Namespace

    If '$D(tVars("SRCDIR")) { Set tVars("SRCDIR")="/home/irisowner/src" } // csp app as a client
    Set tSC=..setupMethod(.tVars)
    $$$ThrowOnError(tSC)

    Set oldns=$NAMESPACE
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    Do ##class(Security.Users).UnExpireUserPasswords("*")

    #; Accept /irisclient/ as CSP path.
    Do ##class(%SYSTEM.CSP).SetConfig("CSPConfigName","irisclient2")

    #; SSL/TLS Configuration
    Kill props
    Set props("CertificateFile")="/home/irisowner/ssl/client/server.crt"
    Set props("Description")="oAuth2 client application"
    Set props("PrivateKeyFile")="/home/irisowner/ssl/client/server.key"
    Set tSC = ##Class(Security.SSLConfigs).Create("client",.props)
    $$$ThrowOnError(tSC)

    #; import ZAUTHENTICATE
    Set tSC=##class(%SYSTEM.OBJ).ImportDir("/home/irisowner/src/%SYS","*","ck",,1)

    #; Enable delegate on System wide
    Kill props
    Set tSC=##class(Security.System).Get(,.props)
    Set props("AutheEnabled")=10239 ; enable delegate
    Set tSC = ##Class(Security.System).Modify(,.props)

    #; Enable delegate on %Service_WebGateway
    Kill props
    Set tSC=##class(Security.Services).Get("%Service_WebGateway",.props)
    Set props("AutheEnabled")=8224 ; enable password + delegate
    Set tSC=##class(Security.Services).Modify("%Service_WebGateway",.props)

    #; Accept delegate only on /csp/user webapp
		Set webapp="/csp/user"
    Kill props
		Set tSC = ##Class(Security.Applications).Get(webapp,.props)
		Set props("AutheEnabled")=8192 ; delegate only
    #; front channel logoutのためにSession Cookie Scopeをnoneに変更する
		Set props("SessionScope")=0
    #; 紛らわしいのでGroupByIdをクリア
    Set props("GroupById")=""
    #; Custom login page for oAuth2 login
    Set props("LoginPage")="MyApp.OAuth2Login.cls"
		Set tSC = ##Class(Security.Applications).Modify(webapp,.props)
		$$$ThrowOnError(tSC)
		Set $NAMESPACE=oldns


    Set $NAMESPACE=oldns
  } Catch(e) {
	  Set tSC=e.AsStatus()
    Do ##class(%SYS.System).WriteToConsoleLog(e.DisplayString())
  }
  Return tSC
}

}
