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
TEXT=${TEXT}"server {\nlisten       80;\nserver_name localhost;\nindex  index.html index.php index.htm;\n"
if [ $HOST ];then
    if [ $HOST_PORT ];then
	TEXT=${TEXT}"proxy_set_header Host       \$host:\$proxy_port;\n"
    else
        TEXT=${TEXT}"proxy_set_header Host       \$host;\n"
    fi
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
if [ -z $DEFAULT_URL ];then
	DEFAULT_URL=http://www.baidu.com
fi
TEXT=${TEXT}"location / {\nproxy_pass $DEFAULT_URL;\n}\n}"
echo -e $TEXT > /etc/nginx/conf.d/default.conf
exec nginx -g 'daemon off;'