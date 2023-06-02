#!/bin/bash

touch bla.temp
/opt/nifi/scripts/start.sh &
pid=$!
if [[ ! -f "created" ]]; then
while true; do
    curl -s --head http://localhost:8080/nifi | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null
    if [ $? -eq 0 ]; then
        echo "NIFI Website is up."
        break
    else
        echo "NIFI Website is down."
        sleep 5
    fi
done
# Set the nifi cli path
NIFI_CLI=/opt/nifi/nifi-toolkit-current/bin/cli.sh

# Set the nifi url
NIFI_URL=http://localhost:8080/nifi

REG_CLIENT_EXISTS=$($NIFI_CLI nifi get-reg-client-id -rcn regclient1|grep -c regclient1)
if [ $REG_CLIENT_EXISTS -gt 0 ]; then
echo "Creating reg client"
$NIFI_CLI nifi create-reg-client -u ${MY_HOST} --registryClientUrl ${NIFI_REG} --registryClientName regclient1
fi
echo "checking bucket"
BUCKETS_EXISTS=$($NIFI_CLI registry list-buckets -u ${NIFI_REG}| grep -c "MyBucket")



 
if [ $BUCKETS_EXISTS -lt 1 ]; then
echo "bucket does not exist"
$NIFI_CLI registry create-bucket -u ${NIFI_REG} --bucketName MyBucket
BUCKET_ID=$($NIFI_CLI registry list-buckets -u ${NIFI_REG}|grep MyBucket|awk '{print $3}')
$NIFI_CLI registry create-flow -u ${NIFI_REG} --bucketIdentifier $BUCKET_ID --flowName MyFlow
FLOWID=$($NIFI_CLI registry list-flows -u ${NIFI_REG} --bucketIdentifier=$BUCKET_ID|grep MyFlow|awk '{print $3}')
$NIFI_CLI registry import-flow-version -u ${NIFI_REG} -f $FLOWID -i /home/nifi/NGSILDHL7Flow.json
$NIFI_CLI nifi pg-import --bucketIdentifier $BUCKET_ID --flowIdentifier $FLOWID --flowVersion 1
fi
PG_ID=$($NIFI_CLI nifi pg-list|grep 1|awk '{print $4}')
$NIFI_CLI nifi pg-enable-services --processGroupId $PG_ID
$NIFI_CLI nifi pg-start --processGroupId $PG_ID
touch created
fi
wait $pid
