#!/bin/bash
{% include "cloud.environment.sh" %}
{% include "mongodb.hugepage.sh" %}
{% include "mongodb.alias.sh" %}
{% include "system.mounts.sh" %}
{% include "docker.config.sh" %}
{% include "docker_compose.run.sh" %}
{# Optional template for datadog metrics
{% include "datadog.mongodb.sh" %}
#}
