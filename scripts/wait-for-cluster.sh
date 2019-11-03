#!/bin/sh
set -e

echo "Wait for cluster to start up the first time..."

starting=1
retries=0

while [ $retries -lt 5 && $starting -ne 0 ]; do
    sleep $retries * 180
    
    set +e
    kops validate cluster
    starting=$?
    set -e

    echo "Retrying..."    
done

if [ $starting -eq 0 ]; then
    echo "Cluster startup successful."
    exit 0
else
    echo "Cluster came not up within $retries retries. See logs above for more details."
    exit 1
fi
