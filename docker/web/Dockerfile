FROM nginx:1.21.4-alpine
ENV APP_DIR /srv/philomena
ENV BUCKET_NAME philomena
COPY docker/web/nginx.conf /tmp/docker.nginx
RUN envsubst '$APP_DIR $BUCKET_NAME' < /tmp/docker.nginx > /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
