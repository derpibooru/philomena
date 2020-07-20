FROM alpine:3.11

ADD crontab.txt /crontab.txt
ADD anonymize_ips.sh /anonymize_ips.sh
COPY entry.sh /entry.sh
RUN chmod 755 /anonymize_ips.sh /entry.sh

RUN apk add postgresql-client

RUN /usr/bin/crontab /crontab.txt

CMD ["/entry.sh"]
