# Docker MongoDB
This project provides a Dockerized MongoDB cluster with the following features:

* replica set for high availability (both mongodb and configdb)
* sharding for easy scale out (mongos) 
* Authentication and authorization of client requests

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

## How do I do a subtree merge for sharing config files?
A subtree merge is an alternative to a Git submodules for copying the contents of one Github repo into another. It is easier to use once it is setup and does not require any special commands (unlike submodules) for others using your repo.

### Initial subtree merge
To do the initial merge you will need to create a git remote, then merge it into your project as a subtree and commit the changes

```bash
# change to the cluster sub-directory
cd my-configs/mongodb/foobar
# add the git remote
git remote add -f docker-mongodb git@github.com:washingtonpost/docker-mongodb.git
# pull in the git remote, but don't commit it
git merge -s ours --no-commit docker-mongodb/master
# make a directory to merge the changes into
mkdir docker-mongodb
# actually do the merge
git read-tree --prefix=mongodb/foobar/docker-mongodb/ -u docker-mongodb/master
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

