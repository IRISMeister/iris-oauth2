# InterSystems API Manager(IAM)をBFFとして利用する

さらに元のタイトルから外れますがInterSystems API Manager(IAM)をBFFとして利用する方法をご紹介します。

> 個人調べです。誤りがあるかもしれませんが、その際はご容赦ください。

<!--break-->

# 相違点
クライアント編ではInterSystems IRISをBFFのサーバとして使用していましたが、この場合、IAMがBFFサーバ相当になります。RPはSPA(Angular)です。

```text
                      login/logout
      +-----------------------------------------------------+
      |                                                     | 
ブラウザ(SPA) -----Apache--+--> Webpack                     |
(ユーザセッション,         +--> IAM ------------+----> 認可サーバ
session)                      (session,AT等)    |      (ユーザセッション)
                                                 +--> リソースサーバ
```

# 環境
IAM(KONG Enterprise)の実行には、有効なIRISライセンスキー(IAMキー付きのコンテナ用ライセンスキー)が必要です。KONGのOpenID Connectプラグインを使用します。

# ビルド

最新のソースコードの再取得を行います。

## サーバ環境
以前に、git clone実行されている方は、再度git pullをお願いします。始めて実行される方は、[サーバ編](https://jp.community.intersystems.com/node/539046)をご覧ください。

```
cd iris-oauth2
git pull
./iam-build.sh
```

## クライアント環境
以前に、git clone実行されている方は、再度git pullをお願いします。始めて実行される方は、[クライアント編](https://jp.community.intersystems.com/node/539491)をご覧ください。

```
cd angular-oauth2-client
git pull
```
クライアントのビルド(デプロイ)には、稼働中のサーバ環境が必要なので、この時点ではビルドは行いません。

# 実行

## サーバ環境
```
cd iris-oauth2
./license/iris.key に有効なライセンスキーを配置
./iam-up.sh
    ・
    ・
Angular based clien App | https://webgw.localdomain:8443//myapp/#/home
IAM Portal | http://localhost:8002
```

## クライアント
サーバ環境が起動した事を確認の上、実行します。

```
cd angular-oauth2-client
./build_and_deploy.sh
```
### 操作方法

[クライアント編](https://jp.community.intersystems.com/node/539491)と同じです。[KONGでログイン](https://webgw.localdomain/myapp/)を実行できます。

### エラー
下記エラーが出た場合、IRISサーバ環境が古いままです。

```
$ ./build_and_deploy.sh
✔ Browser application bundle generation complete.

Error: src/app/display-info-bff/display-info-bff.component.ts:44:26 - error TS2339: Property 'OP' does not exist on type '{ clientId: string; authUri: string; logoutUri: string; tokenUri: string; userinfoUri: string; redirectUri: string; scope: string; frontchannel_logout_uri: string; post_logout_redirect_uri: string; }'.

44     if (environment.auth.OP==='iris') {
                            ~~
```

## 制限事項

KONGのOpenID Connectプラグインはログアウトにback channel logoutのみをサポートしています。IRISのログアウトはfront channel logoutですので、そのままではログアウトが完全には動作しません。そのため、プラグインの「config.logout_revoke」を有効にしてあります。これにより、ログアウトのリクエスト送信とトークンの無効化リクエストの両方がIRISのOPに送信され、結果としてトークンは無効化されます。  
既にRevokeにより無効化されたトークンへのログアウトリクエストが送信されるため、IRIS(OP)側では下記のような警告が出ます。

```
**OAuth2Server-3 2023-05-09 05:01:53.75915953 ns=%SYS routine=OAuth2.Server.Logout.1 job=1024 sessionid=MBBDEtygxy
[OAuth2.Server.Logout:ReturnError]
error=invalid_request, error_description=ID Token not found
```

また、front channelを使用できないため、IRIS(OP)のユーザセッション(http onlyのcookie)をクリアすることができず、次回以降のログイン時のユーザ名・パスワード入力がスキップされます。このままでは「セッション終了間隔」の時間(デフォルトで24時間)が経過しない限り、異なるユーザでのログインが出来なくなりますのでIAMのOpenId Connectプラグイン使用時は「ユーザセッションをサポート」を無効化したほうが良いかもしれません。