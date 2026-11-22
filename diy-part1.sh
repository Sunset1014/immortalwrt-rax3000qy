#!/bin/bash
#
# DIY script part 1 — runs before `feeds update`
# Registers the homeproxy feed (sing-box based proxy for ImmortalWrt).
#

set -e

# Avoid duplicates on rebuilds
sed -i '/homeproxy/d' feeds.conf.default || true

cat >> feeds.conf.default <<'EOF'
src-git homeproxy https://github.com/immortalwrt/homeproxy.git
EOF

cat feeds.conf.default
