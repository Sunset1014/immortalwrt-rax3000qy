# ImmortalWrt for CMCC RAX3000Q / RAX3000QY

基于 **ImmortalWrt master**（主线内核 6.18，qualcommax/ipq50xx 平台）为
中国移动 **CMCC RAX3000Q / RAX3000QY** 编译的固件。GitHub Actions 云端编译，
产物自动上传到 Release / Artifacts。

## 设备硬件

| 部件 | 规格 |
|---|---|
| SoC | 高通 IPQ5000/IPQ5018，双核 Cortex-A53 @1.008GHz |
| 内存 | 256 MiB（SoC 集成） |
| 闪存 | 128 MiB SPI NAND（GigaDevice GD5F1GQ5，Dosilicon 变体不支持） |
| 有线 | QCA8337 千兆交换，1 WAN + 3 LAN |
| 无线 | 2.4G（SoC 内置）+ 5G（QCN6102），Wi-Fi 6 |
| 串口 | 3-pin TTL，115200n8 |

## 本固件相对官方 snapshot 的改动

官方主线（2026-07 起）已支持 `cmcc_rax3000q`，但**因 256 MiB 内存会把
ath11k（WiFi 驱动）挤爆 OOM 而禁用了无线**。本仓库通过以下手段启用无线：

1. **设备树补丁**（`patches/001-enable-wifi-rax3000q.patch`）：
   - 将 `&q6v5_wcss` / `&wifi` / `&wifi1` 置为 `okay`
   - 新增 NVMEM 校准数据单元，直接从 ART 分区读取**本机逐台校准数据**：
     2.4G 在 ART+0x1000、5G 在 ART+0x26800，各 128KiB（偏移取自原厂
     `read_caldata_to_fs.sh` 对 ap-mp02.1 平台的处理逻辑）
   - 补齐 Q6/WiFi 静态内存窗口保留（0x4cb00000-0x4e400000，no-map），
     与原厂固件的保留范围一致，防止内核与无线固件内存互踩
2. **板级数据包 `ipq-wifi-cmcc_rax3000q`**：用 `ath11k-bdencoder` 从原厂
   `wifi_fw` 分区的 BDF（`bdwlan.b24` / `bdwlan.b60`，即 QMI 报告的
   board_id 0x24/0x60）生成的 board-2.bin
3. **内存减压**：zram-swap 128MiB 压缩交换、精简版 `wpad-basic-mbedtls`
   （保留 WPA2/WPA3-PSK）、精简 LuCI 应用列表

> ⚠️ 256 MiB 内存跑主线 ath11k 是社区尚未充分验证的组合。若实测出现
> OOM/无线崩溃重启，可：关闭其中一个无线频段、减包，或改用官方
> 禁用无线的稳定版本。ART 分区与本固件的任何分区互不影响，可随时
> 通过 Breed 刷回官方固件。

## 固件包清单

- LuCI（中文界面）+ 官方默认组件
- luci-app-homeproxy（sing-box 内核代理，当前最轻量的活跃多协议方案）
- luci-app-sqm（智能队列/抗缓冲膨胀）+ luci-app-upnp
- zram-swap（128MiB）、kmod-tcp-bbr、PPPoE、IPv6 全栈
- 预置：nftables 软件流量加速（flow offload）、BBR+fq、WiFi 国家码 CN

## 刷机（Breed/NWrt uboot）

1. 电脑设静态 IP `192.168.1.2`，掩码 `255.255.255.0`
2. 路由器断电 → 按住 reset → 通电 10 秒松开 → 浏览器进 `192.168.1.1`
3. 刷入 Release 里的 **`immortalwrt-qualcommax-ipq50xx-cmcc_rax3000q-squashfs-factory.ubi`**
   （选择"固件/UBI"入口）
4. 等待重启后 LAN 口访问 `192.168.1.1`（LuCI，root 无密码，请立即设置）

> 分区表为 NWrt 改造后的单 rootfs 大分区布局（112MiB），固件约 15MiB，
> 空间充裕。原厂 A/B 双分区布局的机器请勿直接刷 `.ubi`（先确认 Breed/
> uboot 的分区表来源）。

## 首次开机建议

1. LuCI → 系统 → 管理权限：设置 root 密码
2. 网络 → 无线：创建 SSID 并设密码（国家码已预置 CN）
3. 网络 → 接口：WAN 配置拨号（PPPoE）或 DHCP
4. 如需 NAT1（游戏联机）：防火墙 → 常规设置 → 勾选 Full-Cone

## 编译

GitHub Actions 手动触发（`workflow_dispatch`，Release 上传默认开启），
单次约 2.5–4 小时。结构：

```
.config            设备与包选择（256MiB 内存精简版）
diy-part1.sh       注册 homeproxy feed
diy-part2.sh       打 WiFi 设备树补丁 + 注入 ipq-wifi 板文件
patches/           设备树补丁
board-files/       原厂 BDF 生成的 board-2.bin
files/             首次开机预置（uci-defaults / sysctl）
```

## 参考

- 上游支持提交：immortalwrt/immortalwrt@d592680c（CMCC RAX3000Q/QY）
- 校准数据偏移来源：原厂固件 `read_caldata_to_fs.sh`（ap-mp02.1 分支）
- 社区：hzyitc/openwrt-redmi-ax3000、sfxfs/rax3000qy-OpenWrt、
  kkstone/Actions-OpenWrt-RAX3000Q
