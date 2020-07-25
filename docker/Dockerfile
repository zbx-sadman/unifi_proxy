FROM perl:5-stretch
RUN apt-get update
RUN apt-get install -y libjson-perl libjson-xs-perl libwww-perl libio-socket-ssl-perl libio-socket-ip-perl libdata-dumper-simple-perl libtime-hires-perl
RUN mkdir /etc/unifi_proxy
COPY /usr/local/sbin/unifi_proxy.pl /usr/local/sbin/unifi_proxy.pl
COPY docker/entrypoint.sh /usr/local/sbin/entrypoint.sh
RUN chmod +x /usr/local/sbin/unifi_proxy.pl
RUN chmod +x /usr/local/sbin/entrypoint.sh
WORKDIR /usr/local/sbin
ENTRYPOINT ["./entrypoint.sh"]