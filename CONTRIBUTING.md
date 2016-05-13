## Developing
Test locally using the docker-compose.yml. Once the changes work locally, test on EC2 using the [Cloud Compose cluster plugin](https://github.com/cloud-compose/cloud-compose-cluster). Build the docker containers into your Docker Hub repository and update the [docker-compose.override.yml](cloud-compose/templates/docker-compose.override.yml) to change the image to point to your versions.

Finally submit a pull request explaining the reason for the change and how you tested it.

## Releasing
To release new versions you will need to be invited to the washpost teamon Docker Hub. Then follow the instructions below for pushing new Docker images.

### updating mongodb (and configdb)
```
docker build -t washpost/mongodb:latest mongodb
docker tag washpost/mongodb:latest washpost/mongodb:3.2
docker push washpost/mongodb:latest
docker push washpost/mongodb:3.2
```

### updating mongos
```
docker build -t washpost/mongos:latest mongos 
docker tag washpost/mongos:latest washpost/mongos:3.2
docker push washpost/mongos:latest
docker push washpost/mongos:3.2
```

### updating mongodb-snapshots
```
docker build -t washpost/mongodb-snapshots:latest snapshots 
docker tag washpost/mongodb-snapshots:latest washpost/mongodb-snapshots:3.2
docker push washpost/mongodb-snapshots:latest
docker push washpost/mongodb-snapshots:3.2
```

### Post release testing 
To test the project post release, create a new virtualenv and try building a new cluster

Example test script
```
mkvirtualenv mongodb_test
cd pt-configs/mongodb
git pull -s subtree docker-mongodb master
pip install cloud-compose cloud-compose-cluster 
pip freeze > requirements.txt
envdir ~/.envs/sandbox ~/.virtualenvs/mongodb_test/cloud-compose cluster up
```

Wait for the servers to come up then ssh in and run these commands:
```
mongo --port 27017 --eval 'sh.status()'
mongo --port 27018 --eval 'rs.status()'
```

Remember to delete the cluster after testing:
```
envdir ~/.envs/sandbox ~/.virtualenvs/mongodb_test/cloud-compose cluster down 
```
