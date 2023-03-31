Class MyApp.Logout Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
  W "<html><body>Logout</body</html>"
  Quit $$$OK
}

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
  #;IRISLogout=end付きの場合、下記が実行されることはない(ログイン画面でブロックされる)模様。
  #dim %response as %CSP.Response
  Set ^logout($INCREMENT(^logout))=$ZDATETIME($NOW())
  Quit $$$OK
}

}
