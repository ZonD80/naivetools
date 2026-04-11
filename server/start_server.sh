#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "Error: $*" >&2
  exit 1
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "This script must be run as root (e.g. sudo \"$0\")."
}

require_root

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

fetch_public_ip() {
  local url="https://whatismyip.akamai.com/"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" | tr -d '\r\n'
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url" | tr -d '\r\n'
  else
    die "Need curl or wget to fetch public IP"
  fi
}

download_to() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    die "Need curl or wget to download"
  fi
}

domain_resolves_to_ip() {
  local domain="$1" expected_ip="$2"
  local ips=""
  if command -v dig >/dev/null 2>&1; then
    ips=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9.]+$' || true)
  elif command -v getent >/dev/null 2>&1; then
    ips=$(getent ahostsv4 "$domain" 2>/dev/null | awk '{print $1}' | sort -u || true)
  elif command -v host >/dev/null 2>&1; then
    ips=$(host -t A "$domain" 2>/dev/null | awk '/has address/ {print $NF}' || true)
  else
    die "Need dig, getent, or host to verify DNS"
  fi
  [[ -n "$ips" ]] || return 1
  while IFS= read -r ip; do
    [[ -z "$ip" ]] && continue
    if [[ "$ip" == "$expected_ip" ]]; then
      return 0
    fi
  done <<<"$ips"
  return 1
}

