#!/bin/bash
set -e
TEXT=""
for (( i=0; i>-1; i++ ))
do
	upstream=`eval echo '$'"UPSTREAM_$i"`
	if [ -z $upstream ];then
		break
	fi
	TEXT=${TEXT}"upstream "${upstream}" {\n"
    for (( i=0; i>-1; i++ ))
    do
    	server=`eval echo '$'"UPSTREAM_${upstream}_${i}"`
    	if [ -z $server ];then
    		break
    	fi
    	TEXT=${TEXT}"server "$server";\n"
    done
	TEXT=${TEXT}"}\n"
done
if [ $LIMIT_REQ_ZONE ];then
	TEXT=${TEXT}"limit_req_zone \$binary_remote_addr zone=two:10m rate=$LIMIT_REQ_ZONE;\n"
fi
if [ -z $HTTP_PORT ];then
	HTTP_PORT=80
fi
if [ -z $HTTPS_PORT ];then
	HTTPS_PORT=443
fi
if [ -z $HTTP_PROXY_PORT ];then
	HTTP_PROXY_PORT=88
fi
if [ -z $HTTPS_PROXY_PORT ];then
	HTTPS_PROXY_PORT=451
fi
TEXT=${TEXT}"server {\nlisten "${HTTP_PORT}";\nlisten "${HTTP_PROXY_PORT}" proxy_protocol;\n"
CRT="/cert/"${CERT_PREFIX}"cert.crt"
KEY="/cert/"${CERT_PREFIX}"cert.key"
if [ -f $CRT ] && [ -f $KEY ]
then
crontab -l | {
cat
echo '8 3 * * * nginx -s reload > /dev/null'
} | crontab -
TEXT=${TEXT}"listen "${HTTPS_PORT}" ssl http2;\nlisten "${HTTPS_PROXY_PORT}" ssl http2 proxy_protocol;\n"
TEXT=${TEXT}"ssl_certificate "${CRT}";\n"
TEXT=${TEXT}"ssl_certificate_key "${KEY}";\n"
if [ $SSL_STAPLING_RESPONDER ];then
	TEXT=${TEXT}"ssl_stapling_responder "${SSL_STAPLING_RESPONDER}";\n"
fi
crond
fi
if [ $CLIENT_CERT ];then
	wget $CLIENT_CERT -O /root/client_cert.crt;
	TEXT=${TEXT}"ssl_client_certificate /root/client_cert.crt;\n"
	TEXT=${TEXT}"ssl_verify_client on;\n"
	TEXT=${TEXT}"if ( \$scheme = http ) {\n"
	TEXT=${TEXT}"return 301 https://\$host\$request_uri;\n"
	TEXT=${TEXT}"}\n"
fi
TEXT=${TEXT}"index index.html index.php index.htm index.pdf;\n"
if [ $RESOLVER ];then
	TEXT=${TEXT}"resolver $RESOLVER;\n"
fi
if [ $HOST ];then
    if [ $HOST_PORT ];then
	    TEXT=${TEXT}"proxy_set_header Host \$host:\$proxy_port;\n"
    else
        TEXT=${TEXT}"proxy_set_header Host \$host;\n"
    fi
fi
if [ $REWRITE_HOST ];then
	TEXT=${TEXT}"proxy_set_header Host $REWRITE_HOST;\n"
	TEXT=${TEXT}"proxy_ssl_name $REWRITE_HOST;\n"
fi
TEXT=${TEXT}"include naproxy.conf;\n"
if [ -z $FORWARD_PROXY ];then
	if [ $FIRST_PROXY ];then
		TEXT=${TEXT}"proxy_set_header X-Real-IP \$remote_addr;\n"
	    TEXT=${TEXT}"proxy_set_header X-Forwarded-For \$remote_addr;\n"
	else
		TEXT=${TEXT}"proxy_set_header X-Real-IP \$remote_addr;\n"
	    TEXT=${TEXT}"proxy_set_header X-Forwarded-For \$custom_x_forwarded_for;\n"
	fi
fi
if [ $HIDE_DISPOSITION ];then
	TEXT=${TEXT}"proxy_hide_header Content-Disposition;\n"
fi
if [ $CROSS_ORIGIN ];then
    TEXT=${TEXT}"proxy_hide_header Access-Control-Allow-Origin;\n"
    TEXT=${TEXT}"proxy_hide_header Access-Control-Allow-Headers;\n"
    TEXT=${TEXT}"proxy_hide_header Access-Control-Allow-Methods;\n"
    TEXT=${TEXT}"add_header Access-Control-Allow-Origin *;\n"
    TEXT=${TEXT}"add_header Access-Control-Allow-Headers *;\n"
    TEXT=${TEXT}"add_header Access-Control-Allow-Methods *;\n"
fi
if [ $CONNECT_TIMEOUT ];then
    TEXT=${TEXT}"proxy_connect_timeout $CONNECT_TIMEOUT;\n"
fi
if [ $SEND_TIMEOUT ];then
    TEXT=${TEXT}"proxy_send_timeout $SEND_TIMEOUT;\n"
fi
if [ $READ_TIMEOUT ];then
    TEXT=${TEXT}"proxy_read_timeout $READ_TIMEOUT;\n"
fi
if [ $SENDING_TIMEOUT ];then
    TEXT=${TEXT}"send_timeout $SENDING_TIMEOUT;\n"
fi
if [ $LIMIT_RATE ];then
	TEXT=${TEXT}"limit_rate $LIMIT_RATE;\n"
fi
if [ $LIMIT_CONN ];then
	TEXT=${TEXT}"limit_conn one $LIMIT_CONN;\n"
fi
if [ $LIMIT_REQ ];then
	TEXT=${TEXT}"limit_req zone=two burst=$LIMIT_REQ nodelay;\n"
fi
if [ $NO_CACHE ];then
	TEXT=${TEXT}"proxy_cache off;\n"
	TEXT=${TEXT}"add_header 'Cache-Control' 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';\n"
fi
TEXT=${TEXT}"proxy_http_version 1.1;\n"
TEXT=${TEXT}"proxy_set_header Upgrade \$http_upgrade;\nproxy_set_header Connection \$connection_upgrade;\n"
for (( i=0; i>-1; i++ ))
do
	url=`eval echo '$'"URL_$i"`
	path=`eval echo '$'"PATH_$i"`
	if [ -z $url ];then
		break
	fi
	if [ -z $path ];then
		break
	fi
	TEXT=${TEXT}"location $path {\nproxy_pass $url;\n}\n"
done
if [ $DEFAULT_INDEX ];then
	TEXT=${TEXT}"location ~ \\.html\$ {\nproxy_pass $DEFAULT_INDEX;\n}\n"
	TEXT=${TEXT}"location ~ \\.ico\$ {\nproxy_pass $DEFAULT_INDEX;\n}\n"
	TEXT=${TEXT}"location ~ /\$ {\nproxy_pass $DEFAULT_INDEX;\n}\n"
fi
if [ $DEFAULT_URL ];then
	TEXT=${TEXT}"location / {\nproxy_pass $DEFAULT_URL;\n}\n"
fi
TEXT=${TEXT}"}\n"
echo -e $TEXT > /etc/nginx/conf.d/default.conf
exec nginx -g 'daemon off;'