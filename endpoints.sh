#!/bin/bash
source ./params.sh

echo "Useful links..."
echo "Web Gateway | http://${HOST_NAME}/csp/bin/Systems/Module.cxw"
echo "Auth Server SMP | http://${HOST_NAME}/irisauth/csp/sys/%25CSP.Portal.Home.zen"
echo "open-id config | http://${HOST_NAME}/irisauth/authserver/oauth2/.well-known/openid-configuration"
echo "RSC #1 SMP | http://${HOST_NAME}/irisrsc/csp/sys/%25CSP.Portal.Home.zen"
echo "RSC #2 SMP | http://${HOST_NAME}/irisrsc2/csp/sys/%25CSP.Portal.Home.zen"
echo "CSP based client server SMP | http://${HOST_NAME}/irisclient/csp/sys/%25CSP.Portal.Home.zen"
echo "CSP based client App1-1 | https://${HOST_NAME}/irisclient/csp/user/MyApp.Login.cls"
echo "CSP based client App1-2 | https://${HOST_NAME}/irisclient/csp/user2/MyApp.Login.cls"
echo "CSP based client server SMP | http://${HOST_NAME}/irisclient2/csp/sys/%25CSP.Portal.Home.zen"
echo "CSP based client App2 | https://${HOST_NAME}/irisclient2/csp/user/MyApp.AppMain.cls"
echo "Angular based clien App | https://${HOST_NAME}/myapp/ https://${HOST_NAME}/myapp2/"
