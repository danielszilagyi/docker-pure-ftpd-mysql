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
    apt-get -y --force-yes install dpkg-dev debhelper && \
    apt-get -y build-dep pure-ftpd-mysql

WORKDIR /tmp/pure-ftpd-mysql

RUN apt-get source pure-ftpd-mysql && \
    cd pure-ftpd-* && \
    sed -i '/^optflags=/ s/$/ --without-capabilities/g' ./debian/rules && \
    dpkg-buildpackage -j"$(nproc)" -b -uc && \
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

# -------------------------------------------------------------------
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Copy and install only built .deb files, remove installers/deps after
COPY --from=builder /tmp/pure-ftpd-mysql/pure-ftpd*.deb /tmp/

# Set up sources and runtime dependencies
RUN rm -f /etc/apt/sources.list.d/debian.sources && \
    echo "deb http://deb.debian.org/debian bookworm main\ndeb-src http://deb.debian.org/debian bookworm main\ndeb http://deb.debian.org/debian bookworm-updates main\ndeb-src http://deb.debian.org/debian bookworm-updates main\ndeb http://security.debian.org bookworm-security main\ndeb-src http://security.debian.org bookworm-security main" > /etc/apt/sources.list && \
    apt-get update && apt-get -y upgrade && \
    apt-get install -y --no-install-recommends \
        openssl syslog-ng-core syslog-ng openbsd-inetd default-mysql-client libsodium23 && \
    groupadd -g 999 docker && \
    useradd -u 111 -g 999 -d /dev/null -s /usr/sbin/nologin docker && \
    mkdir /ftpdata && \
    chown -R docker:docker /ftpdata && \
    dpkg -i /tmp/pure-ftpd-common*.deb /tmp/pure-ftpd-mysql*.deb && \
    rm -rf /var/lib/apt/lists/* /tmp/*.deb

# Add entrypoint script and permissions
COPY --chown=docker:docker run.sh /run.sh
RUN chmod u+x /run.sh

VOLUME /ftpdata
EXPOSE 20 21 30000-30009
ENTRYPOINT ["/run.sh"]