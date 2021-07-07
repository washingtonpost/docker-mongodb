# Docker MongoDB
This project provides a Dockerized MongoDB cluster with the following features:

* replica set for high availability (both mongodb and configdb)
* sharding for easy scale out (mongos)
* Authentication and authorization of client requests
* Automatic backups every 10 minutes
* Automatic removal of old backups
* Simple and safe cluster upgrade process that includes health checks to avoid an outage
* High speed replacement of servers using the previous snapshot to bootstrap new servers
* Optional: Comprehensive Datadog monitors including server health, replication lag, and missing backups

# Quick Start
To use this project do the following:

1. Create a new Github repo for your configuration (e.g. `my-configs`)
1. Create a directory for mongodb (e.g. `mkdir my-configs/mongodb`)
1. Create a sub-directory for your cluster (e.g. `mkdir my-configs/mongodb/foobar`)
1. Clone this project into your Github repo using subtree merge
1. Copy the docker-mongodb/cloud-compose/cloud-compose.yml.example to your cluster sub-directory
1. Modify the cloud-compose.yml to fit your needs
1. Create a new cluster using the [Cloud Compose cluster plugin](https://github.com/cloud-compose/cloud-compose-cluster).
```
pip install cloud-compose cloud-compose-cluster
pip freeze -r > requirements.txt
cloud-compose cluster up
```

# FAQ
## How do I change the MongoDB version?
The default version is the latest release of the 3.2 series. If you want to use a different version (i.e. 3.4) set the MONGODB_VERSION environment variable in the cloud-compose.yml.

```
cluster:
  environment:
    MONGODB_VERSION: 3.4
```


## How do I upgrade a cluster running 3.2 to 3.4?
Either use the [cloud-compose-mongo plugin](https://github.com/cloud-compose/cloud-compose-mongo) upgrade command or do the following steps to upgrade from 3.2 to 3.4.

First make sure that both mongodb and configdb are primary on the same host by running the following command:

```
mongo --eval 'rs.status()' --port 27018
mongo --eval 'rs.status()' --port 27019
```

If they are not primary on the same host run the following command until they are primary on the same host:
```
# ssh to configdb primary server
mongo --eval 'rs.stepDown()' --port 27019
```

Once you confirm that both mongodb and configdb are primary on the same host, upgrade the hosts one at a time starting with the hosts in SECONDARY state and doing the PRIMARY server last. If you don't upgrade them in that order you will cause the replica set to run on only one node because of an incompatibilty between the index versions of 3.4 and 3.2.


## How do I tune the cluster?
Most of the MongoDB settings default to sensible values, but if you have a write heavy cluster you may want to change the following options by adding environment variables to your cloud-compose.yml:

* MONGODB_OPLOG_SIZE: 10000

MONGODB_OPLOG_SIZE translates the the command line parameter `--oplogSize`. The value is the number of megabytes for the oplog. You can check if your oplog is big enough by running `mongo --port 27018 --eval 'rs.printReplicationInfo()'`. If the output shows you have less than 24 hours between the first and last event, you may want to increase the size to be bigger.

* MONGODB_JOURNAL: "false"

MONGODB_JOURNAL translates to the command line parameter of `--nojournal`. If you are running a replicate set you can safely disable this by setting the value to `false` since you will be able to catch up an missed data from another replicat member. Disabling the journal has been show to reduce the start time by nearly 20 minutes for a write heavy cluster.

## How do I manage secrets?
Secrets can be configured using environment variables. [Envdir](https://pypi.python.org/pypi/envdir) is highly recommended as a tool for switching between sets of environment variables in case you need to manage multiple clusters.
At a minimum you will need AWS_ACCESS_KEY_ID, AWS_REGION, and AWS_SECRET_ACCESS_KEY.

It is highly recommend that you also set MONGODB_ADMIN_PASSWORD to enable authentication. Although you can set the MONGODB_ADMIN_PASSWORD as environment variable, the preferred method is to to KMS encrypt secrets. Simply add MONGODB_ADMIN_PASSWORD to the secrets section of the cloud-compose.yml and then add the grant Decrypt permissions on the KMS key to the instance_profile section.

Example of KMS encrypted secret:
```
cluster
  secrets:
    MONGODB_ADMIN_PASSWORD: "AQECAHgq..."
  instance_policy: '{ "Statement": [ { "Action": [ "ec2:CreateSnapshot", "ec2:CreateTags", "ec2:DeleteSnapshot", "ec2:DescribeInstances", "ec2:DescribeSnapshotAttribute", "ec2:DescribeSnapshots", "ec2:DescribeVolumeAttribute", "ec2:DescribeVolumeStatus", "ec2:DescribeVolumes", "ec2:ModifySnapshotAttribute", "ec2:ResetSnapshotAttribute", "logs:CreateLogStream", "logs:PutLogEvents" ], "Effect": "Allow", "Resource": [ "*" ] }, { "Action": ["kms:Decrypt"], "Effect": "Allow", "Resource": ["arn:aws:kms:us-east-1:111111111111:key/22222222-2222-2222-2222-222222222222"] } ] }'
```

## How do I configure the datadog metrics?
Make sure you have the already datadog agent installed in your base image. You can then configure datadog metrics by setting the following environment variables DATADOG_API_KEY and DATADOG_APP_KEY. Then create a custom cluster.sh by copying docker-mongodb/cloud-compose/templates/cluster.sh to a local directory called templates. Then add the following line to the bottom of the cluster.sh file to include the default datadog.mongodb.sh in your cloud_init script.
```
{% include "datadog.mongodb.sh" %}
```

## What security group rules are needed?
Once you create an AWS security group make sure to add the following rules to it:

```
Custom TCP Rule TCP 27017 - 27019 10.0.0.0/8
```

If you want to make a more restrictive security group, you only need to give port 27017 access to clients and port 27017-27019 access to instances in the same security group.


If you want to ssh into instances, make sure to add an ssh rule as well
```
SSH TCP 22 10.0.0.0/8
```

## How do I enable authentication?
By default, client authentication is disabled. It is highly recommended that you enable client authentication for production use cases. Client authentication cannot be enabled after the cluster has been created, so decide if you need it before creating the cluster for the first time.

To enable client authentication you need to set the following environment variable before creating the cluster.

* MONGODB_ADMIN_PASSWORD

Once the cluster is up, you can ssh to a node and use the ``admin`` user to create application logins for specific databases.

Here is an example command for creating a new user with dbOwner permissions to an application database.
```
mongo localhost:27017/$DB_NAME --eval 'printjson(db.createUser({user: "$DB_USER", pwd: "$DB_PASSWORD", roles: [{role: "dbOwner", db: "$DB_NAME"}]}))'
```

On each server there will be a shell alias called ``mongo`` which contains the parameters to connect to the database as the ``admin`` user. You can type ``alias mongo`` to see those command options in case you want to make a local alias for convenience.

## How do I change the backup frequency and retention?
Mongodb backups are implemented as ELB snapshots of the data volume. ELB snapshots are taken every 10 minutes and kept for 6 hours. After 6 hours, hourly snapshots are kept for 24 hours and daily snapshots are kept for 30 days. You can change these values with the following environment variables

* MONGODB_MINUTELY_SNAPSHOTS=360 - minutes to keep sub-hourly snapshots. Default is 360 minutes.
* MONGODB_HOURLY_SNAPSHOTS=24 - hours to keep the hourly snapshots. Defaults to 24 hours.
* MONGODB_DAILY_SNAPSHOTS=7 - days to keep daily snapshots. Defaults to 30 days.
* MONGODB_SNAPSHOT_FREQUENCY=20 - minutes between snapshots. Default is 20 minutes. Valid values are 5, 10, 15, or 20 minutes.

## How do I share config files?
Since most of the config files are common between MongoDB clusters, it is desirable to directly share the configuration between projects. The recommend directory structure is to have docker-mongodb sub-directory and then a sub-directory for each cluster. For example if I had a test and prod mongodb cluster my directory structure would be:

```
mongodb/
  docker-mongodb/cloud-compose/templates/
  test/cloud-compose.yml
  prod/cloud-compose.yml
  templates/
```

The docker-mongodb directory would be a subtree merge of this Git project, the templates directory would be any common templates that only apply to your mongodb clusters, the the test and prod directories have the cloud-compose.yml files for your two mongodb clusters. Regardless of the directory structure, make sure the search_paths in your cloud-compose.yml reflect all the config directories and the order that you want to load the config files.

## How do I create a subtree merge of this project?
A subtree merge is an alternative to a Git submodules for copying the contents of one Github repo into another. It is easier to use once it is setup and does not require any special commands (unlike submodules) for others using your repo.

### Initial subtree merge
To do the initial merge you will need to create a git remote, then merge it into your project as a subtree and commit the changes

```bash
# change to the cluster sub-directory
cd my-configs/mongodb
# add the git remote
git remote add -f docker-mongodb git@github.com:washingtonpost/docker-mongodb.git
# pull in the git remote, but don't commit it
git merge -s ours --no-commit docker-mongodb/master
# make a directory to merge the changes into
mkdir docker-mongodb
# actually do the merge
git read-tree --prefix=mongodb/docker-mongodb/ -u docker-mongodb/master
# commit the changes
git commit -m 'Added docker-mongodb subtree'
```

### Updating the subtree merge
When you want to update the docker-mongodb subtree use the git pull with the subtree merge strategy

```bash
# Add the remote if you don't already have it
git remote add -f docker-mongodb git@github.com:washingtonpost/docker-mongodb.git
# do the subtree merge again
git pull -s subtree docker-mongodb master
```

## How do I replace a server?
Make sure to only replace one server at a time to reduce the risk of data loss. If the server is not already terminated then terminate it. Then run cloud-compose cluster up to restore the node.

## How do I upgrade the entire cluster?
First make sure the cluster replica sets are healthy by running `mongo --port 27018 --eval 'rs.status()'` and `mongo --port 27019 --eval 'rs.status()'`. All nodes should report a PRIMARY or SECONDARY state. Then follow the steps for replacing a server for each node in the cluster. Check the status of the replica sets in between each server to make sure the cluster is healthy before proceeding with the next node.

## How do I upgrade the instance size or disk space?
First change the instance size or disk space parameters in the cloud-compose.yml. Then follow the steps for upgrading a cluster.

## How do I restore the database to a point in time?
You can select the exact snapshot to restore a cluster from by specifiying the `snapshot` option for the data volume in the cloud-compose.yml. Make sure to remove the snapshot option from the cloud-compose.yml afterwards.

Example cloud-compose.yml
```
    volumes:
      - name: data
        snapshot: snap-abc123
        size: 10G
        block: /dev/xvdc
        file_system: ext4
        meta:
          format: true
          mount: /data/mongodb
```

## How do I clone a cluster?
You can clone a cluster by starting from an existing snapshot of another cluster. First find the relevant snapshot ID for the cluster you want to clone. Then create a copy of the cloud-compose.yml and change the cluster name and IP addresses. Set the `snapshot` option for the data volume as specified above. Then run cloud-compose cluster up to start the cluster from that snapshot. Make sure to remove the snapshot option from the cloud-compose.yml afterwards.

## How do I startup a cluster without starting from a snapshot?
If you want to recreate a cluster, but don't want to use an existing snapshot for the data volume pass the --no-use-snapshots option to cloud-compose cluster up.

## How do I terminate a cluster?
Once a cluster is terminated the data will be destroyed. If you have snapshots then you will be able to restore to the last snapshot. To terminate the cluster run cloud-compose cluster down.

## How do I change the oplog size while the cluster is running?

On rare occasion you may need to increase the size of the oplog while the cluster is running.  Usually this is because the turnover of the oplog is less than the time it takes to sync from a snapshot.

(Instructions adapted from https://docs.mongodb.com/manual/tutorial/change-oplog-size/)

1. Go to the Secondary that you want to increase the oplog size on.  If you have already done it on all of the secondaries, you can make the current primary a secondary with:

```
mongo localhost:27018
rs.stepDown()
```

2. Shut down extraneous services

```
docker stop snapshots
docker stop mongos
```

Leave the config server running, you won't need to touch it here.

3. Stop mongod

```
docker stop mongodb
```

4. Run a new mongod in standalone mode

(change to correct version if using a version other than 3.2)

```
docker run -p 27020:27017  -v /data/mongodb/mongodb:/data/db mongo:3.2 mongod
```

5. In a new terminal window, ssh into the server again, open a mongo console

```
mongo localhost:27020
```

6. Run the commands to increase the size

In this example, the oplog is 20 Gb.  Replace that number with the size you want.

```
use local
db.temp.drop()
db.temp.save( db.oplog.rs.find( { }, { ts: 1, h: 1 } ).sort( {$natural : -1} ).limit(1).next() )

db = db.getSiblingDB('local')
db.oplog.rs.drop()
db.runCommand( { create: "oplog.rs", capped: true, size: (20 * 1024 * 1024 * 1024) } )

db.oplog.rs.save( db.temp.findOne() )
db.oplog.rs.find()

```

7. Kill the standalone instance and restart mongod

```
# ^C on current running process
docker start mongodb
```

8. Wait for the node to sync, and restart the other processes

```
docker start mongos
docker start snapshots
```

9. Repeat for the other nodes, making sure to stepDown the primary node first.


# Contributing
If you want to contribute to the project see the [contributing guide](CONTRIBUTING.md).
