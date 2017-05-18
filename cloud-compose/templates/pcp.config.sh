# pcp.config.sh
{%- if PERFORMANCE_COPILOT is defined and PERFORMANCE_COPILOT == "enabled" %}
chkconfig pmcd on
service pmcd start
chkconfig pmlogger on
service pmlogger start
chkconfig pmwebd on
service pmwebd start
{%- endif %}
