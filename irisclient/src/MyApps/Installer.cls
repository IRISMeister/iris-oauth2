Class MyApps.Installer
{

XData setup [ XMLNamespace = INSTALLER ]
{
<Manifest>
  <Namespace Name="USER" Create="no">
    <Import File="${SRCDIR}/API/" Flags="ck" Recurse="true"/>
    <Import File="${SRCDIR}/MyApp/" Flags="ck" Recurse="true"/>
    <Import File="${SRCDIR}/BFF/" Flags="ck" Recurse="true"/>
  </Namespace>

  <Namespace Name="USER2" Create="yes" Code="USER2" Ensemble="0" Data="USER2">
    <Configuration>
      <Database Name="USER2" Dir="USER2" Create="yes" Resource="%DB_USER2"/>
    </Configuration>

    <Import File="${SRCDIR}/API/" Flags="ck" Recurse="true"/>
    <Import File="${SRCDIR}/MyApp/" Flags="ck" Recurse="true"/>
  </Namespace>

  <Namespace Name="BFF" Create="yes" Code="BFF" Ensemble="0" Data="BFF">
    <Configuration>
      <Database Name="BFF" Dir="BFF" Create="yes" Resource="%DB_BFF"/>
    </Configuration>

    <Import File="${SRCDIR}/API/" Flags="ck" Recurse="true"/>
    <Import File="${SRCDIR}/BFF/" Flags="ck" Recurse="true"/>
  </Namespace>

  <Namespace Name="BFF2" Create="yes" Code="BFF2" Ensemble="0" Data="BFF2">
    <Configuration>
      <Database Name="BFF2" Dir="BFF2" Create="yes" Resource="%DB_BFF2"/>
    </Configuration>

    <Import File="${SRCDIR}/API/" Flags="ck" Recurse="true"/>
    <Import File="${SRCDIR}/BFF/" Flags="ck" Recurse="true"/>
  </Namespace>

  <!-- need DP-421492 -->
  <Namespace Name="%SYS" Create="no">
    <Import File="${SRCDIR}/Patch/" Flags="ck" Recurse="true"/>
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
    If '$D(tVars("SRCDIR")) { Set tVars("SRCDIR")="/home/irisowner/src" } // csp app as a client
    Set tSC=..setupMethod(.tVars)
    $$$ThrowOnError(tSC)

    Set oldns=$NAMESPACE
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    Do ##class(Security.Users).UnExpireUserPasswords("*")

    #; Accept /irisclient/ as CSP path.
    Do ##class(%SYSTEM.CSP).SetConfig("CSPConfigName","irisclient")

    #; SSL/TLS Configuration
    Kill props
    Set props("CertificateFile")="/home/irisowner/ssl/client/server.crt"
    Set props("Description")="oAuth2 client application"
    Set props("PrivateKeyFile")="/home/irisowner/ssl/client/server.key"
    Set tSC = ##Class(Security.SSLConfigs).Create("client",.props)
    $$$ThrowOnError(tSC)

    #; App用に/csp/userを設定
    #; Accept no-password only on /csp/user webapp
		Set webapp="/csp/user"
    Kill props
		Set tSC = ##Class(Security.Applications).Get(webapp,.props)
		Set props("AutheEnabled")=$$$AutheUnauthenticated
    #; front channel logoutのためにSession Cookie Scopeをnoneに変更する
		Set props("SessionScope")=0
    #; 紛らわしいのでGroupByIdをクリア
    Set props("GroupById")=""
		Set tSC = ##Class(Security.Applications).Modify(webapp,.props)
		$$$ThrowOnError(tSC)

    #; App2用に/csp/userを/csp/user2にコピー
    Set tSC = ##Class(Security.Applications).Copy(webapp,webapp_"2")
    Set webapp="/csp/user2"
    Kill props
		Set tSC = ##Class(Security.Applications).Get(webapp,.props)
    Set props("CookiePath")="/csp/user2/"
    Set props("MatchRoles")=":%DB_USER2"
    Set props("Name")="/csp/user2"
    Set props("NameSpace")="USER2"
    Set props("Path")="/usr/irissys/csp/user2/"    
		Set tSC = ##Class(Security.Applications).Modify(webapp,.props)

    #; BFF用に/csp/bffapiを作成
    Set webapp="/csp/bffapi"
    Kill props
    Set props("AutheEnabled")=64  // No-auth only
    Set props("DispatchClass")="BFF.REST"
    Set props("Resource")=""
    Set props("MatchRoles")=":%DB_BFF"
    Set props("DeepSeeEnabled")=0
    Set props("NameSpace")="BFF"
    Kill props("Type")
    Set tSC = ##Class(Security.Applications).Create(webapp,.props)
    $$$ThrowOnError(tSC)

    #; BFF2用に/csp/bff2apiを作成
    Set webapp="/csp/bff2api"
    Kill props
    Set props("AutheEnabled")=64  // No-auth only
    Set props("DispatchClass")="BFF.REST"
    Set props("Resource")=""
    Set props("MatchRoles")=":%DB_BFF2"
    Set props("DeepSeeEnabled")=0
    Set props("NameSpace")="BFF2"
    Kill props("Type")
    Set tSC = ##Class(Security.Applications).Create(webapp,.props)
    $$$ThrowOnError(tSC)

		Set $NAMESPACE=oldns

  } Catch(e) {
	  Set tSC=e.AsStatus()
    Do ##class(%SYS.System).WriteToConsoleLog(e.DisplayString())
    zw tSC
  }
  Return tSC
}

}
