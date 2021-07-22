FROM nginx:1.21.1-alpine
ENV APP_DIR /srv/philomena
COPY docker/web/nginx.conf /tmp/docker.nginx
RUN envsubst '$APP_DIR' < /tmp/docker.nginx > /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
