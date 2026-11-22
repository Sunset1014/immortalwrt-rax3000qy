#!/bin/bash
#
# DIY script part 2 — runs after `feeds install`
# 1. Enables WiFi (ath11k) on CMCC RAX3000Q/QY via a device-tree patch:
#    - flips &q6v5_wcss / &wifi / &wifi1 to "okay"
#    - adds NVMEM calibration-data cells pointing into the ART partition
#      (2.4G at offset 0x1000, 5G QCN6102 at offset 0x26800 — offsets taken
#      from the stock read_caldata_to_fs.sh script for the ap-mp02.1 board)
#    - reserves the remaining Q6/WiFi DDR window (0x4cb00000-0x4e400000)
#      that the stock firmware also keeps off-limits to the kernel
# 2. Registers a board file (built from the stock BDF blobs bdwlan.b24 /
#    bdwlan.b60 with ath11k-bdencoder) as ipq-wifi-cmcc_rax3000q
#

set -e

GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-$(dirname "$0")}"

# ---- 1. Device-tree patch ----
patch -p1 < "$GITHUB_WORKSPACE/patches/001-enable-wifi-rax3000q.patch"

# ---- 2. ipq-wifi board file ----
mkdir -p package/firmware/ipq-wifi/files
cp "$GITHUB_WORKSPACE"/board-files/board-cmcc_rax3000q.* package/firmware/ipq-wifi/files/

python3 - <<'EOF'
path = 'package/firmware/ipq-wifi/Makefile'
s = open(path).read()
if 'cmcc_rax3000q' not in s:
    before = s
    s = s.replace(
        '\tcmcc_rm2-6 \\\n',
        '\tcmcc_rax3000q \\\n\tcmcc_rm2-6 \\\n', 1)
    s = s.replace(
        '$(eval $(call generate-ipq-wifi-package,cmcc_mr3000d-ci,CMCC MR3000D-CI))',
        '$(eval $(call generate-ipq-wifi-package,cmcc_mr3000d-ci,CMCC MR3000D-CI))\n'
        '$(eval $(call generate-ipq-wifi-package,cmcc_rax3000q,CMCC RAX3000Q))', 1)
    if s == before:
        raise SystemExit('ERROR: ipq-wifi Makefile anchors not found - upstream layout changed')
    open(path, 'w').write(s)
print('ipq-wifi Makefile updated')
EOF

grep -n 'cmcc_rax3000q' package/firmware/ipq-wifi/Makefile

# ---- 3. Trim target default packages for the 256 MiB RAM budget ----
# - wpad-openssl -> wpad-basic-mbedtls (keeps WPA2/WPA3-PSK, drops 802.11r/k/v)
# - drop USB3 stack and automount (this board has no USB ports)
python3 - <<'EOF'
path = 'target/linux/qualcommax/Makefile'
s = open(path).read()
before = s
s = s.replace('\tkmod-usb3 kmod-usb-dwc3 kmod-usb-dwc3-qcom \\\n', '', 1)
s = s.replace('\tautomount cpufreq', '\tcpufreq', 1)
s = s.replace('wpad-openssl', 'wpad-basic-mbedtls', 1)
if s == before:
    raise SystemExit('ERROR: qualcommax Makefile anchors not found - upstream layout changed')
open(path, 'w').write(s)
print('qualcommax DEFAULT_PACKAGES trimmed')
EOF

grep -A6 'DEFAULT_PACKAGES' target/linux/qualcommax/Makefile
