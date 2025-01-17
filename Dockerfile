FROM alpine:3.13

ENV REPOSITORY https://github.com/SoftEtherVPN/SoftEtherVPN.git
ENV S6_VERSION 2.2.0.3

# Install s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

COPY .tags /tmp/.tags

RUN \
  apk --no-cache --no-progress update && \
  apk --no-cache --no-progress upgrade && \
  # Install s6 supervisor
  apk --no-cache --no-progress add bash && \
  mkdir -p /etc/services.d && mkdir -p /etc/cont-init.d && \
  mkdir -p /cfg && \
  # Install build dependencies
  apk --no-cache --no-progress --virtual .build-deps add git libgcc libstdc++ gcc musl-dev libc-dev g++ ncurses-dev libsodium-dev \
  readline-dev openssl-dev cmake make zlib-dev && \
  # Grab and build Softether from GitHub
  git clone ${REPOSITORY} /tmp/softether && \
  cd /tmp/softether && \
  # Checkout Latest Tag
  git checkout "$(cat /tmp/.tags)" && git submodule init && git submodule update && export USE_MUSL=YES && \
  # Build
  ./configure && make --silent -C build && make --silent -C build install &&  \
  cp /tmp/softether/build/libcedar.so /tmp/softether/build/libmayaqua.so /usr/lib && \
  # Removing build extensions
  apk del .build-deps && apk del --no-cache --purge && \
  rm -rf /tmp/softether && rm -rf /var/cache/apk/*  && \
  # Deleting unncessary extensions
  rm -rf /usr/local/bin/vpnbridge \
  /usr/local/libexec/softether/vpnbridge && \
  # Reintroduce necassary runtime libraries
  apk add --no-cache --virtual .run-deps \
  libcap libcrypto1.1 libssl1.1 ncurses-libs readline su-exec zlib-dev dhclient libsodium-dev && \
  # Link Libraries to Binary
  ln -s /usr/local/bin/vpnserver /usr/bin/softether-vpnsrv && \
  ln -s /usr/local/bin/vpncmd /usr/bin/softether-vpncmd && \
  ln -s /usr/local/libexec/softether/vpnserver/ /etc && \
  # Install dnsmasq and create the tun network adapter.
  apk add --no-cache dnsmasq iptables && \
  echo "tun" >> /etc/modules && \
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf && \
  mkdir -p /dev/net && \
  mknod /dev/net/tun c 10 200

# Advise to open necassary ports
EXPOSE 1443/tcp 992/tcp 1194/tcp 1194/udp 5555/tcp 500/udp 4500/udp 1701/udp

# Create scripts folder
RUN mkdir -p /scripts

# Copy scripts
ADD https://gist.githubusercontent.com/cenk1cenk2/e03d8610534a9c78f755c1c1ed93a293/raw/logger.sh /scripts/logger.sh
RUN chmod +x /scripts/*.sh

# Move host file system
COPY ./.docker/hostfs /

# Set working directory back
WORKDIR /etc/vpnserver

# s6 behaviour, https://github.com/just-containers/s6-overlay
ENV S6_KEEP_ENV 1
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 2
ENV S6_FIX_ATTRS_HIDDEN 1

ENTRYPOINT ["/init"]
