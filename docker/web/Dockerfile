FROM openresty/openresty:1.21.4.1-7-alpine
ARG APP_DIR
ARG S3_SCHEME
ARG S3_HOST
ARG S3_PORT
ARG S3_BUCKET

RUN apk add --no-cache gettext curl perl && opm get jkeys089/lua-resty-hmac=0.06 && mkdir -p /etc/nginx/lua
COPY docker/web/aws-signature.lua /etc/nginx/lua
COPY docker/web/nginx.conf /tmp/docker.nginx
RUN envsubst '$APP_DIR $S3_SCHEME $S3_HOST $S3_PORT $S3_BUCKET' < /tmp/docker.nginx > /etc/nginx/conf.d/default.conf && \
    mkdir -p /var/www/cache/tmp && \
    echo 'env AWS_ACCESS_KEY_ID;' >> /usr/local/openresty/nginx/conf/nginx.conf && \
    echo 'env AWS_SECRET_ACCESS_KEY;' >> /usr/local/openresty/nginx/conf/nginx.conf
EXPOSE 80
CMD ["openresty", "-g", "daemon off;"]
