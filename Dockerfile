FROM debian:bookworm AS builder

# properly setup debian sources
ENV DEBIAN_FRONTEND=noninteractive
RUN rm -f /etc/apt/sources.list.d/debian.sources && \
echo "deb http://deb.debian.org/debian bookworm main\n\
deb-src http://deb.debian.org/debian bookworm main\n\
deb http://deb.debian.org/debian bookworm-updates main\n\
deb-src http://deb.debian.org/debian bookworm-updates main\n\
deb http://security.debian.org bookworm-security main\n\
deb-src http://security.debian.org bookworm-security main\n\
" > /etc/apt/sources.list

# install packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y upgrade && \
    apt-get -y --force-yes install openssl dpkg-dev debhelper syslog-ng-core syslog-ng && \
    apt-get -y build-dep pure-ftpd-mysql && \
    mkdir /ftpdata && \
    mkdir /tmp/pure-ftpd-mysql && \
    cd /tmp/pure-ftpd-mysql && \
    apt-get source pure-ftpd-mysql && \
    cd pure-ftpd-* && \
    sed -i '/^optflags=/ s/$/ --without-capabilities/g' ./debian/rules && \
    dpkg-buildpackage -b -uc && \
    dpkg -i /tmp/pure-ftpd-mysql/pure-ftpd-common*.deb && \
    apt-get -y install openbsd-inetd \
    default-mysql-client && \
    dpkg -i /tmp/pure-ftpd-mysql/pure-ftpd-mysql*.deb && \
    apt-mark hold pure-ftpd pure-ftpd-mysql pure-ftpd-common && \
    apt-get remove -y dpkg-dev libc-dev-bin libc-devtools libssl-dev libsodium-dev libc6-dev linux-libc-dev \
    libmariadb-dev libmariadb-dev-compat syslog-ng-mod-python python3 && \
    apt-get purge -y build-essential gcc g++ make cmake ninja-build pkg-config autoconf automake libtool && \
    apt -y autoremove 

# add docker user and group
RUN groupadd -g 999 docker
RUN useradd -u 111 -g 999 -d /dev/null -s /usr/sbin/nologin docker
RUN chown -R docker:docker /ftpdata

# cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# run mysql configuration creator script
COPY run.sh /run.sh
RUN chmod u+x /run.sh

# entry point
ENTRYPOINT ["/run.sh"]

# define important volumes
VOLUME /ftpdata

# expose important ports
EXPOSE 20 21 30000-30009
