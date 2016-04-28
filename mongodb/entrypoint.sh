#!/bin/bash
set -e

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

  IS_REPL_SET=$(mongo localhost:$MONGODB_PORT --quiet --eval "rs.status().set" | wc -l)
  if [ "$IS_REPL_SET" != "0" ]; then
    echo "already a replica set"
    return
  fi

  echo "initiating replica set..."
  local first_node=0
  echo $NODE_LIST | sed -n 1'p' | tr ',' '\n' | while read node; do
    if [ "$first_node" == "0" ]; then
      first_node=1
      mongo localhost:$MONGODB_PORT --quiet --eval "printjson(rs.initiate())"
      mongo localhost:$MONGODB_PORT --quiet --eval "cfg = rs.conf(); cfg.members[0].host = \"$node:$MONGODB_PORT\"; printjson(rs.reconfig(cfg))"

      while ! mongo localhost:$MONGODB_PORT --quiet --eval "db.isMaster().ismaster" | grep true
      do
        echo "waiting for $node to become primary"
        sleep 1
      done

    else
      while mongo localhost:$MONGODB_PORT --quiet --eval "printjson(rs.add(\"$node:$MONGODB_PORT\"))" | grep -l '"ok"\s*:\s*0'
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

  if [[ "$NODE_ID" == "0" ]]; then
    rs_initiate &
  fi
	exec gosu mongodb "$@"

else
  exec "$@"
fi
