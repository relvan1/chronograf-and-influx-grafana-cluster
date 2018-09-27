FROM buildpack-deps:stretch-curl

RUN set -ex && \
    for key in \
        05CE15085FC09D18E99EFB22684A14CF2582E0C5 ; \
    do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
        gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
        gpg --keyserver keyserver.pgp.com --recv-keys "$key" ; \
    done

ENV INFLUXDB_VERSION 1.6.3 && CHRONOGRAF_VERSION 1.6.2

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH='amd64';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armhf';; \
      armel) ARCH='armel';; \
      *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
    esac && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_${ARCH}.deb.asc && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    gpg --batch --verify influxdb_${INFLUXDB_VERSION}_${ARCH}.deb.asc influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    dpkg -i influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    rm -f influxdb_${INFLUXDB_VERSION}_${ARCH}.deb*

RUN set -ex && \
    apt-get update && apt-get install -y gpg dirmngr --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* && \
    for key in \
        05CE15085FC09D18E99EFB22684A14CF2582E0C5 ; \
    do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
        gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
        gpg --keyserver keyserver.pgp.com --recv-keys "$key" ; \
    done

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH='amd64';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armhf';; \
      armel) ARCH='armel';; \
      *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
    esac && \
    set -x && \
    apt-get update && apt-get install -y ca-certificates curl --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* && \
    curl -SLO "https://dl.influxdata.com/chronograf/releases/chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb.asc" && \
    curl -SLO "https://dl.influxdata.com/chronograf/releases/chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb" && \
    gpg --batch --verify chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb.asc chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb && \
    dpkg -i chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb && \
    rm -f chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb* && \
    apt-get purge -y --auto-remove $buildDeps

COPY LICENSE /usr/share/chronograf/LICENSE

COPY agpl-3.0.md /usr/share/chronograf/agpl-3.0.md

VOLUME /var/lib/chronograf

COPY entrypoint-chro.sh /entrypoint-chro.sh

COPY influxdb.conf /etc/influxdb/influxdb.conf

VOLUME /var/lib/influxdb

COPY entrypoint.sh /entrypoint.sh

COPY init-influxdb.sh /init-influxdb.sh

RUN apt-get -y update && apt-get install -y apt-utils openssh-server supervisor wget vim 

RUN mkdir -p /var/run/sshd /var/log/supervisor

RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 8086 8083 2003 22 8888

CMD ["/usr/bin/supervisord"]
