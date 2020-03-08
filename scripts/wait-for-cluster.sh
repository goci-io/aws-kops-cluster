#!/bin/sh
set -e

kops export kubecfg

echo "Wait for cluster to start up the first time..."

set +e
kops validate cluster
starting=$?
set -e

retries=0

while [[ $retries -lt 15 && $starting -ne 0 ]]; do
    timeout=$(($retries*60+60))
    echo "Waiting $timeout seconds before validating cluster" 
    sleep $timeout
    
    echo "Retrying..."
    retries=$(($retries+1))

    set +e
    kops validate cluster
    starting=$?
    set -e
done

if [[ $starting -eq 0 ]]; then
    echo "Cluster startup successful."
    exit 0
else
    echo "Cluster came not up within $retries retries. See logs above for more details."
    exit 1
fi
