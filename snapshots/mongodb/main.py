#!/usr/bin/python
import sys
from os import environ
import time
import pytz
from datetime import timedelta, datetime, tzinfo
from subprocess import Popen
from datadog.dogstatsd.base import DogStatsd
from snapshotmanager import SnapshotManager

if __name__ == "__main__":
    if not environ.get('CLUSTER_NAME'):
        print 'CLUSTER_NAME environment variable is required'
        sys.exit(1)

    cluster_name = environ['CLUSTER_NAME']
    snapshot_and_exit = environ.get('MONGODB_SNAPSHOT_AND_EXIT', 'false').lower() == 'true'
    hourly_snapshots = int(environ.get('MONGODB_HOUR_SNAPSHOTS', '24'))
    daily_snapshots = int(environ.get('MONGODB_daily_SNAPSHOTS', '7'))
    statsd = DogStatsd(host='172.17.0.1', port=8125)

    if snapshot_and_exit:
        print 'creating a snapshot and exiting'
    else:
        print 'continuous snapshot creation'

    while True:
        try:
            # take snapshots every 10 minutes
            if datetime.now().minute % 10 == 0 or snapshot_and_exit:
                #TODO check if I am the master db, only then take a snapshot (link to mongodb)
                snapshot = SnapshotManager(cluster_name, statsd)
                current_datetime = pytz.timezone('UTC').localize(datetime.now())
                snapshot.remove_old_snapshots(current_datetime, hourly_snapshots, daily_snapshots)
                snapshot.create_snapshot()

                if snapshot_and_exit:
                    sys.exit(0)
                else:
                    # wait 2 minutes so we don't accidently take two snapshots in the same minute
                    time.sleep(120)
        except Exception as ex:
            print "unhandled exception: %s" % ex
        time.sleep(10)
