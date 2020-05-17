FROM debian:buster-slim
ENV DEBIAN_FRONTEND noninteractive

COPY etc/apt /etc/apt
RUN mv /etc/apt/sources.list /etc/apt/sources.list.d/stable.list \
 && apt-get -qq -y update \
 && apt-get -y install \
    dumb-init \
    ezstream \
    flac \
    lame \
 && useradd stream \
 && apt-get purge --auto-remove -y \
    curl \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

COPY etc/ezstream /etc/ezstream

COPY scripts /
COPY silence.mp3 /

EXPOSE 8000
VOLUME ["/config" ]
USER ezstream
ENTRYPOINT ["/usr/bin/dumb-init", "/start.sh"]
