# sing-box-armv7-crypto

适用于 **高通 IPQ60xx (IPQ6018 / IPQ6000 / 亚瑟 AX1800 Pro / 兆能 ZN-M2 等)** 32 位嵌入式 Linux / OpenWrt 系统的 `sing-box` 硬件优化自动化编译工作流。

---

## 背景与设计目标

高通 IPQ6018 是一颗 **4 核 64 位 Cortex-A53** 处理器，硬件上完整具备 **ARMv8 Cryptography Extensions (AESE, AESD, PMULL, SHA1, SHA256)** 硬件加速指令。但在许多原厂和第三方固件中，系统运行在 **32 位模式（armv7l / AArch32）** 下。

官方分发的预编译 `sing-box` 在 32 位模式（`GOARCH=arm`）下因 Go 标准库缺乏 32 位 ARM AES 汇编，强制退回到纯软件查表模拟（单核吞吐仅约 15~20 MB/s），导致跑大流量代理时 CPU 负载居高不下。

本项目利用 GitHub Actions，提供专为该类设备优化的构建方案：
1. **`sing-box-linux-armv7-crypto`**：通过 CGO + Zig Musl 交叉编译工具链，针对 `-march=armv8-a+crypto` 进行硬件指令加速构建，纯静态链接，完美适配 OpenWrt Musl 环境。
2. **`sing-box-linux-armv7-static`**：纯 Go 静态编译，激活 `GOARM=7` VFP 硬件浮点优化。

---

## 包含构建特性 (Build Tags)

默认包含 ShellCrash 所需的全部协议支持：
```
with_quic,with_dhcp,with_wireguard,with_shadowsocks,with_vless,with_trojan,with_clash_api,with_utls
```

---

## 如何在 GitHub Actions 运行编译

1. Fork 或克隆本仓库。
2. 进入仓库的 **Actions** 标签页。
3. 选择 **`Build sing-box with ARMv8 Hardware Crypto for ARMv7`** 工作流。
4. 点击 **Run workflow**：
   - 可在输入框指定任意 `sing-box` 官方版本标签（如 `v1.13.21`、`v1.14.4`）。
5. 编译完成后，直接在 **Releases** 或 **Artifacts** 中下载打包好的 `.tar.gz` 文件。

---

## 路由器部署方法（配合 ShellCrash）

下载编译产物解压后，重命名为 `CrashCore` 并推送到路由器：

```bash
# 停止当前运行的 ShellCrash 服务
/etc/init.d/ShellCrash stop

# 替换内核文件
cp sing-box-linux-armv7-crypto /etc/ShellCrash/CrashCore
chmod +x /etc/ShellCrash/CrashCore

# 重启 ShellCrash 服务
/etc/init.d/ShellCrash start
```
