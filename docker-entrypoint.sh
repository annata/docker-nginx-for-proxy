#!/bin/bash
set -e
TEXT="server {\nlisten       80;\nserver_name localhost;\nindex  index.html index.php index.htm;\n"
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