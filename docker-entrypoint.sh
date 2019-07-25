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
TEXT=${TEXT}"server {\nlisten 80;\n"
CRT="/cert/"${CERT_PREFIX}"cert.crt"
KEY="/cert/"${CERT_PREFIX}"cert.key"
if [ -f $CRT ] && [ -f $KEY ]
then
crontab -l | {
cat
echo '8 3 * * * nginx -s reload > /dev/null'
} | crontab -
TEXT=${TEXT}"listen 443 ssl;\n"
TEXT=${TEXT}"ssl_certificate "${CRT}";\n"
TEXT=${TEXT}"ssl_certificate_key "${KEY}";\n"
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
if [ $CONNECT_TIMEOUT ];then
    TEXT=${TEXT}"proxy_connect_timeout $CONNECT_TIMEOUT;\n"
else
	TEXT=${TEXT}"proxy_connect_timeout 60s;\n"
fi
if [ $SEND_TIMEOUT ];then
    TEXT=${TEXT}"proxy_send_timeout $SEND_TIMEOUT;\n"
else
	TEXT=${TEXT}"proxy_send_timeout 60s;\n"
fi
if [ $READ_TIMEOUT ];then
    TEXT=${TEXT}"proxy_read_timeout $READ_TIMEOUT;\n"
else
	TEXT=${TEXT}"proxy_read_timeout 90s;\n"
fi
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
if [ $DEFAULT_URL ];then
	TEXT=${TEXT}"location / {\nproxy_pass $DEFAULT_URL;\n}\n"
fi
TEXT=${TEXT}"}\n"
echo -e $TEXT > /etc/nginx/conf.d/default.conf
exec nginx -g 'daemon off;'