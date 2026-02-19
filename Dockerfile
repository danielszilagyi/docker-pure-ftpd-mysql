FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV DEB_BUILD_OPTIONS=noddebs

# Set up sources and install build dependencies
RUN rm -f /etc/apt/sources.list.d/debian.sources && \
    cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main
deb-src http://deb.debian.org/debian trixie main
deb http://deb.debian.org/debian trixie-updates main
deb-src http://deb.debian.org/debian trixie-updates main
deb http://security.debian.org trixie-security main
deb-src http://security.debian.org trixie-security main
EOF
RUN apt-get update && apt-get -y upgrade && \
    apt-get -y --force-yes install dpkg-dev debhelper && \
    apt-get -y build-dep pure-ftpd-mysql

WORKDIR /tmp/pure-ftpd-mysql
COPY rules /tmp/pureftpd-rules

RUN apt-get source pure-ftpd-mysql && \
    cd pure-ftpd-* && \
    cp /tmp/pureftpd-rules debian/rules && \
    sed -i '/^Package: pure-ftpd-ldap/,/^$/d' debian/control && \
    sed -i '/^Package: pure-ftpd-postgresql/,/^$/d' debian/control && \
    rm -f debian/pure-ftpd-ldap* debian/pure-ftpd-postgresql* && \
    dpkg-buildpackage -j"$(nproc)" -b -uc

# -------------------------------------------------------------------
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

COPY --from=builder /tmp/pure-ftpd-mysql/pure-ftpd*.deb /tmp/

# Set up sources and runtime dependencies
RUN rm -f /etc/apt/sources.list.d/debian.sources && \
    echo "deb http://deb.debian.org/debian trixie main\ndeb-src http://deb.debian.org/debian trixie main\ndeb http://deb.debian.org/debian trixie-updates main\ndeb-src http://deb.debian.org/debian trixie-updates main\ndeb http://security.debian.org trixie-security main\ndeb-src http://security.debian.org trixie-security main" > /etc/apt/sources.list && \
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
