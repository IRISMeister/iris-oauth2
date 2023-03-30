# 署名のチェック

IDトークンをhttps://jwt.io/ で確認してみます。まずは、そのままペーストすれば下記が得られます。

Header
```
{
  "typ": "JWT",
  "alg": "RS512",
  "kid": "3"
}
```

Payload
```
{
  "iss": "https://webgw.localdomain/irisauth/authserver/oauth2",
  "sub": "test",
  "exp": 1679629322,
  "auth_time": 1679625721,
  "iat": 1679625722,
  "nonce": "M79MJF6HqHHDKFpK4ZZJkaD3moE",
  "at_hash": "AFeWfbXALP78Y9KEhlKnp_5LJmEjthJQlJDGXh_eLPc",
  "aud": [
    "https://webgw.localdomain/irisrsc/csp/myrsc",
    "https://webgw.localdomain/irisrsc2/csp/myrsc",
    "SrGSiVPB8qWvQng-N7HV9lYUi5WWW_iscvCvGwXWGJM"
  ],
  "azp": "SrGSiVPB8qWvQng-N7HV9lYUi5WWW_iscvCvGwXWGJM",
  "sid": "yxGBivVOuMZGr2m3Z5AkScNueppl8Js_5cz2KvVt6dU"
}
```

"Signature Verified"と表示されているはずです。つまり、署名により内容が改ざんされていないことが確認されます。

次に、逆(署名を作成する)を試します。先ほどペーストした内容の2番目の.から後ろ(署名部分)を全てカットします。

使用された秘密鍵を得るためにirisauthで下記SQLを実行します。	

```
SELECT PrivateJWKS FROM OAuth2_Server.Configuration
```
出力を見やすいように整形すると[こちら](PrivateJWKS.json)のようになります。

ここで、欲しいのはkid:3の部分だけなので、該当箇所だけを抜き出したもの(下記)をhttps://jwt.io/のPrivate Keyの欄にペーストします。

> "Private Key in PKCS #8, PKCS #1, or JWK string format. The key never leaves your browser."と表示されている欄

```
{
  "kty": "RSA",
  "n": "....",
    ・
    ・
    ・
  "alg": "RS512",
  "kid": "3"
}
```

"Signature Verified"と表示されているはずです。
先ほどカットした箇所に再度署名が復元されています。また、この内容は、最初にペーストしたアクセストークンの内容と一致するはずです。


