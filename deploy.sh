#!/bin/bash

function deploy() {
  local major_version=$1
  local full_version=$2
  local push_all_versions=$3

  docker build -t washpost/mongodb:$full_version mongodb/$major_version
  docker push washpost/mongodb:$full_version

  if [ "$push_all_versions" = "true" ]; then
    docker tag washpost/mongodb:$full_version washpost/mongodb:latest
    docker tag washpost/mongodb:$full_version washpost/mongodb:$major_version
    docker push washpost/mongodb:$major_version
    docker push washpost/mongodb:latest
  fi

  docker build -t washpost/mongos:$full_version mongos/$major_version
  docker push washpost/mongos:$full_version

  if [ "$push_all_versions" = "true" ]; then
    docker tag washpost/mongos:$full_version washpost/mongos:latest
    docker tag washpost/mongos:$full_version washpost/mongos:$major_version
    docker push washpost/mongos:$major_version
    docker push washpost/mongos:latest
  fi

  docker build -t washpost/mongodb-snapshots:$full_version snapshots
  docker push washpost/mongodb-snapshots:$full_version

  if [ "$push_all_versions" = "true" ]; then
    docker tag washpost/mongodb-snapshots:$full_version washpost/mongodb-snapshots:latest
    docker tag washpost/mongodb-snapshots:$full_version washpost/mongodb-snapshots:$major_version
    docker push washpost/mongodb-snapshots:$major_version
    docker push washpost/mongodb-snapshots:latest
  fi
}

deploy 3.2 3.2.12 false 
deploy 3.4 3.4.2 true
deploy 3.6 3.6.20 false
