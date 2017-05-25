# secrets.environment.sh
{%- if secrets is defined %}
AWS_REGION="{{ AWS_REGION }}"
{%- for key, val in secrets.items() %}
{{ key }}=$(aws kms decrypt --region $AWS_REGION --ciphertext-blob fileb://<(echo '{{ val }}' | base64 -d) --output text | cut -f 2 -d $'\t' | base64 -d)
{%- endfor %}
{%- endif %}
