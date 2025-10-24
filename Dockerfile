FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# configure debian sources and install all dependencies in as few layers as possible
RUN rm -f /etc/apt/sources.list.d/debian.sources && \
    echo "deb http://deb.debian.org/debian bookworm main\ndeb-src http://deb.debian.org/debian bookworm main\ndeb http://deb.debian.org/debian bookworm-updates main\ndeb-src http://deb.debian.org/debian bookworm-updates main\ndeb http://security.debian.org bookworm-security main\ndeb-src http://security.debian.org bookworm-security main" > /etc/apt/sources.list && \
    apt-get update && apt-get -y upgrade && \
    apt-get -y --force-yes install openssl dpkg-dev debhelper syslog-ng-core syslog-ng && \
    apt-get -y build-dep pure-ftpd-mysql && \
    mkdir /ftpdata /tmp/pure-ftpd-mysql && \
    cd /tmp/pure-ftpd-mysql && \
    apt-get source pure-ftpd-mysql && \
    cd pure-ftpd-* && \
    sed -i '/^optflags=/ s/$/ --without-capabilities/g' ./debian/rules && \
    dpkg-buildpackage -j"$(nproc)" -b -uc && \
    dpkg -i /tmp/pure-ftpd-mysql/pure-ftpd-common*.deb && \
    apt-get -y install openbsd-inetd default-mysql-client && \
    dpkg -i /tmp/pure-ftpd-mysql/pure-ftpd-mysql*.deb && \
    apt-mark hold pure-ftpd pure-ftpd-mysql pure-ftpd-common && \
    apt-get remove -y dpkg-dev libc-dev-bin libc-devtools libssl-dev libsodium-dev libc6-dev linux-libc-dev \
        libmariadb-dev libmariadb-dev-compat syslog-ng-mod-python python3 && \
    apt-get purge -y build-essential gcc g++ make cmake ninja-build pkg-config autoconf automake libtool && \
    apt -y autoremove && \
    groupadd -g 999 docker && \
    useradd -u 111 -g 999 -d /dev/null -s /usr/sbin/nologin docker && \
    chown -R docker:docker /ftpdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

COPY --chown=docker:docker run.sh /run.sh
RUN chmod u+x /run.sh

VOLUME /ftpdata
EXPOSE 20 21 30000-30009

ENTRYPOINT ["/run.sh"]
