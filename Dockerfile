FROM alpine:3.20

RUN apk add --no-cache \
    openvpn iptables iproute2 ca-certificates bash squid tzdata curl \
 && update-ca-certificates

# Squid config + entrypoint
COPY squid.conf /etc/squid/squid.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
 && mkdir -p /run/openvpn /var/log/squid /var/cache/squid \
 && chown -R squid:squid /var/log/squid /var/cache/squid

EXPOSE 3128
ENTRYPOINT ["/entrypoint.sh"]
