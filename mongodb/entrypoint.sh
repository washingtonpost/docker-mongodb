#!/bin/bash
set -e

if [[ "$MONGODB_ADMIN_PASSWORD" ]]; then
  mongo="mongo -u admin -p ${MONGODB_ADMIN_PASSWORD} --authenticationDatabase admin"
else
  mongo="mongo"
fi

function auth_initiate() {
  params="$@"
	gosu mongodb $params &
  pid=$!

  while ! nc -z localhost $MONGODB_PORT; do
    echo "waiting for mongodb to start"
    sleep 1
  done

  mongo localhost:$MONGODB_PORT/admin --eval "if(!db.getUser(\"admin\")) { printjson(db.createUser({user: \"admin\", pwd: \"${MONGODB_ADMIN_PASSWORD}\", roles: [{role: \"root\", db: \"admin\"}, {role: \"userAdminAnyDatabase\", db: \"admin\"}, {role: \"readAnyDatabase\", db: \"admin\"}]})) }"

  echo 'killing mongodb after auth initiation'
  kill -2 $pid

  while nc -z localhost $MONGODB_PORT; do
    echo "waiting for mongodb to stop"
    sleep 1
  done

  while [ -s /data/db/mongod.lock ]; do
    echo 'waiting for /data/db/mongod.lock to disappear'
    sleep 1
  done
}

function rs_initiate() {
  if [ -z "$MONGODB_PORT" ]; then
    echo "MONGODB_PORT environment variable must be set"
    exit 1
  fi

  if [ -z "$NODE_LIST" ]; then
    echo "NODE_LIST environment variable must be set"
    exit 1
  fi

  while ! nc -z localhost $MONGODB_PORT; do
    echo "waiting for mongodb to start"
    sleep 1
  done

  echo "$mongo localhost:$MONGODB_PORT/admin --quiet --eval \"rs.status().set\" | wc -l)"
  IS_REPL_SET=$($mongo localhost:$MONGODB_PORT/admin --quiet --eval "rs.status().set" | wc -l)
  if [ "$IS_REPL_SET" != "0" ]; then
    echo "already a replica set"
    return
  fi

  echo "initiating replica set..."
  local first_node=0
  echo $NODE_LIST | sed -n 1'p' | tr ',' '\n' | while read node; do
    if [ "$first_node" == "0" ]; then
      first_node=1
      $mongo localhost:$MONGODB_PORT/admin --quiet --eval "printjson(rs.initiate())"
      $mongo localhost:$MONGODB_PORT/admin --quiet --eval "cfg = rs.conf(); cfg.members[0].host = \"$node:$MONGODB_PORT\"; printjson(rs.reconfig(cfg))"

      while ! $mongo localhost:$MONGODB_PORT/admin --quiet --eval "db.isMaster().ismaster" | grep true
      do
        echo "waiting for $node to become primary"
        sleep 1
      done

    else
      while $mongo localhost:$MONGODB_PORT/admin --quiet --eval "printjson(rs.add(\"$node:$MONGODB_PORT\"))" | grep -l '"ok"\s*:\s*0'
      do
        echo "failed to add $node to mongodb replica set"
        sleep 1
      done
    fi
  done
}

if [ "${1:0:1}" = '-' ]; then
	set -- mongod "$@"
fi

if [ "$1" = 'mongod' ]; then
	chown -R mongodb /data/db

	numa='numactl --interleave=all'
	if $numa true &> /dev/null; then
		set -- $numa "$@"
	fi

  params="$@"

  if [[ "$MONGODB_ADMIN_PASSWORD" ]]; then
    if [[ "$NODE_ID" == "0" ]]; then
      auth_initiate "$@"
    fi

    if [[ "$MONGODB_KEYFILE" ]]; then
      echo "$MONGODB_KEYFILE" > /tmp/mongodb-keyfile
    else
      echo "$MONGODB_ADMIN_PASSWORD" | base64 > /tmp/mongodb-keyfile
    fi
    chmod 600 /tmp/mongodb-keyfile
    chown mongodb /tmp/mongodb-keyfile
    params="$params --keyFile=/tmp/mongodb-keyfile"
  fi


  if [[ "MONGODB_REPL_SET" ]]; then
    params="$params --replSet ${MONGODB_REPL_SET}"
  fi

  if [[ "$NODE_ID" == "0" ]]; then
    rs_initiate &
  fi

	exec gosu mongodb $params

else
  exec "$@"
fi