write_caddyfile() {
  local domain="$1" email="$2" user="$3" pass="$4" outfile="$5"
  require_cmd python3
  DOMAIN="$domain" EMAIL="$email" PROXY_USER="$user" PROXY_PASS="$pass" python3 - "$outfile" <<'PY'
import os, sys
out = sys.argv[1]
domain = os.environ["DOMAIN"]
email = os.environ["EMAIL"]
user = os.environ["PROXY_USER"]
password = os.environ["PROXY_PASS"]

def caddy_quote(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

text = f"""{{
  order forward_proxy before file_server
}}
:443, {domain} {{
  tls {caddy_quote(email)}
  forward_proxy {{
    basic_auth {caddy_quote(user)} {caddy_quote(password)}
    hide_ip
    hide_via
    probe_resistance
  }}
  file_server {{
    root /var/www/html
  }}
}}
"""
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
PY
}

# Parse Caddyfile written by this script (quoted tls / basic_auth strings).
exports_from_caddyfile() {
  local path="$1"
  python3 - "$path" <<'PY'
import re
import shlex
import sys

def unescape_caddy_quoted(quoted: str) -> str:
    if not (len(quoted) >= 2 and quoted[0] == '"' and quoted[-1] == '"'):
        return quoted
    inner = quoted[1:-1]
    out = []
    i = 0
    while i < len(inner):
        if inner[i] == "\\" and i + 1 < len(inner):
            c = inner[i + 1]
            if c == '"':
                out.append('"')
                i += 2
                continue
            if c == "\\":
                out.append("\\")
                i += 2
                continue
        out.append(inner[i])
        i += 1
    return "".join(out)


def main() -> None:
    path = sys.argv[1]
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        print(f"Could not read Caddyfile: {e}", file=sys.stderr)
        sys.exit(1)

    dm = re.search(r":443,\s*([^\s{#]+)\s*\{", text)
    tm = re.search(r"\btls\s+((?:\"(?:\\.|[^\"])*\"))", text)
    bm = re.search(
        r"\bbasic_auth\s+((?:\"(?:\\.|[^\"])*\"))\s+((?:\"(?:\\.|[^\"])*\"))",
        text,
    )
    if not dm or not tm or not bm:
        print(
            "Could not parse /etc/caddy/Caddyfile (expected :443 host, tls, and basic_auth lines).",
            file=sys.stderr,
        )
        sys.exit(1)

    domain = dm.group(1).strip()
    email = unescape_caddy_quoted(tm.group(1))
    user_q, pass_q = bm.group(1), bm.group(2)
    user = unescape_caddy_quoted(user_q)
    password = unescape_caddy_quoted(pass_q)

    for k, v in (
        ("DOMAIN", domain),
        ("EMAIL", email),
        ("PROXY_USER", user),
        ("PROXY_PASS", password),
    ):
        print(f"export {k}={shlex.quote(v)}")


if __name__ == "__main__":
    main()
PY
}

# Payload: user:password@host:443 → base64 → https://<b64>?method=auto (naive client import)
naive_share_url() {
  PROXY_USER="$1" PROXY_PASS="$2" DOMAIN="$3" python3 - <<'PY'
import base64, os

u = os.environ["PROXY_USER"]
p = os.environ["PROXY_PASS"]
d = os.environ["DOMAIN"]
raw = f"{u}:{p}@{d}:443"
b64 = base64.b64encode(raw.encode("utf-8")).decode("ascii").rstrip("=")
print(f"https://{b64}?method=auto")
PY
}

print_qr_python() {
  local share_url="$1"
  SHARE_URL="$share_url" python3 <<'PY'
import os
import sys

try:
    import qrcode
except ImportError:
    sys.exit(1)

try:
    url = os.environ["SHARE_URL"]
    qr = qrcode.QRCode(version=None, box_size=1, border=2)
    qr.add_data(url)
    qr.make(fit=True)
    if hasattr(qr, "print_ascii"):
        qr.print_ascii(invert=True)
    else:
        qr.print_tty()
except Exception:
    sys.exit(1)
sys.exit(0)
PY
}

show_share_link_and_qr() {
  local share_url
  share_url="$(naive_share_url "$PROXY_USER" "$PROXY_PASS" "$DOMAIN")"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Share link (import in naive client — host, port, user, password, type HTTPS)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$share_url"
  echo ""
  echo "QR code:"
  if command -v qrencode >/dev/null 2>&1; then
    printf '%s' "$share_url" | qrencode -t ANSIUTF8 2>/dev/null \
      || printf '%s' "$share_url" | qrencode -t UTF8
  elif print_qr_python "$share_url"; then
    :
  else
    echo "  (Install package 'qrencode' or Python 'qrcode' to print the QR in the terminal.)"
  fi
  echo ""
}

main() {
  require_cmd tar
  require_cmd python3

  local caddyfile_path="/etc/caddy/Caddyfile"
  mkdir -p /etc/caddy /var/www/html

  if [[ -f "$caddyfile_path" ]] && [[ -s "$caddyfile_path" ]]; then
    echo "Found existing $caddyfile_path — skipping domain, DNS check, email, and proxy prompts."
    eval "$(exports_from_caddyfile "$caddyfile_path")"
  else
    read -r -p "Domain name (e.g. example.com): " DOMAIN
    [[ -n "${DOMAIN// }" ]] || die "Domain name is required."

    echo "Fetching public IP..."
    MY_IP="$(fetch_public_ip)"
    [[ -n "$MY_IP" ]] || die "Could not determine public IP."
    echo "This machine's public IP: $MY_IP"

    echo "Checking that $DOMAIN resolves to $MY_IP ..."
    if ! domain_resolves_to_ip "$DOMAIN" "$MY_IP"; then
      die "DNS for '$DOMAIN' does not resolve to $MY_IP. Fix DNS (A record) and try again."
    fi
    echo "DNS check passed."

    read -r -p "Email (for ACME / Let's Encrypt): " EMAIL
    [[ -n "${EMAIL// }" ]] || die "Email is required."

    read -r -p "Proxy username: " PROXY_USER
    [[ -n "${PROXY_USER// }" ]] || die "Proxy username is required."

    read -r -s -p "Proxy password: " PROXY_PASS
    echo
    [[ -n "$PROXY_PASS" ]] || die "Proxy password is required."

    TMP_CADDY="$(mktemp)"
    write_caddyfile "$DOMAIN" "$EMAIL" "$PROXY_USER" "$PROXY_PASS" "$TMP_CADDY"
    mv "$TMP_CADDY" "$caddyfile_path"
    chmod 0644 "$caddyfile_path"
  fi

  echo "Downloading static index.html..."
  download_to "https://raw.githubusercontent.com/nginx/nginx/5eaf45f11e85459b52c18f876e69320df420ae29/docs/html/index.html" \
    /var/www/html/index.html
  chmod 0644 /var/www/html/index.html

  CADDY_RELEASE_URL="https://github.com/klzgrad/forwardproxy/releases/download/v2.10.0-naive/caddy-forwardproxy-naive.tar.xz"
  CADDY_DIR="/opt/caddy-forwardproxy-naive"
  mkdir -p "$CADDY_DIR"

  TMP_TAR="$(mktemp)"
  echo "Downloading Caddy (forwardproxy naive)..."
  download_to "$CADDY_RELEASE_URL" "$TMP_TAR"
  tar -xJf "$TMP_TAR" -C "$CADDY_DIR"
  rm -f "$TMP_TAR"

  CADDY_BIN="$(find "$CADDY_DIR" -type f \( -name caddy -o -name caddy.exe \) | head -n1)"
  [[ -n "$CADDY_BIN" ]] || die "Could not find caddy binary after extracting archive."
  chmod +x "$CADDY_BIN"

  show_share_link_and_qr

  echo "Starting Caddy: $CADDY_BIN run --config /etc/caddy/Caddyfile"
  cd "$(dirname "$CADDY_BIN")"
  exec "$CADDY_BIN" run --config /etc/caddy/Caddyfile
}

main "$@"
