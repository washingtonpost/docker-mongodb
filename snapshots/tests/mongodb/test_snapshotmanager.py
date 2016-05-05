from unittest import TestCase
from mongodb.snapshotmanager import SnapshotManager, Snapshot
import pytz
from datetime import datetime
import logging
import logging.handlers
import sys

def date(date):
    return pytz.utc.localize(datetime.strptime(date, "%Y-%m-%dT%H:%M:%S.%fZ"))

class MockSnapshotManager(SnapshotManager):
    def __init__(self):
        formatter = logging.Formatter('[%(levelname)s] %(name)s - %(message)s')
        log_handler = logging.StreamHandler(sys.stdout)
        log_handler.setFormatter(formatter)
        log_level = logging.DEBUG
        self.configure_logger(log_handler, log_level)
        self.snapshots = {}
        self.statsd = None

    def add_snapshot(self, snapshot):
        self.snapshots[snapshot.snapshot_id] = snapshot

    def get_snapshots(self):
        return self.snapshots.values()

    def delete_snapshot(self, snapshot_id):
        del(self.snapshots[snapshot_id])

class SnapshotManagerTest(TestCase):
    def test_keep_sub_hour_snapshots(self):
        current_datetime = date("2015-12-20T12:00:00.000Z")
        snapshot1_datetime = date("2015-12-20T09:00:00.000Z")
        manager = MockSnapshotManager()
        manager.add_snapshot(Snapshot("snap-1", snapshot1_datetime))
        assert(len(manager.get_sorted_snapshots()) == 1)

        manager.remove_old_snapshots(current_datetime, 0, 0)
        assert(len(manager.get_sorted_snapshots()) == 1)

    def test_remove_sub_hour_snapshots(self):
        current_datetime = date("2015-12-20T12:00:00.000Z")
        snapshot1_datetime = date("2015-12-20T08:50:00.000Z")
        manager = MockSnapshotManager()
        manager.add_snapshot(Snapshot("snap-1", snapshot1_datetime))
        assert(len(manager.get_sorted_snapshots()) == 1)

        manager.remove_old_snapshots(current_datetime, 0, 0)
        assert(len(manager.get_sorted_snapshots()) == 0)

    def test_keep_hourly_snapshots(self):
        current_datetime = date("2015-12-20T12:00:00.000Z")
        snapshot1_datetime = date("2015-12-20T08:00:00.000Z")
        manager = MockSnapshotManager()
        manager.add_snapshot(Snapshot("snap-1", snapshot1_datetime))
        assert(len(manager.get_sorted_snapshots()) == 1)

        manager.remove_old_snapshots(current_datetime, 4, 0)
        assert(len(manager.get_sorted_snapshots()) == 1)

    def test_remove_hourly_snapshots(self):
        current_datetime = date("2015-12-20T12:00:00.000Z")
        snapshot1_datetime = date("2015-12-20T08:10:00.000Z")
        snapshot2_datetime = date("2015-12-20T08:20:00.000Z")
        snapshot3_datetime = date("2015-12-20T08:00:00.000Z")
        manager = MockSnapshotManager()
        manager.add_snapshot(Snapshot("snap-1", snapshot1_datetime))
        manager.add_snapshot(Snapshot("snap-2", snapshot2_datetime))
        manager.add_snapshot(Snapshot("snap-3", snapshot3_datetime))
        assert(len(manager.get_sorted_snapshots()) == 3)

        manager.remove_old_snapshots(current_datetime, 4, 0)
        assert(len(manager.get_sorted_snapshots()) == 1)
        assert(manager.get_sorted_snapshots()[0].snapshot_id == "snap-3")

    def test_keep_daily_snapshots(self):
        current_datetime = date("2015-12-20T12:00:00.000Z")
        snapshot1_datetime = date("2015-12-10T12:00:00.000Z")
        manager = MockSnapshotManager()
        manager.add_snapshot(Snapshot("snap-1", snapshot1_datetime))
        assert(len(manager.get_sorted_snapshots()) == 1)

        manager.remove_old_snapshots(current_datetime, 0, 10)
        assert(len(manager.get_sorted_snapshots()) == 1)

    def test_remove_daily_snapshots(self):
        current_datetime = date("2015-12-20T12:00:00.000Z")
        snapshot1_datetime = date("2015-12-09T12:00:00.000Z")
        snapshot2_datetime = date("2015-12-08T12:00:00.000Z")
        snapshot3_datetime = date("2015-12-10T12:00:00.000Z")
        manager = MockSnapshotManager()
        manager.add_snapshot(Snapshot("snap-1", snapshot1_datetime))
        manager.add_snapshot(Snapshot("snap-2", snapshot2_datetime))
        manager.add_snapshot(Snapshot("snap-3", snapshot3_datetime))
        assert(len(manager.get_sorted_snapshots()) == 3)

        manager.remove_old_snapshots(current_datetime, 24, 10)
        assert(len(manager.get_sorted_snapshots()) == 1)
        assert(manager.get_sorted_snapshots()[0].snapshot_id == "snap-3")
