# Docker MongoDB
This project provides a Dockerized MongoDB cluster with the following features:

* replica set for high availability (both mongodb and configdb)
* sharding for easy scale out (mongos) 

# Quick Start
To use this project do the following:

1. Create a new Github repo for your configuration (e.g. my-configs)
1. Create a directory for mongodb (i.e. mkdir my-configs/mongodb)
1. Create a sub-directory for your cluster (i.e. mkdir my-configs/mongodb/foobar)
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
## How do I do a subtree merge?
A subtree merge is an alternative to a Git submodules. It is easier to use once it is setup and does not require any special commands for others using your repo unless they want to update it.

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

