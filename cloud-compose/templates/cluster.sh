#!/bin/bash
{%- if _node_id is defined %}
NODE_ID={{ _node_id }}
{%- endif %}
INSTANCE_IP=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`

{% include "mongodb.hugepage.sh" %}
{% include "system.mounts.sh" %}
{% include "docker.config.sh" %}
{% include "datadog.mongodb.sh" %}
{% include "docker_compose.run.sh" %}
