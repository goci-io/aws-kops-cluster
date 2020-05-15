#!/bin/sh

method=$1

if [[ "$method" == "kubecfg" ]]; then
    kops export kubecfg
else
    client_id=$(jq '.client_id' ${2})
    client_secret=$(jq '.client_secret' ${2})
    audience=$(jq '.audience' ${2})
    issuer=$(jq '.issuer' ${2})
    user=$(jq '.user' ${2})
    token=$(curl -X POST ${issuer}/oauth/token \
        -H "Accept: application/json" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&audience=$audience" \
        | jq '.access_token')

    kubectl config set-credentials "$user" \
        --auth-provider=oidc \
        --auth-provider-arg=idp-issuer-url="$issuer" \
        --auth-provider-arg=client-id="$client_id" \
        --auth-provider-arg=client-secret="$client_secret" \
        --auth-provider-arg=id-token="$token"

    kubectl config set-context ${KOPS_CLUSTER_NAME} --cluster=${KOPS_CLUSTER_NAME} --user="$user" --server=https://${KOPS_CLUSTER_NAME} 
fi
