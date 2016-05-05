import sys
import pytz
import logging
import logging.handlers
from datetime import timedelta, datetime, tzinfo
from os import environ
from subprocess import Popen
import boto3
import botocore
from retrying import retry

class Snapshot():
    def __init__(self, snapshot_id, start_time):
        self.snapshot_id = snapshot_id
        self.start_time = start_time

class SnapshotManager():
    def __init__(self, cluster_name, instance_id, data_device, statsd=None,
                 log_handler=None, log_level=logging.INFO):
        self.configure_logger(log_handler, log_level)
        self.logger.setLevel(logging.DEBUG)
        self.ec2 = self._get_ec2_client()
        self.data_device = data_device
        self.instance_id = instance_id
        self.cluster_name = cluster_name
        self.statsd = statsd

    def configure_logger(self, handler, level):
        self.logger = logging.getLogger(__name__)
        if not handler:
            formatter = logging.Formatter('[%(levelname)s] %(name)s - %(message)s')
            handler = logging.StreamHandler(sys.stdout)
            handler.setFormatter(formatter)

        self.logger.addHandler(handler)
        self.logger.setLevel(level)

    def _get_ec2_client(self):
        kwargs = {
            'region_name': environ.get('AWS_REGION', 'us-east-1'),
        }

        aws_access_key_id = environ.get('AWS_ACCESS_KEY_ID')
        aws_secret_access_key = environ.get('AWS_SECRET_ACCESS_KEY')

        if aws_access_key_id and aws_secret_access_key:
            kwargs['aws_access_key_id'] = aws_access_key_id
            kwargs['aws_secret_access_key'] = aws_secret_access_key

        return boto3.client('ec2', **kwargs)

    def get_sorted_snapshots(self):
        snapshots = self.get_snapshots()
        return sorted(snapshots, key=lambda snapshot: snapshot.start_time)

    def get_snapshots(self):
        snapshots = []
        described_snapshots = self._ec2_describe_snapshots(Filters=[{"Name": "tag:ClusterName", "Values": [self.cluster_name]}] )
        for snapshot in described_snapshots:
            snapshots.append(Snapshot(snapshot['SnapshotId'], snapshot['StartTime']))
        return snapshots


    def delete_snapshot(self, snapshot_id):
        self.ec2.delete_snapshot(SnapshotId=snapshot_id)

    def utcnow(self):
        return datetime.utcnow().replace(tzinfo=pytz.utc)

    def remove_old_snapshots(self, now, minutely_snapshots, hourly_snapshots, daily_snapshots):
        #needs to sort by time ASCENDING for the rest of the code to work
        snapshots = self.get_sorted_snapshots()
        self._record_backup_metrics(now, snapshots)

        snapshots = self._remove_minutely_snapshots(now, minutely_snapshots, snapshots)
        snapshots = self._remove_hourly_snapshots(now, hourly_snapshots, snapshots)
        snapshots = self._remove_daily_snapshots(now, daily_snapshots, snapshots)

        # deleting the remaining snapshots
        for snapshot in snapshots:
            self.logger.info("Deleting snapshot %s %s" % (snapshot.snapshot_id, snapshot.start_time))
            self.delete_snapshot(snapshot.snapshot_id)

    def _remove_minutely_snapshots(self, now, minutely_snapshots, snapshots):
        snapshots_to_delete = []
        keep_since_time = now - timedelta(minutes=minutely_snapshots)
        for snapshot in snapshots:
            snapshot_start = snapshot.start_time
            if snapshot_start < keep_since_time:
                snapshots_to_delete.append(snapshot)

        return snapshots_to_delete

    def _remove_hourly_snapshots(self, now, hourly_snapshots, snapshots):
        keep_since_time = now - timedelta(hours=hourly_snapshots)
        return self._remove_bucketed_snapshots(keep_since_time, "%Y%m%d%H", snapshots)

    def _remove_daily_snapshots(self, now, daily_snapshots, snapshots):
        keep_since_time = now - timedelta(days=daily_snapshots)
        return self._remove_bucketed_snapshots(keep_since_time, "%Y%m%d", snapshots)

    def _remove_bucketed_snapshots(self, keep_since_time, bucket_key_datetime_format, snapshots):
        snapshots_to_delete = []
        snapshot_bucket = {}
        for snapshot in snapshots:
            snapshot_start = snapshot.start_time
            if snapshot_start < keep_since_time:
                snapshots_to_delete.append(snapshot)
            else:
                bucket_key = snapshot_start.strftime(bucket_key_datetime_format)
                if bucket_key in snapshot_bucket:
                    # we already have a backup for this key so we can delete this one
                    snapshots_to_delete.append(snapshot)
                else:
                    # save the first snapshot for the hour; this code assumes that the snapshots are sorted ascending already
                    snapshot_bucket[bucket_key] = snapshot

        return snapshots_to_delete

    # records the number of missing snapshots in the last hour
    def _record_backup_metrics(self, now, snapshots):
        # since we are taking snapshots every 10 minutes there should be at least 5 backups in the last hour
        expected_snapshots = 5
        last_hour = now - timedelta(minutes=60)
        snapshot_count = 0
        for snapshot in snapshots:
            snapshot_start = snapshot.start_time
            if snapshot_start >= last_hour:
                snapshot_count += 1

        missing_snapshots = expected_snapshots - snapshot_count
        if missing_snapshots < 0:
            missing_snapshots = 0
        self.logger.info("Recording mongodb.backups.missing %s" % missing_snapshots)
        if self.statsd:
            self.statsd.gauge('mongodb.backups.missing', missing_snapshots)

    def _is_retryable_exception(exception):
        return not isinstance(exception, botocore.exceptions.ClientError)

    def create_snapshot_for_volume(self, volume_id):
        snap_name = self.cluster_name + "." + self.utcnow().strftime('%Y%m%d%H%M')
        tags = [{'Key': 'ClusterName', 'Value': self.cluster_name},
                {'Key': 'Name', 'Value': snap_name}]
        snapshot_id = self._ec2_create_snapshot(VolumeId=volume_id, Description=snap_name)
        if not snapshot_id:
            raise SnapshotManagerException("No snapshot id found after creating snapshot")

        self._ec2_create_tags(Resources=[snapshot_id], Tags=tags)
        self.logger.info("Snapshot " + snap_name + " created.")

    @retry(retry_on_exception=_is_retryable_exception, stop_max_delay=10000, wait_exponential_multiplier=500, wait_exponential_max=2000)
    def _ec2_create_tags(self, **kwargs):
        return self.ec2.create_tags(**kwargs)

    @retry(retry_on_exception=_is_retryable_exception, stop_max_delay=10000, wait_exponential_multiplier=500, wait_exponential_max=2000)
    def _ec2_create_snapshot(self, **kwargs):
        response = self.ec2.create_snapshot(**kwargs)
        if 'SnapshotId' in response:
            return response['SnapshotId']

    def create_snapshot(self):
        try:
            ## Create snapshots of data volumes attached to 'server' and with block dev 'xvdc'
            ## This should only return one volume.
            volumes = self._ec2_describe_volumes(Filters=[{'Name': 'attachment.instance-id', 'Values': [self.instance_id]},
                                                         {'Name': 'attachment.device', 'Values': [self.data_device]}])

            if len(volumes) == 0:
                self.logger.error("No applicable volumes found. Does the MongoDB instance have a block device at %s?" % self.data_device)
                return False

            for volume in volumes:
                volume_id = volume['VolumeId']
                self.logger.debug("Creating snapshot for volume " + str(volume_id) + " from instance " + self.instance_id)
                self.create_snapshot_for_volume(volume_id)

            return True
        except Exception as ex:
            self.logger.error("failed to create snapshot %s" % ex)
            return False

    @retry(retry_on_exception=_is_retryable_exception, stop_max_delay=10000, wait_exponential_multiplier=500, wait_exponential_max=2000)
    def _ec2_describe_volumes(self, **kwargs):
        volumes = []
        response = self.ec2.describe_volumes(**kwargs)
        if 'Volumes' in response:
            volumes = response['Volumes']
        return volumes

    @retry(retry_on_exception=_is_retryable_exception, stop_max_delay=10000, wait_exponential_multiplier=500, wait_exponential_max=2000)
    def _ec2_describe_snapshots(self, **kwargs):
        response = self.ec2.describe_snapshots(**kwargs)
        snapshots = []
        if 'Snapshots' in response:
            snapshots = response['Snapshots']
        return snapshots


class SnapshotManagerException(Exception):
    def __init__(self,*args,**kwargs):
        Exception.__init__(self,*args,**kwargs)
