#!/usr/bin/env python
# -*- coding: utf-8 -*-
# BSD 2-clause

from O365 import Account, FileSystemTokenBackend

#import logging
#logging.basicConfig(level=logging.DEBUG)

TOKEN_FILENAME='token.json'
TOKEN_PATH='.'

#Microsoft 365 開発者プログラムアカウント app : myapp
TENANT_ID = 'xxxxx'
CLIENT_ID = 'yyyyy'
CLIENT_SECRET = 'zzzzz'

AUTH_FLOW='authorization'
SCOPES = ['openid','profile','offline_access','api://xxx-xxx-xxx-xxx-xxx/scope1']
token_backend = FileSystemTokenBackend(token_path=TOKEN_PATH, token_filename=TOKEN_FILENAME)
credentials=(CLIENT_ID, CLIENT_SECRET)
account = Account(credentials=credentials, scopes=SCOPES, token_backend=token_backend, auth_flow_type=AUTH_FLOW, tenant_id=TENANT_ID)

def refresh():
    if not account.is_authenticated:
      print('Not authenticated yet')
    else:
      account.connection.refresh_token()
      print('Refreshed!')
      with open('access_token', mode='w') as f:
        f.write(token_backend.get_token()['access_token'])
      return token_backend.get_token()['access_token']

if __name__ == '__main__':
    if not account.is_authenticated:
        account.authenticate()
        print('Authenticated!')
    else:
        account.connection.refresh_token()
        print('Refreshed!')

    with open('access_token', mode='w') as f:
        f.write(token_backend.get_token()['access_token'])

