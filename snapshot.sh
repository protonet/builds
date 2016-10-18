#!/usr/bin/env bash

set -eu
set -o pipefail

CHANNEL=${CHANNEL:=""}
DELETE_OLD=${DELETE_OLD:=""}

delete_snapshots() {
	local CHAN=$1

	SNAPSHOT_IDS=$(aws ec2 describe-snapshots --filters Name=tag:Name,Values=zpool-snapshot-$CHAN-* | jq .Snapshots[].SnapshotId --raw-output)
	xargs --no-run-if-empty -L1 aws ec2 delete-snapshot --snapshot-id <<< $SNAPSHOT_IDS
}

if [ -z "$CHANNEL" ]; then
	#CHANNEL=$(git show --no-commit-id --pretty="" --name-only HEAD)
	CHANNEL=$(git diff-tree --no-commit-id --name-only HEAD)
	CHANGED_FILES=$(wc -l <<< "$CHANNEL")
	if [[ $CHANGED_FILES -ne 1 ]]; then
		echo "$CHANGED_FILES files have changed."
		echo $CHANNEL
		echo "Exitting."
		exit 0
  fi

	if ! grep -q '\.json$' <<< $CHANNEL; then
		echo "Changed file isn't a JSON. Exitting."
		exit 0
	fi
fi

trap 'vagrant destroy -f' EXIT
vagrant up --provider=aws

cat $CHANNEL | jq '.[0].images | keys[] as $k | $k + ":" + .[$k]' --raw-output | vagrant ssh -c 'xargs -L1 docker pull'
BUILD_NO=$(cat $CHANNEL | jq .[0].build)
vagrant ssh -c 'docker images'
vagrant ssh -c 'zpool status'
vagrant ssh -c 'sync'
vagrant halt

CHANNEL_WITHOUT_EXT=$(sed 's/\.json$//' <<< $CHANNEL)

if [ $DELETE_OLD == "true" ]; then
	delete_snapshots $CHANNEL_WITHOUT_EXT
fi

VOLUME_ID=$(aws ec2 describe-instances --instance-ids $(<.vagrant/machines/*/aws/id) | jq '.Reservations[0].Instances[0].BlockDeviceMappings[] | select(.DeviceName == "/dev/xvdb") | .Ebs.VolumeId' --raw-output)
SNAPSHOT_ID=$(aws ec2 create-snapshot --volume-id $VOLUME_ID --description "SoP zpool snapshot, channel $CHANNEL_WITHOUT_EXT, build $BUILD_NO" | jq .SnapshotId --raw-output)
aws ec2 create-tags --resources $SNAPSHOT_ID --tags "Key=Name,Value=zpool-snapshot-$CHANNEL_WITHOUT_EXT-$BUILD_NO" "Key=Channel,Value=$CHANNEL"
