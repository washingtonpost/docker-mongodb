import os
from setuptools import setup, find_packages
import warnings

setup(
    name='mongodb-snapshots',
    version='0.1.0',
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        'datadog>=0.10.0',
        'decorator>=4.0.9',
        'pymongo>=3.4.0',
        'python-dateutil>=2.4.2',
        'pytz>=2015.7',
        'requests>=2.9.1',
        'simplejson>=3.8.2',
        'six>=1.10.0',
        'wheel>=0.24.0',
        'boto3>=1.3.1',
        'botocore>=1.4.14',
        'docutils>=0.12',
        'futures>=3.0.5',
        'retrying>=1.3.3'
    ],
    setup_requires=[
        'pytest-runner'
    ],
    tests_require=[
        'pytest',
    ],
    author="Patrick Cullen and the WaPo platform tools team",
    author_email="opensource@washingtonpost.com",
    url="https://github.com/washingtonpos/docker-mongodb",
    keywords = ['cloud', 'mongodb', 'aws'],
    classifiers = []
)
