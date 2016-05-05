#!/usr/bin/python
import sys
import urllib2
from os import environ
import time
import pytz
import logging
import logging.handlers
from datetime import timedelta, datetime, tzinfo
from subprocess import Popen
from datadog.dogstatsd.base import DogStatsd
from snapshotmanager import SnapshotManager, SnapshotManagerException
from pymongo import MongoClient

class Main():
    def mongo_client(self, host, port, password):
        if password:
            return MongoClient("mongodb://admin:%s@%s:%s" % (password, host, port))
        else:
            return MongoClient(host, port)

    def is_master(self):
        if environ.get('MONGODB_REPLICA_SET_MASTER', 'false').lower() == 'true':
            return True
        self.logger.debug('Connecting to mongodb to see if this node is master')
        connection = self.mongo_client('mongodb', 27018, environ.get('MONGODB_ADMIN_PASSWORD', None))
        db = connection.admin
        return db.command('isMaster')['ismaster']

    def configure_logger(self):
        self.logger = logging.getLogger(__name__)
        formatter = logging.Formatter('[%(levelname)s] %(name)s - %(message)s')
        self.log_handler = logging.StreamHandler(sys.stdout)
        self.log_handler.setFormatter(formatter)
        self.log_level = logging.DEBUG
        self.logger.addHandler(self.log_handler)
        self.logger.setLevel(self.log_level)

    def configure_options(self):
        if not environ.get('CLUSTER_NAME'):
            self.logger.fatal('CLUSTER_NAME environment variable is required')
            sys.exit(1)

        self.cluster_name = environ['CLUSTER_NAME']
        self.snapshot_and_exit = environ.get('MONGODB_SNAPSHOT_AND_EXIT', 'false').lower() == 'true'
        self.hourly_snapshots = int(environ.get('MONGODB_HOUR_SNAPSHOTS', '24'))
        self.daily_snapshots = int(environ.get('MONGODB_daily_SNAPSHOTS', '7'))
        self.data_device = environ.get('MONGODB_DATA_DEVICE', '/dev/xvdc')
        self.instance_id = self.get_instance_id()
        self.statsd = DogStatsd(host='172.17.0.1', port=8125)

    def get_instance_id(self):
        if 'INSTANCE_ID' in environ:
            return environ.get('INSTANCE_ID')
        # get the instance id from the metadata service
        instance_id = urllib2.urlopen("http://169.254.169.254/latest/meta-data/instance-id").read()
        if not instance_id:
            raise SnapshotManagerException("No instance id could be found using either INSTANCE_ID environment variable or instance metadata")

    def run(self):
        self.configure_logger()
        self.configure_options()
        if self.snapshot_and_exit:
            self.logger.info('Creating a single snapshot and exiting')
        else:
            self.logger.info('Starting in continuous snapshot mode')

        while True:
            try:
                self.create_snapshot_on_master()
                if self.snapshot_and_exit:
                    return
            except Exception as ex:
                self.logger.error("unhandled exception: %s" % ex)
            time.sleep(10)

    def create_snapshot_on_master(self):
        if self.is_master():
            self.logger.info('This node is the replica set master. Taking a snapshot.')
            self.create_snapshot()
        else:
            self.logger.info('This node is NOT the replica set master. Skipping snapshots.')

    def create_snapshot(self):
        # TODO take POINT_IN_TIME_RETENTION as env vars
        # point in time snapshots are taken every 10 minutes
        if datetime.now().minute % 10 == 0 or self.snapshot_and_exit:
            snapshot_manager = SnapshotManager(self.cluster_name, self.instance_id,
                                               self.data_device, self.statsd,
                                               self.log_handler, self.log_level)
            current_datetime = snapshot_manager.utcnow()
            snapshot_manager.remove_old_snapshots(current_datetime, self.hourly_snapshots,
                                                  self.daily_snapshots)
            snapshot_manager.create_snapshot()


if __name__ == "__main__":
    main = Main()
    main.run()
