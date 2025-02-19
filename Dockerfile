FROM nginx:1.26-alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY naproxy.conf /etc/nginx/naproxy.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN apk add --no-cache bash && chmod +x /docker-entrypoint.sh
STOPSIGNAL SIGTERM
CMD ["/docker-entrypoint.sh"]