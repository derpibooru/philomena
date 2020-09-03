FROM alpine:3.11

ADD crontab.txt /crontab.txt
ADD scripts /scripts
COPY entry.sh /entry.sh
RUN chmod 755 -R /scripts /entry.sh

RUN apk add postgresql-client

RUN /usr/bin/crontab /crontab.txt

CMD ["/entry.sh"]
