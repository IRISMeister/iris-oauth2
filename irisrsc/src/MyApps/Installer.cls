Class MyApps.Installer
{

XData setup [ XMLNamespace = INSTALLER ]
{
<Manifest>
  <Var Name="DATADB" Value="${Namespace}-DATA"/>
  <Var Name="CODEDB" Value="${Namespace}-CODE"/>

  <Log Text="Creating namespace ${Namespace}" Level="0"/>
  <Namespace Name="${Namespace}" Create="yes" Code="${CODEDB}" Ensemble="0" Data="${DATADB}">
    <Configuration>
      <Database Name="${CODEDB}" Dir="${DBDIR}${CODEDB}" Create="yes" Resource="%DB_${CODEDB}"/>
      <Database Name="${DATADB}" Dir="${DBDIR}${DATADB}" Create="yes" Resource="%DB_${DATADB}"/>
    </Configuration>

    <CSPApplication Url="/csp/${Namespace}" Directory="${CSPDIR}${Namespace}" Resource=""/>
    <Import File="${SRCDIR}" Flags="ck" Recurse="true"/>
  </Namespace>

  <Log Text="End Creating namespace ${Namespace}" Level="0"/>

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
    Set Namespace="myrsc"
    Set webapp="/csp/"_Namespace

    If '$D(tVars("Namespace")) { Set tVars("Namespace")=Namespace }
    If '$D(tVars("appuserpwd")) { Set tVars("appuserpwd")="sys" }
    If '$D(tVars("SRCDIR")) { Set tVars("SRCDIR")="/home/irisowner/src/API/" }

    #; specify database dir
    If '$D(tVars("DBDIR")) { Set tVars("DBDIR")="/home/irisowner/" }

    Set tSC=..setupMethod(.tVars)
    $$$ThrowOnError(tSC)

    Set oldns=$NAMESPACE
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    Do ##class(Security.Users).UnExpireUserPasswords("*")
    
    #; Accept /irisrsc/ as CSP path.
    Do ##class(%SYSTEM.CSP).SetConfig("CSPConfigName","irisrsc,irisrsc2")

    #; SSL/TLS Configuration
    Kill props
    Set props("CertificateFile")="/home/irisowner/ssl/resserver/server.crt"
    Set props("Description")="oAuth2 resource server"
    Set props("PrivateKeyFile")="/home/irisowner/ssl/resserver/server.key"
    Set tSC = ##Class(Security.SSLConfigs).Create("resserver",.props)
    $$$ThrowOnError(tSC)

    Set tSC = ##Class(Security.Applications).Get(webapp,.props)
    $$$ThrowOnError(tSC)
    Set props("AutheEnabled")=64  // No-auth only
    Set props("DispatchClass")="API.REST"
    Set props("Resource")=""
    Set props("DeepSeeEnabled")=1
    Set props("MatchRoles")=":%DB_MYRSC-CODE:%DB_MYRSC-DATA"
    Set props("NameSpace")=Namespace
    Kill props("Type")
    Set tSC = ##Class(Security.Applications).Modify(webapp,.props)
    $$$ThrowOnError(tSC)

    Set $NAMESPACE=oldns
  } Catch(e) {
	  Set tSC=e.AsStatus()
    Do ##class(%SYS.System).WriteToConsoleLog(e.DisplayString())
  }
  Return tSC
}

}
