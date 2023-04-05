# IRISだけでoAuth2/OpenID ConnectのSSO/SLO環境を実現する

本記事は、あくまで執筆者の見解であり、インターシステムズの公式なドキュメントではありません。

IRISのoAuth2機能関連の情報発信は既に多数ありますが、本稿では
- 手順(ほぼ)ゼロでひとまず動作させてみる
- 設定の見通しを良くするために、役割ごとにサーバを分ける
- 目に見えない動作を確認する
- クライアント実装(PythonやAngular,CSPアプリケーション等)と合わせて理解する
- シングルサインオン/シングルログアウトを実現する

ということを主眼においています。

コミュニティ版で動作しますので、「とりあえず動かす」の手順に従って、どなたでもお試しいただけます。
> 現状、使用IRISバージョンはIRIS 2023.1のプレビュー版になっていますが、[ソースコード](https://github.com/IRISMeister/iris-oauth2)は適宜変更します。

手順に沿ってコンテナを起動すると下記の環境が用意されます。この環境を使用して動作を確認します。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/oauth-demo-env.png)

ユーザエージェント(ブラウザ)やPython/curlからのアクセスは、全てApache (https://webgw.localdomain/) 経由になります。青枠の中のirisclient等の文字はコンテナ名(ホスト名)です。

例えば、irisclientホストの/csp/user/MyApp.Login.clsにアクセスする場合、URLとして
```
 https://webgw.localdomain/irisclient/csp/user/MyApp.Login.cls
```
と指定します。

> つまり、各エンドポイントは同一のorigin (https://webgw.localdomain) を持ちます。そのため、クロスサイト固有の課題は存在しません(カバーされません)が、仮に各サーバが別のドメインに存在しても基本的には動作するはずです。

oAuth2/OIDC(OpenID Connect)の利用シーンは多種多様です。

本例は、認証・認可サーバ,クライアントアプリケーション,リソースサーバの全てがIRISで実行されるクローズドな環境(社内や組織内での使用)を想定して、認可コードフロー(Authorization Code Flow)を実現します。分かりやすい解説が、ネットにたくさんありますので、コードフロー自身の説明は本稿では行いません。

>認証・認可サーバの候補はIRIS, WindowsAD, Azure AD, AWS Cognito, Google Workspace, keycloak, OpenAMなどがあり得ます。個別に動作検証が必要です。

クライアントアプリケーション(RP)は、昨今はSPAが第一候補となると思いますが、利用環境によっては、SPA固有のセキュリティ課題に直面します。

IRISには、Confidential Clientである、従来型のWebアプリケーション(フォームをSubmitして、画面を都度再描画するタイプのWebアプリケーション)用のoAuth2関連のAPI群が用意されています。

そこで、Webアプリケーション(CSP)を選択することも考えられますが、クライアント編では、よりセキュアとされるSPA+BFF(Backend For Frontend)の構成を実現するにあたり、Wepアプリケーション用APIをそのまま活用する方法をご紹介する予定です。

> 以下、サーバ編の動作確認には、CSPアプリケーションを使用しています。これは、新規開発にCSP(サーバページ)を使用しましょう、という事ではなく、BFF実現のために必要となる機能を理解するためです。BFFについては、クライアント編で触れます。BFFについては、[こちら](https://dev.to/damikun/web-app-security-understanding-the-meaning-of-the-bff-pattern-i85)の説明がわかりやすかったです。

リソースサーバの役割はデータプラットフォームであるIRISは最適な選択肢です。医療系用のサーバ機能ですがFHIRリポジトリはその良い例です。本例では、至極簡単な情報を返すAPIを使用しています。

> 少しの努力でFHIRリポジトリを組み込むことも可能です。

サーバ編とクライアント編に分けて記載します。今回はサーバ編です。

> とはいえ、クライアントとサーバが協調動作する仕組みですので、境界は少しあいまいです

<!--break-->
---------

# 使用環境
- Windows10  
ブラウザ(Chrome使用)、curl及びpythonサンプルコードを実行する環境です。

- Liunx (Ubuntu)  
IRIS, WebGateway(Apache)を実行する環境です。Windows10上のwsl2、仮想マシンあるいはクラウドで動作させる事を想定しています。

参考までに私の環境は以下の通りです。

---------

|用途|O/S|ホストタイプ|
|:--|:--|:--|
|クライアントPC|Windows10 Pro|物理ホスト|
|Linux環境|ubuntu 22.04.1 LTS|上記Windows10上のwsl2|

---------
Linux環境はVMでも動作します。VMのubuntuは、[ubuntu-22.04-live-server-amd64.iso](https://releases.ubuntu.com/22.04/ubuntu-22.04.1-live-server-amd64.iso
)等を使用して、最低限のサーバ機能のみをインストールしてあれば十分です。

# Linux上に必要なソフトウェア
実行にはjq,openssl,dockerが必要です。
私の環境は以下の通りです。
```
$ jq --version
jq-1.6
$ openssl version
OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)
$ docker version
Client: Docker Engine - Community
 Version:           23.0.1
```
# とりあえず動かす
下記手順でとりあえず動かしてみることが出来ます。

- 以下は、Linuxで実行します。
  ```bash
  git clone https://github.com/IRISMeister/iris-oauth2.git --recursive
  cd iris-oauth2
  ./first-run.sh
  ```

  この時点で下記をLinuxで実行し、OpenIDプロバイダーのメタデータを取得できる事を確認してください。[こちら](https://github.com/IRISMeister/iris-oauth2/blob/main/docs/openid-configuration.json)のような出力が得られるはずです。
  ```bash
  curl http://localhost/irisauth/authserver/oauth2/.well-known/openid-configuration
  ```

- 以下はWindowsで実行します。

  クライアントPC(Windows)にホスト名(webgw.localdomain)を認識させるために、%SystemRoot%\system32\drivers\etc\hostsに下記を追加します。

  wsl2使用でかつlocalhostForwarding=Trueに設定してある場合は下記のように設定します。
  ```
  127.0.0.1 webgw.localdomain 
  ```
  VM使用時は、LinuxのIPを指定します。
  ```
  192.168.11.48 webgw.localdomain 
  ```

  次に、httpsの設定が正しく機能しているか確認します。作成された証明書チェーンをWindows側のc:\tempにコピーします。 
  
  ```
  cp ssl/web/all.crt /mnt/c/temp
  ```

  >  VMの場合は、scp等を使用してssl/web/all.crtを c:\temp\all.crtにコピーしてください。以後、WSL2のコマンドのみを例示します。

  PCからcurlでリソースサーバの認証なしのRESTエンドポイントにアクセスします。ユーザ指定(-u指定)していないことに注目してください。   
  ```DOS
  curl --cacert c:\temp\all.crt --ssl-no-revoke -X POST https://webgw.localdomain/irisrsc/csp/myrsc/public
  {"HostName":"irisrsc","UserName":"UnknownUser","sub":"","aud":"","Status":"OK","TimeStamp":"03/28/2023 17:39:17","exp":"(1970-01-01 09:00:00)","debug":{}}
  ```

  認証なしのRESTサービスですので成功するはずです。次にアクセストークン/IDトークンによる認証・認可チェック処理を施したエンドポイントにアクセスします。
  
  ```DOS
  curl --cacert c:\temp\all.crt --ssl-no-revoke -X POST https://webgw.localdomain/irisrsc/csp/myrsc/private
  {
    "errors":[ {
              "code":5035,
              "domain":"%ObjectErrors",
              "error":"エラー #5035: 一般例外 名前 'NoAccessToken' コード '5001' データ ''",
              "id":"GeneralException",
              "params":["NoAccessToken",5001,""
              ]
            }
    ],
    "summary":"エラー #5035: 一般例外 名前 'NoAccessToken' コード '5001' データ ''"
  }
  ```
  こちらは、期待通りエラーで終了します。  

  次に、ブラウザで[CSPベースのWEBクライアントアプリケーション](https://webgw.localdomain/irisclient/csp/user/MyApp.Login.cls)を開きます。
  > プライベート認証局発行のサーバ証明書を使用しているため、初回はブラウザで「この接続ではプライバシーが保護されません」といったセキュリティ警告が出ます。アクセスを許可してください。

  ![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/login.png)

  「oAuth2認証を行う」ボタンを押した際に、ユーザ名、パスワードを求められますので、ここではtest/testを使用してください。
  
  ![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/user-pass.png)

  権限の要求画面で「許可」を押すと各種情報が表示されます。

  ![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/authorize.png)

  ページ先頭に「ログアウト(SSO)」というリンクがありますので、クリックしてください。最初のページに戻ります。

  IRISコミュニティエディションで、接続数上限に達してしまうと、それ以後は[Service Unavailable]になったり、認証後のページ遷移が失敗したりしますので、ご注意ください。その場合、下記のような警告メッセージがログされます。

  ```
  docker compose logs irisclient

  iris-oauth2-irisclient-1  | 03/24/23-17:14:34:429 (1201) 2 [Generic.Event] License limit exceeded 1 times since instance start.
  ```
  しばらく(10分ほど)待つか、終了・起動をしてください。

- 以下は、Linuxで実行します。

  終了させるには下記を実行します。
  ```bash
  ./down.sh
  ```

# 主要エンドポイント一覧
下図は、コード認可フローを例にした、各要素の役割になります。用語としてはoAuth2を採用しています。
 ![](https://community.intersystems.com/sites/default/files/inline/images/images/image-20200703154452-1.png)

OIDCはoAuth2の仕組みに認証機能を載せたものなので、各要素は重複しますが異なる名称(Authorization serverはOIDC用語ではOP)で呼ばれています。

> CLIENT SERVERという表現は「何どっち？」と思われる方もおられると思いますが、Client's backend serverの事で、サーバサイドに配置されるロジック処理機能を備えたWebサーバの事です。描画を担うJavaScriptなどで記述されたClient's frontendと合わせて単にClientと呼ぶこともあります。

-----
|要素|サービス名|OIDC用語|oAuth2用語|エンドポイント|
|:--|:--|:--|:--|:--|
|ユーザエージェント|N/A|User Agent|User Agent|N/A|
|Web Gateway|webgw|N/A|N/A|[/csp/bin/Systems/Module.cxw](http://webgw.localdomain/csp/bin/Systems/Module.cxw)|
|認可サーバの管理|irisauth|N/A|N/A|[/irisauth/csp/sys/%25CSP.Portal.Home.zen](http://webgw.localdomain/irisauth/csp/sys/%25CSP.Portal.Home.zen)|
|リソースサーバ#1の管理|irisrsc|N/A|N/A|[irisrsc/csp/sys/%25CSP.Portal.Home.zen](https://webgw.localdomain/irisrsc/csp/sys/%25CSP.Portal.Home.zen)|
|リソースサーバ#1|irisrsc|N/A|Resource server|[/irisrsc/csp/myrsc/private](https://webgw.localdomain/irisrsc/csp/myrsc/private)|
|リソースサーバ#2の管理|irisrsc2|N/A|N/A|[/irisrsc2/csp/sys/%25CSP.Portal.Home.zen](https://webgw.localdomain/irisrsc2/csp/sys/%25CSP.Portal.Home.zen)|
|リソースサーバ#2|irisrsc2|N/A|Resource server|[/irisrsc2/csp/myrsc/private](https://webgw.localdomain/irisrsc2/csp/myrsc/private)|
|WebApp 1a,1bの管理|irisclient|N/A|N/A|[/irisclient/csp/sys/%25CSP.Portal.Home.zen](http://webgw.localdomain/irisclient/csp/sys/%25CSP.Portal.Home.zen)|
|WebApp 1a|irisclient|RP|Client server|[/irisclient/csp/user/MyApp.Login.cls](https://webgw.localdomain/irisclient/csp/user/MyApp.Login.cls)|
|WebApp 1b|irisclient|RP|Client server|[/irisclient2/csp/user/MyApp.AppMain.cls](https://webgw.localdomain/irisclient/csp/user2/MyApp.Login.cls)|
|WebApp 2の管理|irisclient2|N/A|N/A|[/irisclient2/csp/sys/%25CSP.Portal.Home.zen](http://webgw.localdomain/irisclient2/csp/sys/%25CSP.Portal.Home.zen)|
|WebApp 2|irisclient2|RP|Client server|[/irisclient2/csp/user/MyApp.AppMain.cls](https://webgw.localdomain/irisclient2/csp/user/MyApp.AppMain.cls)|

> エンドポイントのオリジン(https://webgw.localdomain)は省略しています

-----

組み込みのIRISユーザ(SuperUser,_SYSTEM等)のパスワードは、[merge1.cpf](https://github.com/IRISMeister/iris-oauth2/blob/master/cpf/merge1.cpf)のPasswordHashで一括で"SYS"に設定しています。管理ポータルへのログイン時に使用します。

# 導入手順の解説

first-run.shは、2～5を行っています。

1. ソースコード入手
    ```bash
    git clone https://github.com/IRISMeister/iris-oauth2.git --recursive
    ```
2. SSL証明書を作成
    ```
    ./create_cert_keys.sh
    ```
    [apache-ssl](https://github.com/IRISMeister/apache-ssl.git)に同梱のsetup.shを使って、鍵ペアを作成し、出来たsslフォルダの中身を丸ごと、ssl/web下等にコピーしています。コピー先と用途は以下の通りです。

    |コピー先|使用場所|用途|
    |:--|:--|:--|
    |ssl/web/| ApacheのSSL設定およびクライアントアプリ(python)| Apacheとのhttps通信用|
    |irisauth/ssl/auth/|認可サーバ| 認可サーバのクライアント証明書|
    |irisclient/ssl/client/|CSPアプリケーション#1a,1b| IRIS(CSP)がクライアントアプリになる際のクライアント証明書|
    |irisclient2/ssl/client/|CSPアプリケーション#2| IRIS(CSP)がクライアントアプリになる際のクライアント証明書|
    |irisrsc/ssl/resserver/|リソースサーバ| リソースサーバのクライアント証明書|
    |irisrsc2/ssl/resserver/|リソースサーバ#2| リソースサーバのクライアント証明書|

3. PCにクライアント用の証明書チェーンをコピー  

    all.crtには、サーバ証明書、中間認証局、ルート認証局の情報が含まれています。curlやpythonなどを使用する場合、これらを指定しないとSSL/TLSサーバ証明書の検証に失敗します。

    ```bash
    cp ssl/web/all.crt /mnt/c/temp
    ```

    >備忘録  

    >下記のコマンドで内容を確認できます。
    >```bash
    >openssl crl2pkcs7 -nocrl -certfile ssl/web/all.crt | openssl pkcs7 -print_certs -text -noout
    >```

4. Web Gatewayの構成ファイルを上書きコピー

    ```bash
    cp webgateway* iris-webgateway-example/
    ```

5. コンテナイメージをビルドする  

    ```bash
    ./build.sh
    ```

  >各種セットアップは、各サービス用のDockerfile以下に全てスクリプト化されています。iris関連のサービスは、原則、##class(MyApps.Installer).setup()で設定を行い、必要に応じてアプリケーションコードをインポートするという動作を踏襲しています。例えば、認可サーバの設定はこちらの[Dockefile](https://github.com/IRISMeister/iris-oauth2/blob/master/irisauth/Dockerfile)と、インストーラ用のクラスである[MyApps.Installer](https://github.com/IRISMeister/iris-oauth2/blob/master/irisauth/src/MyApps/Installer.cls)(内容は後述します)を使用しています。

6. ブラウザ、つまりクライアントPC(Windows)にホスト名webgw.localdomainを認識させる

    上述の通りです。

# 起動方法

```
./up.sh
```

up時に表示される下記のようなjsonは、後々、pythonなどの非IRISベースのクライアントからのアクセス時に使用する事を想定しています。各々client/下に保存されます。
```json
{
  "client_id": "trwAtbo5DKYBqpjwaBu9NnkQeP4PiNUgnbWU4YUVg_c",
  "client_secret": "PeDUMmFKq3WoCfNfi50J6DnKH9KlTM6kHizLj1uAPqDzh5iPItU342wPvUbXp2tOwhrTCKolpg2u1IarEVFImw",
  "issuer_uri": "https://webgw.localdomain/irisauth/authserver/oauth2"
}
```

コンテナ起動後、ブラウザで下記(CSPアプリケーション)を開く。  
https://webgw.localdomain/irisclient/csp/user/MyApp.Login.cls  


# 停止方法
```bash
./down.sh  
```

# 認可サーバの設定について

## カスタマイズ内容

多様なユースケースに対応するために、[認可サーバの動作をカスタマイズする機能](https://docs.intersystems.com/irislatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GOAUTH_authz#GOAUTH_authz_code)を提供しています。

特に、%OAuth2.Server.Authenticateはプロダクションには適さない可能性が高いのでなんらかのカスタマイズを行うように[注記](https://docs.intersystems.com/irislatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GOAUTH_authz#GOAUTH_authz_oauth2serverauthenticate)されていますのでご注意ください。

本例では、認証関連で下記の独自クラスを採用しています。

- 認証クラス

  [%ZOAuth2.Server.MyAuthenticate.cls](https://github.com/IRISMeister/iris-oauth2/blob/master/irisauth/src/%25ZOAuth2/Server/MyAuthenticate.cls)

  下記を実装しています。  
  BeforeAuthenticate() — 必要に応じてこのメソッドを実装し、認証の前にカスタム処理を実行します。

  ドキュメントに下記の記載があります。本例ではscope2が要求された場合には、応答に必ずscope99も含める処理を行っています。

  >通常、このメソッドを実装する必要はありません。ただし、このメソッドの使用事例の1つとして、FHIR® で使用される launch と launch/patient のスコープを実装するのに利用するというようなものがあります。この事例では、特定の患者を含めるようにスコープを調整する必要があります。

  AfterAuthenticate() — 必要に応じてこのメソッドを実装し、認証の後にカスタム処理を実行します。

  ドキュメントに下記の記載があります。本例ではトークンエンドポイントからの応答にaccountno=12345というプロパティを付与する処理を行っています。

  >通常、このメソッドを実装する必要はありません。ただし、このメソッドの使用事例の1つとして、FHIR® で使用される launch と launch/patient のスコープを実装するのに利用するというようなものがあります。この事例では、特定の患者を含めるようにスコープを調整する必要があります。

  トークンエンドポイントからの応答はリダイレクトの関係でブラウザのDevToolでは確認できません。[pythonクライアント](https://github.com/IRISMeister/python-oauth2-client)で表示出来ます。
  ```
  {   'access_token': '...........',
      'accountno': '12345',
      'expires_at': 1680157346.845698,
      'expires_in': 3600,
      'id_token': '...........',
      'refresh_token': '..........',
      'scope': ['openid', 'profile', 'scope1', 'scope2', 'scope99'],
      'token_type': 'bearer'
  }
  ```

- ユーザクラスを検証(ユーザの検証を行うクラス)

  [%ZOAuth2.Server.MyValidate.cls](https://github.com/IRISMeister/iris-oauth2/blob/master/irisauth/src/%25ZOAuth2/Server/MyValidate.cls)

  下記を実装しています。  
  ValidateUser() — (クライアント資格情報を除くすべての付与タイプで使用)

  ここでは、トークンに含まれる"aud"クレームのデフォルト値を変更したり、カスタムクレーム(customer_id)を含める処理を行っています。

  ```
  {
    "jti":"https://webgw.localdomain/irisauth/authserver/oauth2.UQK89uY7wBdysNvG-fFh44AxFu8",
    "iss":"https://webgw.localdomain/irisauth/authserver/oauth2",
    "sub":"test",
    "exp":1680156948,
    "aud":[
      "https://webgw.localdomain/irisrsc/csp/myrsc",
      "https://webgw.localdomain/irisrsc2/csp/myrsc",
      "pZXxYLRaP8vAOjmMetLe1jBIKl0wu4ehCIA8sN7Wr-Q"
    ],
    "scope":"openid profile scope1",
    "iat":1680153348,
    "customer_id":"RSC-00001",
    "email":"test@examples.com",
    "phone_number":"01234567"
  }
  ```

これらの独自クラスは、下記で設定しています。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/oauth-server-customize.png)

## リフレッシュトークン

「パブリッククライアント更新を許可」をオンにしています。

この設定をオンにすると、client_secretを含まない(つまりpublic clientの要件を満たすクライアント)からのリフレッシュトークンフローを受け付けます。そもそもPublic Clientにはリフレッシュトークンを発行しない、という選択もありますが、ここでは許可しています。

また、「リフレッシュ・トークンを返す」項目で「常にリフレッシュトークンを返す」を設定しています。
> 「scopeに"offline_access"が含まれている場合のみ」のように、より強めの制約を課すことも可能ですが、今回は無条件に返しています

## ユーザセッションをサポート
認可サーバの"ユーザセッションをサポート"を有効に設定しています。この機能により、シングルサインオン(SSO)、シングルログアウト(SLO)が実現します。

> ユーザセッションをユーザエージェントとRP間のセッション維持に使用する"セッション"と混同しないよう

この設定を有効にすると、認可時に使用したユーザエージェントは、以後、ユーザ名・パスワードの再入力を求めることなくユーザを認証します。以下のように動作を確認できます。

1. [CSPベースのアプリケーション#1a](https://webgw.localdomain/irisclient/csp/user/MyApp.Login.cls)をブラウザで開きます。ユーザ名・パスワードを入力し、認証を行います。

2. 同じブラウザの別タブで、異なるclient_idを持つ[CSPベースのアプリケーション#1b](https://webgw.localdomain/irisclient/csp/user2/MyApp.Login.cls)を開きます。本来であれば、ユーザ名・パスワード入力を求められますが、今回はその工程はスキップされます。

3. 上記はほぼ同じ表示内容ですが$NAMESPACE(つまり実行されているアプリケーション)が異なります。

> アプリケーションが最初に認可されたスコープと異なるスコープを要求した場合、以下のようなスコープ確認画面だけが表示されます。  

> ![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/authorize-scope.png)

この時点で認可サーバで下記を実行すると、現在1個のセッションに属する(同じGroupIdを持つ)トークンが2個存在することが確認できます。

```bash
$ docker compose exec irisauth iris session iris -U%SYS "##class(%SYSTEM.SQL).Shell()"
[SQL]%SYS>>SELECT * FROM OAuth2_Server.Session

ID                                              AuthTime        Cookie                                          Expires         Scope                   Username
6Xks9UD1fm8HU6u6FYf5eRtlyv8IU44LM4vGEkqbI60     1679909215      6Xks9UD1fm8HU6u6FYf5eRtlyv8IU44LM4vGEkqbI60     1679995615      openid profile scope1   test

[SQL]%SYS>>SELECT ClientId, GroupId,  Scope, Username FROM OAuth2_Server.AccessToken

ClientId                                        GroupId                                         Scope                   Username
qCIoFRl1jtO0KpLlCrfYb8TelYcy_G1sXW_vav_osYU     6Xks9UD1fm8HU6u6FYf5eRtlyv8IU44LM4vGEkqbI60     openid profile scope1   test
vBv3V0_tS3XEO5O15BLGOgORwk-xYlEGQA-48Do9JB8     6Xks9UD1fm8HU6u6FYf5eRtlyv8IU44LM4vGEkqbI60     openid profile scope1   test
```

4. 両方のタブでF5を何度か押して、%session.Data("COUNTER")の値が増えて行くことを確認します。
> セッションを持つアプリケーションの動作という見立てです。

5. 1個目のタブ(CSPベースのアプリケーション#1a)でログアウト(SSO)をクリックします。ログアウトが実行され、最初のページに戻ります。

6. 2個目のタブ(CSPベースのアプリケーション#1b)でF5を押します。「認証されていません! 認証を行う」と表示されます。

これで、1度のログアウト操作で、全てのアプリケーションからログアウトするSLOが動作したことがが確認できました。

同様に、[サンプルのpythonコード](https://github.com/IRISMeister/python-oauth2-client)も、一度認証を行うと、それ以降、何度実行してもユーザ名・パスワード入力を求めることはありません。これはpythonが利用するブラウザに"ユーザセッション"が記録されるためです。

```
          redirect
  <-----------------------------------
                                     |
python +--> ブラウザ           --> 認可サーバ
       |    (ユーザセッション)  
       +--> リソースサーバ
```


この設定が有効の場合、認可サーバはユーザエージェントに対してCSPOAuth2Sessionという名称のクッキーをhttpOnly, Secure設定で送信します。以後、同ユーザエージェントが認可リクエストを行う際には、このクッキーが使用され、(認可サーバでのチェックを経て)ユーザを認証済みとします。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/CSPOAuth2Session.png)

CSPOAuth2Sessionの値は、発行されるIDトークンの"sid"クレームに含まれます。
```
{
  "iss":"https://webgw.localdomain/irisauth/authserver/oauth2",
  "sub":"test",
  "exp":1679629322,
  "auth_time":1679625721,
  "iat":1679625722,
  "nonce":"M79MJF6HqHHDKFpK4ZZJkaD3moE",
  "at_hash":"AFeWfbXALP78Y9KEhlKnp_5LJmEjthJQlJDGXh_eLPc",
  "aud":[
    "https://webgw.localdomain/irisrsc/csp/myrsc",
    "https://webgw.localdomain/irisrsc2/csp/myrsc",
    "SrGSiVPB8qWvQng-N7HV9lYUi5WWW_iscvCvGwXWGJM"
  ],
  "azp":"SrGSiVPB8qWvQng-N7HV9lYUi5WWW_iscvCvGwXWGJM",
  "sid":"yxGBivVOuMZGr2m3Z5AkScNueppl8Js_5cz2KvVt6dU"
}
```


詳細は[こちら](https://docs.intersystems.com/irislatest/csp/docbookj/DocBook.UI.Page.cls?KEY=GOAUTH_authz#GOAUTH_authz_config_ui_server)
の「ユーザ・セッションのサポート」の項目を参照ください。

## PKCE

認可コード横取り攻撃への対策である、[PKCE](https://www.rfc-editor.org/rfc/rfc7636)(ピクシーと発音するそうです)関連の設定を行っています。そのため、PublicクライアントはPKCEを実装する必要があります。

- 公開クライアントにコード交換用 Proof Key (PKCE) を適用する: 有効	
- 機密クライアントにコード交換用 Proof Key (PKCE) を適用する: 無効

## ログアウト機能

OpenID Connectのログアウト機能について再確認しておきます。

実に、様々なログアウト方法が提案されています。メカニズムとして、postMessage-Based Logout,HTTP-Based Logoutがあり、ログアウト実行の起点によりRP-Initiated, OP-Initiatedがあり、さらにHTTP-Based LogoutはFront-Channel, Back-Channelがありと、利用環境に応じて様々な方法が存在します。

> postMessageとはクロスドメインのiframe間でデータ交換する仕組みです

目的は同じでシングルログアウト(SLO)、つまり、シングルサインオンの逆で、OP,RP双方からログアウトする機能を実現することです。

### 本例での設定

HTTP-Basedを使用したほうがクライアント実装が簡単になる事、バックチャネルログアウトは現在IRISでは未対応であることから、本例では、フロントチャネルログアウトをRP-Initiatedで実行しています。

ユーザセッションが有効なクライアント(irisclient)のログアウト用のリンクをクリックすると下記のようなJavaScriptを含むページが描画されます。

```
<body onload="check(0)">
<iframe id=frame0 src=RP1のfrontchannel_logout_uri hidden></iframe>
<iframe id=frame1 src=RP2のfrontchannel_logout_uri hidden></iframe>
  ・
  ・
<scr1pt language=javascript type="text/javascript">
    function check(start) {
      個々のiframeの実行完了待ち
      if (完了) doRedirect()
    }
    function doRedirect() {
            post_logout_redirect_uriへのリダイレクト処理
    }
</scr1pt>
```

> 表示がおかしくなってしまうので、scriptをscr1ptに変更しています。インジェクション攻撃扱いされています...？

JavaScriptが行っていることは、iframe hiddenで指定された各RPログアウト用のエンドポイント(複数のRPにログインしている場合、iframeも複数出来ます)を全て呼び出して、成功したら、doRedirect()で、post_logout_redirect_urisで指定されたURLにリダイレクトする、という処理です。これにより、一度の操作で全RPからのログアウトとOPからのログアウト、ログアウト後の指定したページ(本例では最初のページ)への遷移が実現します。

> 内容を確認したい場合、ログアウトする前に、ログアウト用のリンクのURLをcurlで実行してみてください。
>
>```
>curl -L --insecure "https://webgw.localdomain/irisclient/csp/sys/oauth2/OAuth2.PostLogoutRedirect.cls?register=R3_wD-F5..."
>``` 

一方、ユーザセッションが無効の場合は、ログアウトを実行したクライアントのみがfrontchannel_logout対象となります。

> つまり、ユーザセッションを使用して、2回目以降にユーザ名・パスワードの入力なしで、認証されたアプリケーション群が、SLOでログアウトされる対象となります。

フロントチャネルログアウト実現のために、認可サーバの設定で、下記のログアウト関連の設定を行っています。

- HTTPベースのフロントチャネルログアウトをサポート:有効	
- フロントチャネルログアウトURLとともに sid (セッションID) クレームの送信をサポート:有効

また、認可サーバ(irisauth)に以下のcookie関連の設定を行っています。

[ドキュメント](https://docs.intersystems.com/iris20223/csp/docbook/Doc.View.cls?KEY=GOAUTH_authz)に従って、irisauthの/oauth2のUser Cookie Scopeをlaxとしています。

>Note:
For an InterSystems IRIS authorization server to support front channel logout, the User Cookie Scope for the /oauth2 web application must be set to Lax. For details on configuring application settings, see Create and Edit Applications.

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/cookie-user-session.png)

> 本例は同じオリジンで完結している(Chromeであれば、ログアウト実行時に関わるhttpアクセスのRequest Headersに含まれるsec-fetch-site値がsame-originになっていることで確認できます)ので、この設定は不要ですが、備忘目的で設定しています。

また、クライアント(irisclient)に以下の設定を行っています。

1. Session Cookie Scopeの設定

[ドキュメント](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GOAUTH_client)に従って、irisclientの/csp/userのSession Cookie Scopeをnoneとしています。

>Note:
For an InterSystems IRIS client to support front channel logout, the Session Cookie Scope of the client application to None. For details on configuring application settings, see Create and Edit Applications.

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/cookie-session.png)

> 本例は同じオリジンで完結している(Chromeであれば、ログアウト実行時に関わるhttpアクセスのRequest Headersに含まれるsec-fetch-site値がsame-originになっていることで確認できます)ので、この設定は不要ですが、備忘目的で設定しています。

2. "frontchannel_logout_session_required"をTrueに設定しています。

3. "frontchannel_logout_uri"に"https://webgw.localdomain/irisclient/csp/user/MyApp.Logout.cls"を設定しています。

管理ポータル上には下記のように表示されています。このURLに遷移する際は、IRISLogout=endが自動付与されます。

>If the front channel logout URL is empty, the client won't support front channel logout.
'IRISLogout=end' will always be appended to any provided URL.

IRISドキュメントに記述はありませんが、Cache'の同等機能の記述は[こちら](https://docs.intersystems.com/latest/csp/docbook/DocBook.UI.Page.cls?KEY=GCSP_sessions)です。IRISLogout=endは、CSPセッション情報の破棄を確実なものとするためと理解しておけば良いでしょう。

> 一般論として、ログアウト時のRP側での処理は認可サーバ側では制御不可能です。本当にセッションやトークンを破棄しているか知るすべがありません。IRISLogout=endはRPがCSPベースである場合に限り、それら(cspセッションとそれに紐づくセッションデータ)の破棄を強制するものです。非CSPベースのRPにとっては意味を持ちませんので、無視してください。

# 各サーバの設定について

各サーバの設定内容とサーバ環境を自動作成する際に使用した各種インストールスクリプトに関する内容です。

## 認可サーバ

認可サーバ上の、oAUth2/OIDC関連の設定は、[MyApps.Installer](https://github.com/IRISMeister/iris-oauth2/blob/master/irisauth/src/MyApps/Installer.cls)にスクリプト化してあります。

下記の箇所で、「OAuth 2.0 認可サーバ構成」を行っています。
```
Set cnf=##class(OAuth2.Server.Configuration).%New()
  ・
  ・
Set tSC=cnf.%Save()
```

これらの設定は、[認可サーバ](http://webgw.localdomain/irisauth/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Server.Configuration.zen#0)で確認できます。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/oauth-server-config.png)

## 認可サーバ上のクライアントデスクリプション

下記のような箇所が3か所あります。これらは「 OAuth 2.0 サーバ クライアントデスクリプション」で定義されている、python, curl, angularのエントリに相当します。
```
Set c=##class(OAuth2.Server.Client).%New()
Set c.Name = "python"
  ・
  ・
Set tSC=c.%Save()
```
> これらに続くファイル操作は、利便性のためにclient_idなどをファイル出力しているだけで、本来は不要な処理です。

> これらはコンテナイメージのビルド時に実行されます。

これらの設定は、[認可サーバ](http://webgw.localdomain/irisauth/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Server.ClientList.zen?)で確認できます。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/oauth-serverside-client-desc.png)

## CSPベースのWebアプリケーション

実行内容の説明は、クライアント編で行います。

CSPベースのWebアプリケーションの設定は、[MyApps.Installer](https://github.com/IRISMeister/iris-oauth2/blob/master/irisclient/src/MyApps/Installer.cls)にスクリプト化してあります。

oAUth2/OIDC関連の設定(クライアントの動的登録)は、irisclient用の[RegisterAll.mac](https://github.com/IRISMeister/iris-oauth2/blob/master/irisclient/src/MyApp/RegisterAll.mac)、およびirisclient2用の[RegisterAll.mac](https://github.com/IRISMeister/iris-oauth2/blob/master/irisclient2/src/MyApp/RegisterAll.mac)にスクリプト化してあります。

> これらは[register_oauth2_client.sh](https://github.com/IRISMeister/iris-oauth2/blob/master/register_oauth2_client.sh)により、コンテナ起動後に実行されます。

これらの設定は、[クライアント用サーバ](http://webgw.localdomain/irisclient/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Client.Configuration.zen?PID=USER_CLIENT_APP&IssuerEndpointID=1&IssuerEndpoint=https%3A%2F%2Fwebgw.localdomain%2Firisauth%2Fauthserver%2Foauth2#0)で確認できます。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/client-config.png)

動的登録を行った時点で、これらの内容が認可サーバに渡されて、認可サーバ上に保管されます。その内容は、認可サーバで確認できます。
> ビルド時に生成されるclient_idがURLに含まれるため、リンクを用意できません。画像イメージのみです。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/serverside-client-config.png)

## リソースサーバ

リソースサーバの設定は、[MyApps.Installer](https://github.com/IRISMeister/iris-oauth2/blob/master/irisrsc/src/MyApps/Installer.cls)にスクリプト化してあります。

リソースサーバのRESTサービスは、IRISユーザUnknownUserで動作しています。

リソースサーバは、受信したトークンのバリデーションをするために、[REST APIの実装](https://github.com/IRISMeister/iris-oauth2/blob/master/irisrsc/src/API/REST.cls)で、下記のAPIを使用しています。

アクセストークンをhttp requestから取得します。
```objectscript
set accessToken=##class(%SYS.OAuth2.AccessToken).GetAccessTokenFromRequest(.tSC)
```

アクセストークンのバリデーションを実行します。この際、..#AUDがアクセストークンのaudクレームに含まれていることをチェックしています。
```objectscript
if '(##class(%SYS.OAuth2.Validation).ValidateJWT($$$APP,accessToken,,..#AUD,.jsonObjectJWT,.securityParameters,.tSC)) {
```

署名の有無の確認をしています。
```objectscript
Set sigalg=$G(securityParameters("sigalg"))
if sigalg="" { 
  set reason=..#HTTP401UNAUTHORIZED
  $$$ThrowOnError(tSC)				
}
```

(べた書きしていますが)受信したアクセストークンのSCOPEクレーム値がscope1を含まない場合、http 404エラーを返しています。
```objectscript
if '(jsonObjectJWT.scope_" "["scope1 ") { set reason=..#HTTP404NOTFOUND throw }
```

oAUth2/OIDC関連の設定(クライアントの動的登録)は、[Register.mac](https://github.com/IRISMeister/iris-oauth2/blob/master/irisrsc/src/API/Register.mac)にスクリプト化してあります。

> これらは[register_oauth2_client.sh](https://github.com/IRISMeister/iris-oauth2/blob/master/register_oauth2_client.sh)により、コンテナ起動後に実行されます。

これらの設定は、[リソースサーバ](http://webgw.localdomain/irisrsc/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Client.Configuration.zen?PID=RESSERVER_APP&IssuerEndpointID=1&IssuerEndpoint=https%3A%2F%2Fwebgw.localdomain%2Firisauth%2Fauthserver%2Foauth2#0)で確認できます。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/rsc-config.png)

動的登録を行った時点で、これらの内容が認可サーバに渡されて、認可サーバ上に保管されます。その内容は、認可サーバで確認できます。
> ビルド時に生成されるclient_idがURLに含まれるため、リンクを用意できません。画像イメージのみです。

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/serverside-rsc-config.png)

## 署名(JWK)

認可サーバをセットアップすると、一連の暗号鍵ペアが作成されます。これらはJWTで表現されたアクセストークンやIDトークンを署名する(JWS)ために使用されます。

鍵情報は認可サーバのデータべースに保存されています。参照するにはirisauthで下記SQLを実行します。	

```
$ docker compose exec irisauth iris session iris -U%SYS "##class(%SYSTEM.SQL).Shell()"

SELECT PrivateJWKS,PublicJWKS FROM OAuth2_Server.Configuration
```
PrivateJWKSの内容だけを見やすいように整形すると[こちら](https://github.com/IRISMeister/iris-oauth2/blob/main/docs/PrivateJWKS.json)のようになります。

実際にアクセストークンを https://jwt.io/ で確認してみます。ヘッダにはkidというクレームが含まれます。これはトークンの署名に使用されたキーのIDです。
```
{
  "typ": "JWT",
  "alg": "RS512",
  "kid": "3"
}
```

これで、このトークンはkid:3で署名されていることがわかります。
この時点で、Signature Verifiedと表示されていますが、これはkid:3の公開鍵を使用して署名の確認がとれたことを示しています。

> 公開鍵は[公開エンドポイント](https://webgw.localdomain/irisauth/authserver/oauth2/jwks)から取得されています

次に、エンコード処理(データへのJWSの付与)を確認するために、ペーストしたトークンの水色の部分(直前のピリオドも)をカットします。Invalid Signatureに変わります。

さきほどSQLで表示したPrivateJWKSの内容のkid:3の部分だけ(下記のような内容)を抜き出して下のBOXにペーストします。

```
{
  "kty": "RSA",
  "n": "....",
  "e": "....",
  "d": "....",
    ・
    ・
    ・
  "alg": "RS512",
  "kid": "3"
}
```

![](https://raw.githubusercontent.com/IRISMeister/iris-oauth2/main/docs/images/jwtio.png)

水色部分が復元され、再度、Signature Verifiedと表示されるはずです。また、水色部分は元々ペーストしたアクセストークンのものと一致しているはずです。

> 本当に大切な秘密鍵はこういう外部サイトには張り付けないほうが無難かも、です

# ログ取得方法

各所でのログの取得方法です。

## 認可サーバ(IRIS)
認可サーバ上の実行ログを取得、参照出来ます。クライアントの要求が失敗した際、多くの場合、クライアントが知りえるのはhttpのステータスコードのみで、その理由は明示されません。認可サーバ(RPがIRISベースの場合は、クライアントサーバでも)でログを取得すれば、予期せぬ動作が発生した際に、原因のヒントを得ることができます。

- ログ取得開始  
  ```bash
  ./log_start.sh
  ```
  これ以降、発生した操作に対するログが保存されます。ログは^ISCLOGグローバルに保存されます。

- ログを出力  

  ログは非常に多くなるので、いったんファイルに出力してIDE等で参照するのが良いです。
  ```bash
  ./log_display.sh
  ```
  [Webアプリケーション1a](https://webgw.localdomain/irisclient/csp/user/MyApp.Login.cls)をユーザエージェント(ブラウザ)からアクセスした際のログファイルの出力例は[こちら](https://github.com/IRISMeister/iris-oauth2/blob/master/docs/logging.txt)です。

- ログを削除  
  ログを削除します。ログ取得は継続します。  
  ```bash
  ./log_clear.sh
  ```

- ログ取得停止
  ログ取得を停止します。ログ(^ISCLOGグローバル)は削除されません。
  ```bash
  ./log_end.sh
  ```

## IRISサーバのログ確認
IRISサーバが稼働しているサービス名(認可サーバならirisauth)を指定します。

IRISコミュニティエディション使用時に、接続数オーバ等を発見できます。

```
docker compose logs -f irisauth
```

## WebGWのログ確認
WebGWコンテナ内で稼働するapacheのログを確認できます。

全体の流れを追ったり、エラー箇所を発見するのに役立ちます。

```
docker compose logs -f webgw
```
