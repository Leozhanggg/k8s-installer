#!/bin/sh

cn=$1
tls=$2
ns=$3

if  [ ! "$tls" ] ;then
  tls=tls-secret
fi

if  [ ! "$ns" ] ;then
  ns=default
fi

rm -rf tls.key tls.crt
kubectl delete secret $tls --namespace $ns 2> /dev/null

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=$cn"
kubectl create secret tls $tls --key tls.key --cert tls.crt --namespace $ns

