#!/bin/bash
pushd apache-ssl

p1=01
p2=01
if [ ! -z "$1" ]; then
    p1=$1
fi
if [ ! -z "$2" ]; then
    p2=$2
fi
./setup.sh webgw.localdomain $p1 $p2
cp ssl/* ../ssl/web/

./setup.sh auth.localdomain $p1 $p2
cp ssl/* ../irisauth/ssl/auth/

./setup.sh client.localdomain $p1 $p2
cp ssl/* ../irisclient/ssl/client/

./setup.sh client2.localdomain $p1 $p2
cp ssl/* ../irisclient2/ssl/client/

# two resource servers share the same key.
./setup.sh resserver.localdomain $p1 $p2
cp ssl/* ../irisrsc/ssl/resserver/

popd
