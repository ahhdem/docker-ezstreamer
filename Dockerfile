FROM python:3.8-slim-buster
ENV DEBIAN_FRONTEND noninteractive
ENV AUTOSTREAMS "live fallback"
ENV STREAM_URL "http://stream.mysite.com"
ENV STREAM_NAME "Tremendous Radio"
ENV STREAM_PASSWORD "wowsoSecure"
ENV STREAM_HOST "icecast"
ENV STREAM_PORT "8000"
ENV STREAM_GENRE "Polka"
ENV STREAM_DESCRIPTION "Probably the best thing anyone has ever heard, maybe ever."


COPY etc /etc
RUN mv /etc/apt/sources.list /etc/apt/sources.list.d/stable.list \
 && apt-get -qq -y update \
 && apt-get -y install \
    dumb-init \
    ezstream \
    file \
    flac \
    lame \
    mp3val \
    madplay \
    procps \
 && pip3 install discord.py \
    xmltodict \
 && apt-get purge --auto-remove -y \
    curl \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache /etc/ezstream.xml

RUN useradd stream \
 && mkdir -p /config /var/log/ezstreamer \
 && chown -R stream /chunebot /config /var/log/ezstreamer /etc/ezstream

COPY scripts /
COPY silence.mp3 /

USER stream
VOLUME ["/config", "/var/log/ezstreamer" "/media" ]
ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint.sh"]
