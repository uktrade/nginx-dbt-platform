#!/bin/bash

set -euo pipefail

# Get settings from environment variables or fall back to defaults
CLIENT_HEADER_BUFFER_SIZE_IN_KILOBYTES=${CLIENT_HEADER_BUFFER_SIZE_IN_KILOBYTES:-1}
PROXY_BUFFER_SIZE_IN_KILOBYTES=${PROXY_BUFFER_SIZE_IN_KILOBYTES:-8}

set_proxy_pass_configuration () {
  LOCATION_PATH=$1 # E.g. "/", "/admin/" etc.
  UPSTREAM_HOST=$2 # E.g. "upstream_server_private" or "upstream_server_public"
  OUTPUT_FILE=$3 # E.g. "private_paths.txt" or "public_paths.txt"
  PROXY_BUFFER_SIZE_IN_KILOBYTES=$4 # E.g. 8, 16, 32, 64, 128 etc.

  # Set proxy buffer size
  if ! [[ $PROXY_BUFFER_SIZE_IN_KILOBYTES =~ ^[0-9]+$ ]]; then
    echo "Error: If set, PROXY_BUFFER_SIZE_IN_KILOBYTES must be an integer" >&2;
    exit 1
  fi
  PROXY_BUFFER_SIZE="${PROXY_BUFFER_SIZE_IN_KILOBYTES}k"
  PROXY_BUSY_BUFFERS_SIZE="$((${PROXY_BUFFER_SIZE_IN_KILOBYTES} * 2))k"

  cat << EOF >> $OUTPUT_FILE

    location $LOCATION_PATH {
        proxy_pass http://$UPSTREAM_HOST;
        proxy_set_header Host \$host;
        proxy_set_header x-forwarded-for \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Prefix $LOCATION_PATH;

        proxy_buffer_size ${PROXY_BUFFER_SIZE};
        proxy_buffers 8 ${PROXY_BUFFER_SIZE};
        proxy_busy_buffers_size ${PROXY_BUSY_BUFFERS_SIZE};
EOF

  if [[ -n "${ALLOW_WEBSOCKETS+x}" ]]; then
      cat << EOF >> $OUTPUT_FILE
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
EOF
  fi

  echo -e "\n    }" >> $OUTPUT_FILE
}

# Either PRIV_PATH_LIST or PUB_PATH_LIST VARs can be set, not both.
# If neither is set, the default is to make / public
# To enable IP filter set PRIV_PATH_LIST: '/'
if ! [ -z ${PRIV_PATH_LIST+x} ]; then
  PUBLIC_PATHS=""
elif [ -z ${PUB_PATH_LIST+x} ] || [ "$PUB_PATH_LIST" = '/' ]; then
  set_proxy_pass_configuration "/" "upstream_server_public" "public_paths.txt" "${PROXY_BUFFER_SIZE_IN_KILOBYTES}"
  PUBLIC_PATHS=$(<public_paths.txt)
else
  set_proxy_pass_configuration "/" "upstream_server_private" "public_paths.txt" "${PROXY_BUFFER_SIZE_IN_KILOBYTES}"
  for pub in $(echo -e $PUB_PATH_LIST |sed "s/,/ /g")
  do
    set_proxy_pass_configuration "$pub" "upstream_server_public" "public_paths.txt" "${PROXY_BUFFER_SIZE_IN_KILOBYTES}"
  done
  PUBLIC_PATHS=$(<public_paths.txt)
fi


if (! [ -z ${PRIV_PATH_LIST+x} ] && ! [ -z ${PUB_PATH_LIST+x} ] ) || [ -z ${PRIV_PATH_LIST+x} ]; then
  PRIVATE_PATHS=""
elif [ ${PRIV_PATH_LIST} == '/' ]; then
    set_proxy_pass_configuration "/" "upstream_server_private" "private_paths.txt" "${PROXY_BUFFER_SIZE_IN_KILOBYTES}"
    PRIVATE_PATHS=$(<private_paths.txt)
else
  set_proxy_pass_configuration "/" "upstream_server_public" "private_paths.txt" "${PROXY_BUFFER_SIZE_IN_KILOBYTES}"
  for priv in $(echo -e $PRIV_PATH_LIST |sed "s/,/ /g")
  do
    set_proxy_pass_configuration "$priv" "upstream_server_private" "private_paths.txt" "${PROXY_BUFFER_SIZE_IN_KILOBYTES}"
  done
  PRIVATE_PATHS=$(<private_paths.txt)
fi

echo ">> generating self signed cert"
openssl req -x509 -newkey rsa:4086 \
-subj "/C=XX/ST=XXXX/L=XXXX/O=XXXX/CN=localhost" \
-keyout "/key.pem" \
-out "/cert.pem" \
-days 3650 -nodes -sha256

# Set client header buffer size
if ! [[ $CLIENT_HEADER_BUFFER_SIZE_IN_KILOBYTES =~ ^[0-9]+$ ]]; then
  echo "Error: If set, CLIENT_HEADER_BUFFER_SIZE_IN_KILOBYTES must be an integer" >&2;
  exit 1
fi
CLIENT_HEADER_BUFFER_SIZE="${CLIENT_HEADER_BUFFER_SIZE_IN_KILOBYTES}k"
LARGE_CLIENT_HEADER_BUFFERS="$((${CLIENT_HEADER_BUFFER_SIZE_IN_KILOBYTES} * 8))k"

cat <<EOF >/etc/nginx/nginx.conf
user nginx;
worker_processes 2;
events {
  worker_connections 1024;
}

http {
  upstream upstream_server_private{
      server localhost:8000;
  }

  upstream upstream_server_public{
      server localhost:8080;
  }

  client_header_buffer_size ${CLIENT_HEADER_BUFFER_SIZE};
  large_client_header_buffers 4 ${LARGE_CLIENT_HEADER_BUFFERS};

  log_format main '\$http_x_forwarded_for - \$remote_user [\$time_local] '
                  '"\$request" \$status \$body_bytes_sent "\$http_referer" '
                  '"\$http_user_agent"' ;

  access_log /var/log/nginx/access.log main;
  error_log /var/log/nginx/error.log;
  server_tokens off;
  server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate /cert.pem;
    ssl_certificate_key /key.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

    include /etc/nginx/mime.types;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;
    set_real_ip_from 172.16.0.0/20;
    set_real_ip_from 10.0.0.0/8;
    set_real_ip_from 192.168.0.0/16;
    client_max_body_size 600M;

$PUBLIC_PATHS

$PRIVATE_PATHS
  }
}
EOF

echo "Running nginx..."

# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
