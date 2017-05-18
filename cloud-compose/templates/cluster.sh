#!/bin/bash
{% include "system.resolv_conf.sh" %}
{% include "system.limits_conf.sh" %}
{% include "cloud.environment.sh" %}
{% include "secrets.environment.sh" %}
{% include "mongodb.hugepage.sh" %}
{% include "mongodb.alias.sh" %}
{% include "system.mounts.sh" %}
{% include "docker.config.sh" %}
{% include "docker_compose.run.sh" %}
{% include "system.network_conf.sh" %}
{% include "datadog.mongodb.sh" %}
{% include "pcp.config.sh" %}
