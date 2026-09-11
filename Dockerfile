FROM alpine:3.20

RUN apk add --no-cache \
    openvpn iptables iproute2 ca-certificates bash squid tzdata curl tini \
 && update-ca-certificates

# Squid config + entrypoint
COPY squid.conf /etc/squid/squid.conf
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh
COPY route-up.sh /route-up.sh
COPY route-pre-down.sh /route-pre-down.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh /route-up.sh /route-pre-down.sh \
 && mkdir -p /run/openvpn /var/log/squid /var/cache/squid \
 && chown -R squid:squid /var/log/squid /var/cache/squid

EXPOSE 3128
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 CMD ["/healthcheck.sh"]
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
