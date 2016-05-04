#!/bin/bash
{% include "cloud.environment.sh" %}
{% include "mongodb.hugepage.sh" %}
{% include "system.mounts.sh" %}
{% include "docker.config.sh" %}
{% include "datadog.mongodb.sh" %}
{% include "docker_compose.run.sh" %}
