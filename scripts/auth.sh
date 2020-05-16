#!/bin/sh
set -e
method=$1
cluster=$2

if [[ "$method" == "kubecfg" ]]; then
    kops export kubecfg
else
    token=$(kops get secrets --type secret admin -oplaintext)
    kubectl config set-credentials admin --token=${token}
    kubectl config set-cluster ${cluster} --server=https://${cluster}
    kubectl config set-context ${cluster} --cluster=${cluster} --user=admin
    kubectl config use-context ${cluster}
fi
