FROM python:3.8-slim-buster
ENV DEBIAN_FRONTEND noninteractive

COPY etc/apt /etc/apt
RUN mv /etc/apt/sources.list /etc/apt/sources.list.d/stable.list \
 && apt-get -qq -y update \
 && apt-get -y install \
    dumb-init \
    ezstream \
    flac \
    lame \
    xmltodict \
 && pip3 install discord.py \
 && useradd stream \
 && apt-get purge --auto-remove -y \
    curl \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache \
 && mkdir -p /config /var/log/ezstreamer \

COPY etc/ezstream/ /etc/
COPY scripts /
COPY silence.mp3 /
RUN  chown stream /config /var/log/ezstreamer /etc/ezstream.xml


USER stream
VOLUME ["/config", "/var/log/ezstreamer" ]
ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint.sh"]
