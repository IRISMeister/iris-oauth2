Include MyApp.common

Class MyApp.AppMain Extends %CSP.Page
{

Parameter RSCURL1 = "https://webgw.localdomain/irisrsc/csp/myrsc";

Parameter RSCURL2 = "https://webgw.localdomain/irisrsc2/csp/myrsc";

Parameter SSLCONFIG = "client";

Parameter SCOPES = "openid profile scope1";

ClassMethod OnPage() As %Status
{

    &html<<html>
<head>
</head>

<style>
body { font-family: verdana; }

h4 { color:#2080E0 ;}
</style>

<body>>

    #; test to see if session data had initialized.
    Set tmp=$INCREMENT(%session.Data("COUNTER")) 
    
    // Check if we have an access token from oauth2 server
    set isAuthorized=##class(%SYS.OAuth2.AccessToken).IsAuthorized($$$APP,,..#SCOPES,.accessToken,.idtoken,.responseProperties,.error)
    
    if isAuthorized {
        #;
        #; lougout
        #;
        Set ns=$ZCVT($NAMESPACE,"L") Set fclouri="https://webgw.localdomain/"_$$$HOSTNAME_"/csp/"_ns_"/MyApp.AppMain.cls"
        Set url=##class(%SYS.OAuth2.Authorization).GetLogoutEndpoint($$$APP,fclouri)
        #; このURLは、WebGWのpathを考慮していない。本例では/irisclient（もしくは/irisclient2）が必要なので追加する。
        Set url=$REPLACE(url,"/csp/sys/","/"_$$$HOSTNAME_"/csp/sys/")

        Write "<a href="_url_">ログアウト</a>",!

        #;
        #; Refresh
        #;
        Write "<a href=MyApp.AppMain.cls?refresh=1>トークン更新</a>",!
        Write "</br>",!

        &html<
        <table border="1">
        <tr>
            <th>Item</th>
            <th>Value</th>
        </tr>
        <tr>
            <td>AT</td><td>#(accessToken)#</td>
        </tr>
        <tr>
            <td>IDT</td><td>#(idtoken)#</td>
        </tr>
        <tr>
            <td>RefreshToken</td><td>#(responseProperties("refresh_token"))#</td>
        </tr>
        <tr>
            <td>SessionId</td><td>#(%session.SessionId)#</td>
        </tr>
        <tr>
            <td>%session.Data("COUNTER")</td><td>#(tmp)#</td>
        </tr>
        <tr>
            <td>$NAMESPACE</td><td>#($NAMESPACE)#</td>
        </tr>
        <tr>
            <td>$USERNAME</td><td>#($USERNAME)#</td>
        </tr>
        <tr>
            <td>$ROLES</td><td>#($ROLES)#</td>
        </tr>
        </table>
        >

        set formatter = ##class(%JSON.Formatter).%New()
        if idtoken'="" {
            // Validate and display the IDToken -- see OpenID Connect Core specification.
            set valid=##class(%SYS.OAuth2.Validation).ValidateIDToken(
                $$$APP,
                idtoken,
                accessToken,
                ..#SCOPES,
                ..#RSCURL1,  // RSCURL2の存在チェックはしていないので注意
                .jsonObject,
                .securityParameters,
                .sc)
            if $$$ISOK(sc) {
                write "IDToken="
                w "<pre>" Do formatter.Format(jsonObject) w "</pre>",!
                write "<br>",!
            } else {
                write "IDToken Error="_..EscapeHTML($system.Status.GetErrorText(sc))_"<br>",!    
            }
        } else {
            write "No IDToken returned"_"<br>",!
        }
        write "<br>",!
    
        // 署名の有無の確認
        Set isSigned=$Data(securityParameters("sigalg"))#2
        if 'isSigned="" { 
            write "署名されていません !<br>",!
        }
        // ToDo:
        // 署名の種類の確認

        // Optionally, Call the introspection endpoint and display result -- see RFC 7662.
        set sc=##class(%SYS.OAuth2.AccessToken).GetIntrospection($$$APP,accessToken,.jsonObject)
        if $$$ISOK(sc) {
            write "Introspection="
            w "<pre>" Do formatter.Format(jsonObject) w "</pre>",!
            write "<br>",!
        } else {
            write "Introspection Error="_..EscapeHTML($system.Status.GetErrorText(sc))_"<br>",!    
        }
        write "<br>",!
        
        // Call the userinfo endpoint and display the result -- see OpenID Connect Core specification.
        set sc=##class(%SYS.OAuth2.AccessToken).GetUserinfo(
            $$$APP,
            accessToken,,
            .jsonObject)
        if $$$ISOK(sc) {
            write "Userinfo="
            w "<pre>" Do formatter.Format(jsonObject) w "</pre>",!
            write "<br>",!
        } else {
            write "Userinfo Error="_..EscapeHTML($system.Status.GetErrorText(sc))_"<br>",!    
        }
        write "<p>",!

        /***************************************************
        *                                                  *
        *   Call the resource server and display result.   *
        *                                                  *
        ***************************************************/
        write "<h4>Call resource server #1","</h4>",!
        set httpRequest=##class(%Net.HttpRequest).%New()
        // AddAccessToken adds the current access token to the request.
        set sc=##class(%SYS.OAuth2.AccessToken).AddAccessToken(
            httpRequest,,
            ..#SSLCONFIG,
            $$$APP)
        if $$$ISOK(sc) {
            Set url=..#RSCURL1_"/private" w "URL:"_url_"</BR>",!
            set sc=httpRequest.Get(url)
        }
        if $$$ISOK(sc) {
            set body=httpRequest.HttpResponse.Data
            if $isobject(body) {
                do body.Rewind()
                set body=body.Read()
            }
            w "<pre>" Do formatter.Format({}.%FromJSON(body)) w "</pre>",!
        }
        if $$$ISERR(sc) {
            write "Resource Server Error="_..EscapeHTML($system.Status.GetErrorText(sc))_"<br>",!    
        }
        write "<br>",!

        // IDフェデレーション。
        // 本来、IDフェデレーション時に異なるリソースサーバに同一のSCOPEを持つアクセストークンを使用するのは不自然。
        write "<h4>Call resource server #2","</h4>",!
        set httpRequest=##class(%Net.HttpRequest).%New()
        // AddAccessToken adds the current access token to the request.
        set sc=##class(%SYS.OAuth2.AccessToken).AddAccessToken(
            httpRequest,,
            ..#SSLCONFIG,
            $$$APP)
        if $$$ISOK(sc) {
            Set url=..#RSCURL2_"/private" w "URL:"_url_"</BR>",!
            set sc=httpRequest.Get(url)
        }
        if $$$ISOK(sc) {
            set body=httpRequest.HttpResponse.Data
            if $isobject(body) {
                do body.Rewind()
                set body=body.Read()
            }
            w "<pre>" Do formatter.Format({}.%FromJSON(body)) w "</pre>",!
        }
        if $$$ISERR(sc) {
            write "Resource Server Error="_..EscapeHTML($system.Status.GetErrorText(sc))_"<br>",!    
        }
        write "<br>",!

    } else {
        write "認証されていません!<p>",!
        write "<a href='MyApp.AppMain.cls'>認証を行う</a>"
    }    
    &html<</body></html>>
    Return $$$OK
}

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
    if $get(%request.Data("refresh",1))=1 {
        Set tSC=##class(%ZSYS.OAuth2.Authorization).GetAccessTokenRefreshById($$$APP,, .refreshed, .error) 
        $$$ThrowOnError(tSC)
        Set %response.Redirect="MyApp.AppMain.cls"
    }
    Return $$$OK
}

}
