#!/bin/bash

dir=$(dirname $0)
pushd $dir

touch CSP.ini
touch CSP.log
touch CSPRT.ini

apacheUser=daemon

chmod 600 CSP.ini
chown $apacheUser CSP.ini
chmod 600 CSP.log
chown $apacheUser CSP.log
chmod 600 CSPRT.ini
chown $apacheUser CSPRT.ini

configAuth=irisauth
configRsc1=irisrsc
configRsc2=irisrsc2
configClient=irisclient
configClient2=irisclient2
port=${SERVER_PORT-51773}
username=${USERNAME-CSPSystem}
password=${PASSWORD-SYS}

# [SYSTEM]
./cvtcfg setparameter "CSP.ini" "[SYSTEM]" "System_Manager" "*.*.*.*"
# to prevent [Status=Server] connections. WRC #903951
./cvtcfg setparameter "CSP.ini" "[SYSTEM]" "REGISTRY_METHODS" "Disabled"

# [SYSTEM_INDEX]
./cvtcfg setparameter "CSP.ini" "[SYSTEM_INDEX]" "$configAuth" "Enabled"
./cvtcfg setparameter "CSP.ini" "[SYSTEM_INDEX]" "$configRsc1" "Enabled"
./cvtcfg setparameter "CSP.ini" "[SYSTEM_INDEX]" "$configRsc2" "Enabled"
./cvtcfg setparameter "CSP.ini" "[SYSTEM_INDEX]" "$configClient" "Enabled"
./cvtcfg setparameter "CSP.ini" "[SYSTEM_INDEX]" "$configClient2" "Enabled"

# [Auth server]
./cvtcfg setparameter "CSP.ini" "[${configAuth}]" "Ip_Address" "$configAuth"
./cvtcfg setparameter "CSP.ini" "[${configAuth}]" "TCP_Port" "$port"
./cvtcfg setparameter "CSP.ini" "[${configAuth}]" "Username" "$username"
./cvtcfg setparameter "CSP.ini" "[${configAuth}]" "Password" "$password"

# [Resource server #1]
./cvtcfg setparameter "CSP.ini" "[${configRsc1}]" "Ip_Address" "$configRsc1"
./cvtcfg setparameter "CSP.ini" "[${configRsc1}]" "TCP_Port" "$port"
./cvtcfg setparameter "CSP.ini" "[${configRsc1}]" "Username" "$username"
./cvtcfg setparameter "CSP.ini" "[${configRsc1}]" "Password" "$password"

# [Resource server #2]
./cvtcfg setparameter "CSP.ini" "[${configRsc2}]" "Ip_Address" "$configRsc2"
./cvtcfg setparameter "CSP.ini" "[${configRsc2}]" "TCP_Port" "$port"
./cvtcfg setparameter "CSP.ini" "[${configRsc2}]" "Username" "$username"
./cvtcfg setparameter "CSP.ini" "[${configRsc2}]" "Password" "$password"

# [CSP based Client App server]
./cvtcfg setparameter "CSP.ini" "[${configClient}]" "Ip_Address" "$configClient"
./cvtcfg setparameter "CSP.ini" "[${configClient}]" "TCP_Port" "$port"
./cvtcfg setparameter "CSP.ini" "[${configClient}]" "Username" "$username"
./cvtcfg setparameter "CSP.ini" "[${configClient}]" "Password" "$password"

# [CSP based Client2 App server]
./cvtcfg setparameter "CSP.ini" "[${configClient2}]" "Ip_Address" "$configClient2"
./cvtcfg setparameter "CSP.ini" "[${configClient2}]" "TCP_Port" "$port"
./cvtcfg setparameter "CSP.ini" "[${configClient2}]" "Username" "$username"
./cvtcfg setparameter "CSP.ini" "[${configClient2}]" "Password" "$password"

# [APP_PATH_INDEX]
./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/" "Disabled"
./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/csp" "Disabled"
# enabling /fhir to accept fhir endpoint
./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/fhir" "Enabled"
./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/iris-on-fhir" "Enabled"

./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/$configAuth" "Enabled"
./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/$configRsc1" "Enabled"
./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/$configRsc2" "Enabled"
./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/$configClient" "Enabled"
./cvtcfg setparameter "CSP.ini" "[APP_PATH_INDEX]" "/$configClient2" "Enabled"

# [APP_PATH:/]
./cvtcfg setparameter "CSP.ini" "[APP_PATH:/]" "Default_Server" "LOCAL"

# [APP_PATH:/csp]
# /csp point to resource server #2 which is fhir server
#./cvtcfg setparameter "CSP.ini" "[APP_PATH:/csp]" "Default_Server" "$configRsc2"
# [APP_PATH:/fhir]
./cvtcfg setparameter "CSP.ini" "[APP_PATH:/fhir]" "Default_Server" "$configRsc2"
# [APP_PATH:/iris-on-fhir]
./cvtcfg setparameter "CSP.ini" "[APP_PATH:/iris-on-fhir]" "Default_Server" "$configRsc2"

# [APP_PATH:/irisauth]
./cvtcfg setparameter "CSP.ini" "[APP_PATH:/$configAuth]" "Default_Server" "$configAuth"
# [APP_PATH:/irisrsc]
./cvtcfg setparameter "CSP.ini" "[APP_PATH:/$configRsc1]" "Default_Server" "$configRsc1"
# [APP_PATH:/irisrsc2]
./cvtcfg setparameter "CSP.ini" "[APP_PATH:/$configRsc2]" "Default_Server" "$configRsc2"
# [APP_PATH:/irisclient]
./cvtcfg setparameter "CSP.ini" "[APP_PATH:/$configClient]" "Default_Server" "$configClient"
# [APP_PATH:/irisclient2]
./cvtcfg setparameter "CSP.ini" "[APP_PATH:/$configClient2]" "Default_Server" "$configClient2"

popd

httpd-foreground