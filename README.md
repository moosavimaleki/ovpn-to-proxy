# OpenVPN → HTTP Proxy (Squid)

This image runs an **OpenVPN client** inside a container and exposes an **HTTP/HTTPS proxy (Squid)**.
All traffic sent to the proxy is routed **through the VPN tunnel**.

✔ OpenVPN client inside Docker  
✔ HTTP / HTTPS proxy (CONNECT supported)  
✔ Kill-switch (no traffic leaks outside VPN)  
✔ Designed for private use (not a public open proxy)

---

## How it works

```

[ Your App / Browser ]
|
|  HTTP / HTTPS proxy (3128)
v
Squid Proxy
|
v
OpenVPN tunnel (tun0)
|
v
VPN Provider
|
v
Internet

```

---

## Quick Start

### 1. Prepare the `ovpn/` directory

Create a folder named `ovpn` **next to your docker-compose or docker run command**:

```

ovpn/
├── client.ovpn
└── auth.txt

````

### `client.ovpn`
Your standard OpenVPN client configuration file.

Example:
```conf
client
dev tun
proto tcp
remote your.vpn.server 443
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-128-CBC
auth SHA1
auth-user-pass
redirect-gateway def1
verb 3

<ca>
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
</key>
````

⚠️ `auth-user-pass` **must be present** if your VPN uses username/password auth.

---

### `auth.txt`

Username and password used by OpenVPN:

```
USERNAME
PASSWORD
```

(two lines, no extra spaces)

---

## Run with Docker

```bash
docker run -d --name vpnproxy \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  -p 3128:3128 \
  -v "$PWD/ovpn:/ovpn:ro" \
  moosavimaleki/openvpn-squid-proxy:latest
```

---

## Run with docker-compose (recommended)

```yaml
services:
  vpnproxy:
    image: moosavimaleki/openvpn-squid-proxy:latest
    container_name: vpnproxy
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "3128:3128"
    volumes:
      - ./ovpn:/ovpn:ro
    restart: unless-stopped
```

---

## Using the proxy

### Environment variables

```bash
export http_proxy=http://127.0.0.1:3128
export https_proxy=http://127.0.0.1:3128
```

### curl

```bash
curl -x http://127.0.0.1:3128 https://ifconfig.me
```

### Browser

Set HTTP / HTTPS proxy to:

```
Host: 127.0.0.1
Port: 3128
```

---

## 🚀 One-line run (recommended)

```bash
docker run -d --name vpnproxy \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  -p 3128:3128 \
  -v "$(pwd)/ovpn:/ovpn:ro" \
  moosavimaleki/openvpn-squid-proxy:latest
```

---

## قبل از اجرا فقط اینو آماده کن

در کنار این دستور، کاربر فقط باید این پوشه رو داشته باشه:

```
ovpn/
├── client.ovpn
└── auth.txt
```

### auth.txt

```
USERNAME
PASSWORD
```

---

## بعد از اجرا (تست فوری)

```bash
curl -x http://127.0.0.1:3128 https://ifconfig.me
```

اگر IP مربوط به VPN بود → همه‌چی اوکیه ✅

---

## این دستور دقیقاً چی کار می‌کنه؟

* `--cap-add=NET_ADMIN` → اجازه ساخت تونل VPN
* `--device /dev/net/tun` → فعال‌سازی TUN device
* `-p 3128:3128` → در دسترس بودن پروکسی
* `-v ./ovpn:/ovpn:ro` → لود کانفیگ VPN
* `moosavimaleki/openvpn-squid-proxy:latest` → ایمیج آماده
 
---

## Important Notes

### 🔐 Security

* This image is **not meant to be a public proxy**
* If you expose it to the internet, **add authentication or IP restrictions**
* Default setup allows only Docker/local networks

### 🧠 DNS handling

* Docker DNS (`127.0.0.11`) breaks after OpenVPN `redirect-gateway`
* The container explicitly sets public DNS servers internally
* Prevents DNS failures and common 503 proxy errors

### 🔁 Kill-switch

* If the VPN tunnel goes down, **all outbound traffic is blocked**
* No traffic leaks outside the VPN

### Healthcheck URL

The healthcheck sends a request through Squid every few seconds. To avoid a
fixed external dependency, put one URL on the first non-empty line of
`ovpn/healthchek.txt` (for example `https://your-internal-health-endpoint/`).
The file is optional; if it is absent or empty, the default is
`http://www.google.com`. You can also override it with `CHECK_URL` or
`HEALTHCHECK_URL`, and change the file path with `CHECK_URL_FILE`.

---

## Ports

| Port | Description                |
| ---: | -------------------------- |
| 3128 | HTTP / HTTPS Proxy (Squid) |

---

## What this image is NOT

* ❌ Not a SOCKS5 proxy (no port 1080)
* ❌ Not a VPN server
* ❌ Not designed for anonymous/public usage

---

## Common issues

### Proxy returns 403

* CONNECT not allowed → check Squid ACLs

### Proxy returns 503

* Usually DNS misconfiguration
* Ensure `client.ovpn` uses `redirect-gateway def1`

---

## Roadmap / Extensions

Possible future additions:

* SOCKS5 proxy (1080)
* Proxy authentication
* Multi-arch builds (amd64 / arm64)

---

## License

MIT
