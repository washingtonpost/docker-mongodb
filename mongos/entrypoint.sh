#!/bin/bash
set -e

if [[ "$MONGODB_ADMIN_PASSWORD" ]]; then
  mongo="mongo -u admin -p ${MONGODB_ADMIN_PASSWORD} --authenticationDatabase admin"
else
  mongo="mongo"
fi

function wait_for_startup() {
  local host="$1"
  local port="$2"
  local primary="${3:-1}"
  while ! nc -z $host $port; do
    echo "waiting for $host:$port to start"
    sleep 1
  done

  if [ "$primary" == "1" ]; then
    echo "checking for primary status for $host:$port"

    while ! $mongo $host:$port/admin --quiet --eval "rs.status()" | grep PRIMARY
    do
      echo "waiting for $host:$port to be elected primary"
      sleep 1
    done
  fi
}

function add_shard() {
  if [ -z "$MONGODB_REPL_SET" ]; then
    echo "MONGODB_REPL_SET environment variable must be set"
    exit 1
  fi
  wait_for_startup localhost 27017 0

  echo $mongo
  $mongo localhost:27017 --quiet --eval "db = db.getSiblingDB('config'); if (!db.shards.count()) { printjson(sh.addShard(\"$MONGODB_REPL_SET/$MONGODB_SHARD:27018\"))}"
}

if [ "${1:0:1}" = '-' ]; then
	set -- mongos "$@"
fi

if [ "$1" = 'mongos' ]; then
	chown -R mongodb /data/db

	numa='numactl --interleave=all'
	if $numa true &> /dev/null; then
		set -- $numa "$@"
	fi

  wait_for_startup $MONGODB_HOST 27018
  wait_for_startup $CONFIGDB_HOST 27019

  params="$@"

  if [[ "$MONGODB_ADMIN_PASSWORD" ]]; then
    echo "$MONGODB_ADMIN_PASSWORD" | base64 > /tmp/mongodb-keyfile
    chmod 600 /tmp/mongodb-keyfile
    chown mongodb /tmp/mongodb-keyfile
    params="$params --keyFile=/tmp/mongodb-keyfile"
  fi

  if [[ "$CONFIGDB_REPL_SET" ]]; then
    params="$params --configdb ${CONFIGDB_REPL_SET}/node0:27017"
  fi

  if [[ $MONGODB_SHARD ]]; then
    if [[ "$NODE_ID" == "0" ]]; then
      add_shard &
    fi
  fi

	exec gosu mongodb $params
fi

exec "$@"
