FROM alpine:3.11

ENV PGHOST=${POSTGRES_HOST}
ENV PGPORT=${POSTGRES_PORT}
ENV PGDATABASE=${POSTGRES_DATABASE}
ENV PGUSER=${POSTGRES_USER}
ENV PGPASSWORD=${POSTGRES_PASSWORD}

ADD crontab.txt /crontab.txt
ADD scripts /scripts
COPY entry.sh /entry.sh
RUN chmod 755 -R /scripts /entry.sh

RUN apk add postgresql-client

RUN /usr/bin/crontab /crontab.txt

CMD ["/entry.sh"]
