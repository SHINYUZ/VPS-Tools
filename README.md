# VPS-Tools

![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)
![Language](https://img.shields.io/badge/language-Shell-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)

VPS-Tools 是一个 VPS 常用管理工具箱，集成系统维护、SSH 管理、网络设置、DD 重装、脚本合集与测试脚本入口。

---

## 功能特性

- 系统管理
  - 系统信息查询
  - 系统更新
  - 系统清理
  - 系统必备工具安装
  - 虚拟内存 Swap 管理
  - 系统时区、主机名、更新源管理
  - 定时任务管理

- SSH 与安全
  - 修改登录密码
  - 修改登录密钥
  - 密码登录模式切换
  - 修改 SSH 连接端口
  - 重启 SSH
  - 开放所有端口
  - 查看端口占用状态
  - 禁止 Ping

- 网络与系统增强
  - BBR+FQ 加速
  - IPv4 / IPv6 优先级切换
  - 禁用 / 恢复 IPv6
  - 限流自动关机

- 脚本合集
  - Singbox 脚本
  - 转发脚本
  - 流量限额脚本
  - Caddy 反代脚本
  - Docker 管理脚本
  - WARP 管理

- DD 重装
  - DD 纯净版
  - DD 最强版
  - Nat-DD 版

- 测试脚本合集
  - IP 与解锁检测
  - 回程路由测试
  - 网络测速
  - 性能测试
  - NodeQuality 综合测试

---

## 安装

复制并执行以下命令：

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/SHINYUZ/VPS-Tools/main/tools.sh && chmod +x tools.sh && ./tools.sh
```

如果下载失败，请检查 VPS 网络连接或 DNS 设置。

使用镜像加速源下载：

```bash
wget -N --no-check-certificate https://ghproxy.net/https://raw.githubusercontent.com/SHINYUZ/VPS-Tools/main/tools.sh && chmod +x tools.sh && ./tools.sh
```

---

## 快捷指令

首次运行脚本后，默认会自动设置快捷指令：

```bash
st
```

之后直接输入 `st` 即可打开工具箱。

---

## 主菜单

```text
Shinyuz Tools v1.0.0

命令行输入 st 可快速启动脚本

------------------------

1. 系统信息查询

2. 系统更新

3. 系统清理

4. 脚本合集

5. 测试脚本合集

6. 系统工具

7. 脚本管理

------------------------

0. 退出脚本
```

---

## 环境要求

- 系统: Debian / Ubuntu / CentOS / Alpine 等主流 Linux 发行版
- 权限: 建议使用 root 用户运行
- 架构: AMD64 / ARM64

---

## 免责声明

1. 本脚本仅供学习交流与服务器管理使用，请勿用于非法用途。
2. 使用本脚本造成的任何损失，包括但不限于数据丢失、服务器无法连接、服务异常等，作者不承担责任。
3. 执行 DD 重装、SSH 配置、防火墙、密钥、端口等功能前，请确认你理解对应操作的影响。

---

## 开源协议

本项目遵循 GPL-3.0 License 协议开源。

Copyright (c) 2026 Shinyuz
