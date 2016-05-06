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
        self.minutely_snapshots = int(environ.get('MONGODB_MINUTELY_SNAPSHOTS', '360'))
        self.hourly_snapshots = int(environ.get('MONGODB_HOURLY_SNAPSHOTS', '24'))
        self.daily_snapshots = int(environ.get('MONGODB_DAILY_SNAPSHOTS', '7'))
        self.data_device = environ.get('MONGODB_DATA_DEVICE', '/dev/xvdc')
        self.instance_id = self.get_instance_id()
        self.statsd = DogStatsd(host='172.17.0.1', port=8125)
        self.snapshot_frequency = self.get_snapshot_frequency()

    def get_snapshot_frequency(self):
        allowed_frequencies = [5, 10, 15, 20]
        default_frequency = 10
        snapshot_frequency = int(environ.get('MONGODB_SNAPSHOT_FREQUENCY', str(default_frequency)))
        if snapshot_frequency not in allowed_frequencies:
            self.logger.error('Invalid MONGODB_SNAPSHOT_FREQUENCY of %s minute. Only %s minutes are allowed. Changing to default frequency of %s minutes.' %
                              (snapshot_frequency,
                               ' or '.join([str(x) for x in allowed_frequencies]),
                               default_frequency))
            snapshot_frequency = default_frequency
        return snapshot_frequency

    def get_instance_id(self):
        if 'INSTANCE_ID' in environ:
            return environ.get('INSTANCE_ID')
        # get the instance id from the metadata service
        instance_id = urllib2.urlopen("http://169.254.169.254/latest/meta-data/instance-id").read()
        if not instance_id:
            raise SnapshotManagerException("No instance id could be found using either INSTANCE_ID environment variable or instance metadata")
        return instance_id

    def run(self):
        self.configure_logger()
        self.configure_options()
        if self.snapshot_and_exit:
            self.logger.info('Creating a single snapshot and exiting')
        else:
            self.logger.info('Taking a snapshot every %s minutes.' % self.snapshot_frequency)

        last_snapshot_datetime = None
        while True:
            try:
                now = datetime.now()
                if self.snapshot_and_exit or self.time_to_snapshot_again(last_snapshot_datetime, now):
                    snapshot_datetime = self.create_snapshot_on_master(now)
                    if self.snapshot_and_exit:
                        return
                    if snapshot_datetime:
                        last_snapshot_datetime = snapshot_datetime

            except Exception as ex:
                self.logger.error("unhandled exception: %s" % ex)
            time.sleep(10)

    def time_to_snapshot_again(self, last_snapshot_datetime, now):
        if not last_snapshot_datetime:
            return True

        # wait at least 60 seconds between snapshots to avoid a race condition
        return now > (last_snapshot_datetime + timedelta(seconds=70))

    def create_snapshot_on_master(self, now):
        if self.is_master():
            return self.create_snapshot(now)

    def create_snapshot(self, now):
        if now.minute % self.snapshot_frequency == 0 or self.snapshot_and_exit:
            snapshot_manager = SnapshotManager(self.cluster_name, self.instance_id,
                                               self.data_device, self.statsd,
                                               self.log_handler, self.log_level)
            current_datetime = snapshot_manager.utcnow()
            snapshot_manager.remove_old_snapshots(current_datetime,
                                                  self.minutely_snapshots,
                                                  self.hourly_snapshots,
                                                  self.daily_snapshots)
            snapshot_manager.create_snapshot()
            return now


if __name__ == "__main__":
    main = Main()
    main.run()
