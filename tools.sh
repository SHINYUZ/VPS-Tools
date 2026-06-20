#!/usr/bin/env bash

set -u

sh_v="1.0.0"
SCRIPT_TITLE="Shinyuz Tools"
DEFAULT_CMD="st"

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'

sep() {
  echo -e "${gl_kjlan}------------------------${gl_bai}"
}

info_sep() {
  printf '%s\n\n' "$(printf '%*s' 53 '' | tr ' ' '-')"
}

info_line() {
  local label="$1:"
  local value="$2"
  printf '%b%s%b' "${gl_kjlan}" "$label" "${gl_bai}"
  printf '\033[17G'
  printf '%s\n\n' "$value"
}

pause() {
  echo
  read -r -p "按回车键继续..."
}

ok() {
  echo
  echo -e "${gl_lv}$*${gl_bai}"
}

warn() {
  echo
  echo -e "${gl_huang}$*${gl_bai}"
}

err() {
  echo
  echo -e "${gl_hong}$*${gl_bai}"
}

confirm() {
  local prompt="${1:-确定继续吗？}"
  local answer
  echo
  read -r -p "$prompt [Y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

menu_prefix() {
  local no="$1"
  if (( no >= 10 )); then
    printf "%s." "$no"
  else
    printf "%s. " "$no"
  fi
}

menu_line() {
  local left_no="$1"
  local left_text="$2"
  local right_no="${3:-}"
  local right_text="${4:-}"
  local left_prefix
  left_prefix="$(menu_prefix "$left_no")"

  printf "${gl_kjlan}%s${gl_bai}%s${gl_bai}\n\n" "$left_prefix" "$left_text"

  if [[ -n "$right_no" ]]; then
    local right_prefix
    right_prefix="$(menu_prefix "$right_no")"
    printf "${gl_kjlan}%s${gl_bai}%s${gl_bai}\n\n" "$right_prefix" "$right_text"
  fi
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "提示: 该功能需要 root 用户才能运行！"
    return 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

format_bytes() {
  awk -v bytes="${1:-0}" 'BEGIN {
    if (bytes >= 1099511627776) printf "%.2f TB", bytes / 1099511627776;
    else if (bytes >= 1073741824) printf "%.2f GB", bytes / 1073741824;
    else if (bytes >= 1048576) printf "%.2f MB", bytes / 1048576;
    else if (bytes >= 1024) printf "%.2f KB", bytes / 1024;
    else printf "%d B", bytes;
  }'
}

detect_pm() {
  if command_exists apt; then echo "apt"
  elif command_exists dnf; then echo "dnf"
  elif command_exists yum; then echo "yum"
  elif command_exists pacman; then echo "pacman"
  elif command_exists apk; then echo "apk"
  elif command_exists zypper; then echo "zypper"
  else echo ""
  fi
}

install_pkg() {
  local pm
  pm="$(detect_pm)"
  if [[ -z "$pm" ]]; then
    err "未识别包管理器，无法安装: $*"
    return 1
  fi

  case "$pm" in
    apt) apt update && apt install -y "$@" ;;
    dnf) dnf install -y "$@" ;;
    yum) yum install -y "$@" ;;
    pacman) pacman -Sy --noconfirm "$@" ;;
    apk) apk add --no-cache "$@" ;;
    zypper) zypper --non-interactive install "$@" ;;
  esac
}

restart_service() {
  local svc="$1"
  if command_exists systemctl; then
    systemctl restart "$svc"
  elif command_exists service; then
    service "$svc" restart
  else
    warn "未找到 systemctl/service，请手动重启 $svc"
  fi
}

set_sshd_option() {
  local option="$1"
  local value="$2"
  local config="${3:-/etc/ssh/sshd_config}"

  sed -i "/^[#[:space:]]*${option}[[:space:]]/d" "$config"
  printf '%s %s\n' "$option" "$value" >> "$config"
}

enable_service() {
  local svc="$1"
  if command_exists systemctl; then
    systemctl enable --now "$svc"
  elif command_exists service; then
    service "$svc" start
  fi
}

script_header() {
  clear
  echo -e "${gl_kjlan}"
  echo " _____           _       "
  echo "|_   _|__   ___ | |___   "
  echo "  | |/ _ \ / _ \| / __|  "
  echo "  | | (_) | (_) | \__ \  "
  echo "  |_|\___/ \___/|_|___/  "
  echo
  echo -e "${SCRIPT_TITLE} v$sh_v${gl_bai}"
  echo
  echo -e "${gl_kjlan}命令行输入 ${gl_huang}${DEFAULT_CMD}${gl_kjlan} 可快速启动脚本${gl_bai}"
  echo
}

main_menu() {
  while true; do
    script_header
    sep
    echo
    menu_line 1 "系统信息查询"
    menu_line 2 "系统更新"
    menu_line 3 "系统清理"
    menu_line 4 "脚本合集"
    menu_line 5 "测试脚本合集"
    menu_line 6 "系统工具"
    menu_line 7 "脚本管理"
    sep
    echo
    menu_line 0 "退出脚本"
    sep
    echo
    read -r -p "请输入你的选择: " choice

    case "$choice" in
      1) system_info; pause ;;
      2) clear; system_update; pause ;;
      3) clear; system_clean; pause ;;
      4) script_collection_menu ;;
      5) test_menu ;;
      6) settings_menu ;;
      7) script_manage_menu ;;
      0) clear; exit 0 ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

system_info() {
  clear
  echo -e "${gl_kjlan}正在查询系统信息...${gl_bai}"

  if ! command_exists curl; then
    echo
    echo -e "${gl_huang}未检测到 curl，正在自动安装...${gl_bai}"
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
      install_pkg curl ca-certificates || true
    elif command_exists sudo; then
      local pm
      pm="$(detect_pm)"
      case "$pm" in
        apt) sudo apt update && sudo apt install -y curl ca-certificates ;;
        dnf) sudo dnf install -y curl ca-certificates ;;
        yum) sudo yum install -y curl ca-certificates ;;
        pacman) sudo pacman -Sy --noconfirm curl ca-certificates ;;
        apk) sudo apk add --no-cache curl ca-certificates ;;
        zypper) sudo zypper --non-interactive install curl ca-certificates ;;
      esac || true
    fi
  fi

  local cpu_info cpu_usage cpu_cores cpu_freq mem_info disk_info load dns_addresses
  local cpu_arch hostname kernel_version os_info current_time swap_info runtime timezone
  local tcp_count udp_count ipv4_address ipv6_address congestion_algorithm queue_algorithm
  local rx_bytes tx_bytes rx tx ipinfo country city isp_info

  cpu_info="$(lscpu 2>/dev/null | awk -F': +' '/Model name:/ {print $2; exit}')"
  cpu_info="${cpu_info:-Unknown}"
  cpu_usage="$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else if (t>t1) printf "%.0f\n", ((u-u1) * 100 / (t-t1));}' <(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat) 2>/dev/null)"
  cpu_usage="${cpu_usage:-0}"
  cpu_cores="$(nproc 2>/dev/null || echo Unknown)"
  cpu_freq="$(awk -F': ' '/cpu MHz/ {printf "%.1f GHz\n", $2/1000; exit}' /proc/cpuinfo 2>/dev/null)"
  cpu_freq="${cpu_freq:-Unknown}"
  mem_info="$(free -b | awk 'NR==2{printf "%.2f/%.2fM (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
  disk_info="$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
  load="$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')"
  dns_addresses="$(awk '/^nameserver/{printf "%s ", $2} END{print ""}' /etc/resolv.conf 2>/dev/null)"
  cpu_arch="$(uname -m)"
  hostname="$(hostname)"
  kernel_version="$(uname -r)"
  os_info="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Unknown}")"
  current_time="$(date '+%Y-%m-%d %I:%M %p')"
  swap_info="$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) percentage=0; else percentage=used*100/total; printf "%dM/%dM (%d%%)", used, total, percentage}')"
  runtime="$(awk -F. '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); if(d>0) printf "%d天", d; if(h>0) printf "%d小时", h; printf "%d分钟\n", m}' /proc/uptime 2>/dev/null)"
  timezone="$(date +%Z)"
  tcp_count="$(ss -t 2>/dev/null | wc -l || echo 0)"
  udp_count="$(ss -u 2>/dev/null | wc -l || echo 0)"
  congestion_algorithm="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo Unknown)"
  queue_algorithm="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo Unknown)"
  read -r rx_bytes tx_bytes < <(
    awk -F'[: ]+' 'NR>2 && $1!="lo" {rx+=$3; tx+=$11} END {print rx+0, tx+0}' /proc/net/dev 2>/dev/null
  )
  rx="$(format_bytes "${rx_bytes:-0}")"
  tx="$(format_bytes "${tx_bytes:-0}")"

  if command_exists curl; then
    ipv4_address="$(curl -4 -s --max-time 3 https://api.ipify.org || true)"
    ipv6_address="$(curl -6 -s --max-time 3 https://api64.ipify.org || true)"
    ipinfo="$(curl -4 -s --max-time 5 https://ipinfo.io/json || true)"
    country="$(printf '%s\n' "$ipinfo" | sed -n 's/.*"country":[[:space:]]*"\([^"]*\)".*/\1/p')"
    city="$(printf '%s\n' "$ipinfo" | sed -n 's/.*"city":[[:space:]]*"\([^"]*\)".*/\1/p')"
    isp_info="$(printf '%s\n' "$ipinfo" | sed -n 's/.*"org":[[:space:]]*"\([^"]*\)".*/\1/p')"
  fi
  country="${country:-Unknown}"
  city="${city:-Unknown}"
  isp_info="${isp_info:-Unknown}"

  clear
  echo -e "系统信息查询"
  echo
  info_sep
  info_line "主机名" "$hostname"
  info_line "系统版本" "${os_info:-Unknown}"
  info_line "Linux版本" "$kernel_version"
  info_sep
  info_line "CPU架构" "$cpu_arch"
  info_line "CPU型号" "$cpu_info"
  info_line "CPU核心数" "$cpu_cores"
  info_line "CPU频率" "$cpu_freq"
  info_sep
  info_line "CPU占用" "$cpu_usage%"
  info_line "系统负载" "${load:-Unknown}"
  info_line "TCP|UDP连接数" "$tcp_count|$udp_count"
  info_line "物理内存" "$mem_info"
  info_line "虚拟内存" "$swap_info"
  info_line "硬盘占用" "$disk_info"
  info_sep
  info_line "总接收" "$rx"
  info_line "总发送" "$tx"
  info_sep
  info_line "网络算法" "$congestion_algorithm $queue_algorithm"
  info_sep
  info_line "运营商" "$isp_info"
  [[ -n "${ipv4_address:-}" ]] && info_line "IPv4地址" "$ipv4_address"
  [[ -n "${ipv6_address:-}" ]] && info_line "IPv6地址" "$ipv6_address"
  info_line "DNS地址" "${dns_addresses:-Unknown}"
  info_line "地理位置" "$country $city"
  info_line "系统时间" "$timezone $current_time"
  info_sep
  info_line "运行时长" "${runtime:-Unknown}"
}

system_update() {
  need_root || return
  echo "系统更新"
  echo
  sep
  echo
  local pm
  pm="$(detect_pm)"
  case "$pm" in
    apt) apt update && apt upgrade -y ;;
    dnf) dnf upgrade -y ;;
    yum) yum update -y ;;
    pacman) pacman -Syu --noconfirm ;;
    apk) apk update && apk upgrade ;;
    zypper) zypper refresh && zypper --non-interactive update ;;
    *) err "未识别包管理器" ;;
  esac
}

system_clean() {
  need_root || return
  echo "系统清理"
  echo
  sep
  echo
  local pm
  pm="$(detect_pm)"
  case "$pm" in
    apt) apt autoremove -y; apt autoclean -y; apt clean ;;
    dnf) dnf autoremove -y; dnf clean all ;;
    yum) yum autoremove -y 2>/dev/null || true; yum clean all ;;
    pacman) pacman -Sc --noconfirm ;;
    apk) rm -rf /var/cache/apk/* ;;
    zypper) zypper clean --all ;;
    *) warn "未识别包管理器，跳过包缓存清理" ;;
  esac
  journalctl --vacuum-time=7d >/dev/null 2>&1 || true
  ok "系统清理完成"
}

settings_menu() {
  while true; do
    clear
    echo -e "系统工具"
    echo
    sep
    echo
    menu_line 1 "设置脚本启动快捷键"
    menu_line 2 "用户密码登录模式"
    menu_line 3 "修改登录密码"
    menu_line 4 "修改登录密钥"
    menu_line 5 "修改SSH连接端口"
    menu_line 6 "重启SSH"
    menu_line 7 "开放所有端口"
    menu_line 8 "查看端口占用状态"
    sep
    echo
    menu_line 9 "修改虚拟内存大小"
    menu_line 10 "系统时区调整"
    menu_line 11 "修改主机名"
    menu_line 12 "切换系统更新源"
    menu_line 13 "定时任务管理"
    sep
    echo
    menu_line 14 "系统必备"
    menu_line 15 "优先IPV4/IPV6"
    menu_line 16 "禁止Ping"
    menu_line 17 "DD纯净版"
    menu_line 18 "DD最强版"
    menu_line 19 "Nat-DD版"
    menu_line 20 "限流自动关机"
    menu_line 21 "安装Python指定版本"
    sep
    echo
    menu_line 0 "返回主菜单"
    sep
    echo
    read -r -p "请输入你的选择: " sub_choice

    case "$sub_choice" in
      1) set_shortcut; pause ;;
      2) password_login_mode; pause ;;
      3) change_password; pause ;;
      4) change_ssh_key; pause ;;
      5) change_ssh_port; pause ;;
      6) restart_ssh; pause ;;
      7) open_all_ports; pause ;;
      8) port_status; pause ;;
      9) swap_menu ;;
      10) timezone_menu; pause ;;
      11) change_hostname; pause ;;
      12) switch_mirror; pause ;;
      13) cron_menu ;;
      14) install_system_essentials; pause ;;
      15) ip_priority_menu ;;
      16) ping_manage_menu ;;
      17) dd_clean_reinstall ;;
      18) dd_strong_reinstall ;;
      19) nat_dd_reinstall ;;
      20) limit_shutdown_menu ;;
      21) install_python_version; pause ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

restart_ssh() {
  clear
  echo "重启SSH"
  echo
  sep
  if command_exists sudo; then
    sudo systemctl restart ssh || sudo systemctl restart sshd || service ssh restart || service sshd restart
  else
    systemctl restart ssh || systemctl restart sshd || service ssh restart || service sshd restart
  fi
  ok "SSH 已重启"
}

install_system_essentials() {
  need_root || return
  clear
  echo "系统必备"
  echo
  sep
  if ! command_exists apt; then
    err "当前系统不支持 apt"
    return 1
  fi
  echo
  if apt update && apt install -y curl sudo nano unzip wget; then
    ok "系统必备工具安装完成"
  else
    err "系统必备工具安装失败"
    return 1
  fi
}

enable_ping_block() {
  need_root || return
  clear
  echo "启动禁止Ping"
  echo
  sep
  printf '%s\n' 'net.ipv4.icmp_echo_ignore_all = 1' > /etc/sysctl.d/99-tools-disable-ping.conf
  if [[ -e /proc/sys/net/ipv6/icmp/echo_ignore_all ]]; then
    printf '%s\n' 'net.ipv6.icmp.echo_ignore_all = 1' >> /etc/sysctl.d/99-tools-disable-ping.conf
  fi

  if ! sysctl -w net.ipv4.icmp_echo_ignore_all=1 >/dev/null 2>&1; then
    err "禁止Ping设置失败"
    return 1
  fi

  if [[ -e /proc/sys/net/ipv6/icmp/echo_ignore_all ]]; then
    sysctl -w net.ipv6.icmp.echo_ignore_all=1 >/dev/null 2>&1 || true
  fi
  ok "禁止Ping成功"
}

disable_ping_block() {
  need_root || return
  clear
  echo "关闭禁止Ping"
  echo
  sep
  rm -f /etc/sysctl.d/99-tools-disable-ping.conf

  if ! sysctl -w net.ipv4.icmp_echo_ignore_all=0 >/dev/null 2>&1; then
    err "关闭禁止Ping失败"
    return 1
  fi

  if [[ -e /proc/sys/net/ipv6/icmp/echo_ignore_all ]]; then
    sysctl -w net.ipv6.icmp.echo_ignore_all=0 >/dev/null 2>&1 || true
  fi
  ok "关闭禁止Ping成功"
}

ping_manage_menu() {
  while true; do
    local ping_status
    if [[ "$(sysctl -n net.ipv4.icmp_echo_ignore_all 2>/dev/null)" == "1" ]]; then
      ping_status="禁止Ping已启动"
    else
      ping_status="禁止Ping已关闭"
    fi

    clear
    echo "禁止Ping"
    echo
    echo -e "当前: ${gl_huang}${ping_status}${gl_bai}"
    echo
    sep
    echo
    menu_line 1 "启动禁止Ping"
    menu_line 2 "关闭禁止Ping"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) enable_ping_block; pause ;;
      2) disable_ping_block; pause ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

set_ipv6_disabled_state() {
  local value="$1"
  local setting
  local found=0

  for setting in /proc/sys/net/ipv6/conf/*/disable_ipv6; do
    [[ -e "$setting" ]] || continue
    found=1
    printf '%s\n' "$value" > "$setting" || return 1
  done

  (( found == 1 ))
}

backup_ipv6_network() {
  local backup_dir="/var/lib/shinyuz-tools"
  local address_file="$backup_dir/ipv6-addresses"
  local route_file="$backup_dir/ipv6-routes"
  local temporary_address_file
  local temporary_route_file

  temporary_address_file="$(mktemp)"
  temporary_route_file="$(mktemp)"
  ip -6 -o addr show scope global 2>/dev/null | awk '{print $2, $4}' > "$temporary_address_file"
  ip -6 route show default 2>/dev/null > "$temporary_route_file"

  if [[ -s "$temporary_address_file" ]]; then
    mkdir -p "$backup_dir"
    chmod 700 "$backup_dir"
    mv "$temporary_address_file" "$address_file"
    mv "$temporary_route_file" "$route_file"
    chmod 600 "$address_file" "$route_file"
  else
    rm -f "$temporary_address_file" "$temporary_route_file"
  fi
}

restore_ipv6_network_backup() {
  local backup_dir="/var/lib/shinyuz-tools"
  local address_file="$backup_dir/ipv6-addresses"
  local route_file="$backup_dir/ipv6-routes"
  local iface address route
  local -a route_args

  [[ -s "$address_file" ]] || return 1

  while read -r iface address; do
    [[ -n "$iface" && -n "$address" ]] || continue
    ip -6 addr replace "$address" dev "$iface" >/dev/null 2>&1 || return 1
  done < "$address_file"

  if [[ -s "$route_file" ]]; then
    while IFS= read -r route; do
      [[ -n "$route" ]] || continue
      read -r -a route_args <<< "$route"
      ip -6 route replace "${route_args[@]}" >/dev/null 2>&1 || return 1
    done < "$route_file"
  fi
}

restore_ipv6_from_interfaces() {
  local iface config_file address gateway
  iface="$(ip -4 route show default 2>/dev/null | awk 'NR==1 {print $5}')"
  [[ -n "$iface" ]] || return 1

  for config_file in /etc/network/interfaces /etc/network/interfaces.d/*; do
    [[ -f "$config_file" ]] || continue
    address="$(awk -v iface="$iface" '
      $1 == "iface" {
        active = ($2 == iface && $3 == "inet6" && $4 == "static")
        next
      }
      active && $1 == "address" { print $2; exit }
    ' "$config_file")"
    gateway="$(awk -v iface="$iface" '
      $1 == "iface" {
        active = ($2 == iface && $3 == "inet6" && $4 == "static")
        next
      }
      active && $1 == "gateway" { print $2; exit }
    ' "$config_file")"
    [[ -n "$address" ]] && break
  done

  [[ -n "$address" ]] || return 1
  ip -6 addr replace "$address" dev "$iface" >/dev/null 2>&1 || return 1

  if [[ -n "$gateway" ]]; then
    ip -6 route replace "$gateway/128" dev "$iface" >/dev/null 2>&1 || return 1
    ip -6 route replace default via "$gateway" dev "$iface" >/dev/null 2>&1 || return 1
  fi
}

reload_ipv6_network() {
  local iface
  iface="$(ip -4 route show default 2>/dev/null | awk 'NR==1 {print $5}')"
  [[ -n "$iface" ]] || iface="$(ip -o link show up 2>/dev/null | awk -F': ' '$2!="lo" {print $2; exit}')"
  [[ -n "$iface" ]] || return 1

  if command_exists nmcli && nmcli -t -f DEVICE device status 2>/dev/null | grep -Fxq "$iface"; then
    nmcli device reapply "$iface" >/dev/null 2>&1
  elif command_exists networkctl && networkctl status "$iface" >/dev/null 2>&1; then
    networkctl reconfigure "$iface" >/dev/null 2>&1
  elif command_exists netplan; then
    netplan apply >/dev/null 2>&1
  else
    return 1
  fi
}

enable_ipv4_priority() {
  need_root || return
  clear
  echo "优先IPV4"
  echo
  sep
  rm -f /etc/sysctl.d/99-tools-disable-ipv6.conf
  set_ipv6_disabled_state 0 >/dev/null 2>&1 || true
  if sed -i 's/^# *\(precedence ::ffff:0:0\/96  *100\)/\1/' /etc/gai.conf; then
    ok "优先IPV4已开启"
  else
    err "优先IPV4设置失败"
    return 1
  fi
}

enable_ipv6_priority() {
  need_root || return
  clear
  echo "优先IPV6"
  echo
  sep
  rm -f /etc/sysctl.d/99-tools-disable-ipv6.conf
  set_ipv6_disabled_state 0 >/dev/null 2>&1 || true
  if sed -i 's/^[[:space:]]*precedence[[:space:]]\+::ffff:0:0\/96[[:space:]]\+100[[:space:]]*$/# precedence ::ffff:0:0\/96  100/' /etc/gai.conf; then
    ok "优先IPV6已开启"
  else
    err "优先IPV6设置失败"
    return 1
  fi
}

disable_ipv6() {
  need_root || return
  clear
  echo "禁用IPV6"
  echo
  sep
  backup_ipv6_network
  cat > /etc/sysctl.d/99-tools-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
  if set_ipv6_disabled_state 1; then
    ok "IPV6已禁用"
  else
    err "IPV6禁用失败"
    return 1
  fi
}

restore_ipv6() {
  need_root || return
  clear
  echo "恢复IPV6"
  echo
  sep
  rm -f /etc/sysctl.d/99-tools-disable-ipv6.conf
  if set_ipv6_disabled_state 0; then
    restore_ipv6_network_backup ||
      restore_ipv6_from_interfaces ||
      reload_ipv6_network ||
      true
    local wait_count
    for wait_count in {1..15}; do
      ip -6 addr show scope global 2>/dev/null | grep -q 'inet6 ' && break
      sleep 1
    done

    if ip -6 addr show scope global 2>/dev/null | grep -q 'inet6 '; then
      ok "IPV6已恢复"
    else
      warn "IPV6开关已恢复，但暂未重新获得公网IPV6地址"
      warn "请检查服务商IPV6配置或手动重新加载当前网卡配置"
    fi
  else
    err "IPV6恢复失败"
    return 1
  fi
}

ip_priority_menu() {
  while true; do
    local current_priority
    if [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" == "1" ]]; then
      current_priority="优先IPV4（IPV6已禁用）"
    elif grep -Eq '^[[:space:]]*precedence[[:space:]]+::ffff:0:0/96[[:space:]]+100([[:space:]]|$)' /etc/gai.conf 2>/dev/null; then
      current_priority="优先IPV4"
    else
      current_priority="优先IPV6"
    fi

    clear
    echo "优先IPV4/IPV6"
    echo
    echo -e "当前: ${gl_huang}${current_priority}${gl_bai}"
    echo
    sep
    echo
    menu_line 1 "优先IPV4"
    menu_line 2 "优先IPV6"
    menu_line 3 "禁用IPV6"
    menu_line 4 "恢复IPV6"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) enable_ipv4_priority; pause ;;
      2) enable_ipv6_priority; pause ;;
      3) disable_ipv6; pause ;;
      4) restore_ipv6; pause ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

generate_dd_password() {
  local allowed_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz013456789!@#$%&*+_=.?-'
  local password
  while true; do
    password="$(LC_ALL=C tr -dc "$allowed_chars" < /dev/urandom | head -c 16)"
    [[ ${#password} -eq 16 && "$password" != *2* && "$password" =~ [^[:alnum:]] ]] && {
      printf '%s' "$password"
      return
    }
  done
}

download_reinstall_script() {
  local script_url="${1:-https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh}"
  rm -f reinstall.sh
  if ! command_exists curl && ! command_exists wget; then
    install_pkg curl wget ca-certificates || return 1
  fi
  if command_exists curl; then
    curl -fL "$script_url" -o reinstall.sh
  elif command_exists wget; then
    wget --no-check-certificate -O reinstall.sh "$script_url"
  else
    err "未找到 curl 或 wget"
    return 1
  fi

  if [[ ! -s reinstall.sh ]]; then
    err "reinstall.sh 下载失败"
    return 1
  fi
  chmod +x reinstall.sh
}

start_clean_reinstall() {
  local os_name="$1"
  local os_version="$2"
  local display_name="$3"
  local script_url="${4:-https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh}"
  local root_password confirm_password reinstall_status

  clear
  echo "$display_name"
  echo
  sep
  echo
  read -r -s -p "请输入 root 密码（直接回车随机生成）: " root_password
  if [[ -z "$root_password" ]]; then
    root_password="$(generate_dd_password)"
    echo
    echo
    echo -e "已随机生成 root 密码: ${gl_huang}$root_password${gl_bai}"
  else
    echo
    echo
    read -r -s -p "请再次输入 root 密码: " confirm_password
    echo
    if [[ "$root_password" != "$confirm_password" ]]; then
      err "两次输入的密码不一致"
      return 1
    fi
  fi

  warn "即将重装为 $display_name"
  warn "用户名固定为 root，SSH端口固定为 22"
  echo

  download_reinstall_script "$script_url" || return
  if [[ "$script_url" == *"bin456789/reinstall/main/reinstall.sh" ]]; then
    (
      set -o pipefail
      bash reinstall.sh "$os_name" "$os_version" \
        --username root \
        --password "$root_password" \
        --ssh-port 22 2>&1 | awk '
          function out(text) {
            printf "%s\r\n", text
          }
          { sub(/\r$/, "") }
          /警告：重装会清除主硬盘的所有数据，包括所有分区！/ { out($0); out(""); next }
          /^重启后开始重装。$/ {
            out("重启后开始重装，或者现在运行 \"sh reinstall.sh reset\" 以取消重装！")
            out("")
            out("输入“reboot”重启！")
            out("")
            skip_cn=1
            final_message=1
            next
          }
          skip_cn && /^或者现在运行 .* 以取消重装。$/ { skip_cn=0; next }
          /Warning: Reinstalling will erase all data on the main disk, including all partitions!/ { next }
          /Reboot to start the reinstallation./ { next }
          /Or run ".*reset" now to cancel the reinstallation./ { next }
          final_message && /^[[:space:]]*$/ { next }
          { out($0) }
        '
    )
  elif [[ "$script_url" == *"leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh" ]]; then
    bash reinstall.sh "-$os_name" "$os_version" \
      -pwd "$root_password" \
      -port 22
    echo
    exit 0
  else
    bash reinstall.sh "$os_name" "$os_version" \
      --username root \
      --password "$root_password" \
      --ssh-port 22
  fi
  reinstall_status=$?
  if (( reinstall_status == 0 )); then
    exit 0
  fi
  err "重装环境准备失败"
  return "$reinstall_status"
}

start_windows_reinstall() {
  local image_name="$1"
  local display_name="$2"
  local script_url="${3:-https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh}"
  local windows_password confirm_password reinstall_status

  clear
  echo "$display_name"
  echo
  sep
  echo
  read -r -s -p "请输入 administrator 密码（直接回车随机生成）: " windows_password
  if [[ -z "$windows_password" ]]; then
    windows_password="$(generate_dd_password)"
    echo
    echo
    echo -e "已随机生成 administrator 密码: ${gl_huang}$windows_password${gl_bai}"
  else
    echo
    echo
    read -r -s -p "请再次输入 administrator 密码: " confirm_password
    echo
    if [[ "$windows_password" != "$confirm_password" ]]; then
      err "两次输入的密码不一致"
      return 1
    fi
  fi

  warn "即将重装为 $display_name"
  warn "用户名固定为 administrator，RDP端口固定为 3389"
  echo

  download_reinstall_script "$script_url" || return
  if [[ "$script_url" == *"leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh" ]]; then
    bash reinstall.sh -windows "$image_name" \
      -pwd "$windows_password" \
      -port 22
    echo
    exit 0
  else
    bash reinstall.sh windows \
      --image-name "$image_name" \
      --lang zh-cn \
      --username administrator \
      --password "$windows_password" \
      --rdp-port 3389 \
      --ssh-port 22
  fi
  reinstall_status=$?
  if (( reinstall_status == 0 )); then
    exit 0
  fi
  err "重装环境准备失败"
  return "$reinstall_status"
}

dd_linux_menu() {
  local script_url="${1:-https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh}"
  while true; do
    clear
    echo "Linux系统"
    echo
    sep
    echo
    menu_line 1 "Debian 12"
    menu_line 2 "Debian 13"
    menu_line 3 "Ubuntu 24.04"
    menu_line 4 "Ubuntu 26.04"
    menu_line 5 "Alpine 3.23"
    menu_line 6 "Alpine 3.24"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) start_clean_reinstall "debian" "12" "Debian 12" "$script_url" ;;
      2) start_clean_reinstall "debian" "13" "Debian 13" "$script_url" ;;
      3) start_clean_reinstall "ubuntu" "24.04" "Ubuntu 24.04" "$script_url" ;;
      4) start_clean_reinstall "ubuntu" "26.04" "Ubuntu 26.04" "$script_url" ;;
      5) start_clean_reinstall "alpine" "3.23" "Alpine 3.23" "$script_url" ;;
      6) start_clean_reinstall "alpine" "3.24" "Alpine 3.24" "$script_url" ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

dd_windows_menu() {
  local script_url="${1:-https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh}"
  while true; do
    clear
    echo "Windows系统"
    echo
    sep
    echo
    menu_line 1 "Windows 10 Pro"
    menu_line 2 "Windows 11 Pro"
    menu_line 3 "Windows Server 2022 Datacenter"
    menu_line 4 "Windows Server 2025 Datacenter"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) start_windows_reinstall "Windows 10 Pro" "Windows 10 Pro" "$script_url" ;;
      2) start_windows_reinstall "Windows 11 Pro" "Windows 11 Pro" "$script_url" ;;
      3) start_windows_reinstall "Windows Server 2022 SERVERDATACENTER" "Windows Server 2022 Datacenter" "$script_url" ;;
      4) start_windows_reinstall "Windows Server 2025 SERVERDATACENTER" "Windows Server 2025 Datacenter" "$script_url" ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

dd_clean_reinstall() {
  need_root || return
  while true; do
    clear
    echo "DD纯净版"
    echo
    sep
    echo
    menu_line 1 "Linux系统"
    menu_line 2 "Windows系统"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) dd_linux_menu ;;
      2) dd_windows_menu ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

dd_strong_reinstall() {
  need_root || return
  local script_url="https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh"
  while true; do
    clear
    echo "DD最强版"
    echo
    sep
    echo
    menu_line 1 "Linux系统"
    menu_line 2 "Windows系统"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) dd_linux_menu "$script_url" ;;
      2) dd_windows_menu "$script_url" ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

nat_dd_reinstall() {
  need_root || return
  clear
  echo "Nat DD版"
  echo
  sep
  echo
  if ! command_exists curl; then
    install_pkg curl ca-certificates || return 1
  fi
  if curl -so OsMutation.sh https://raw.githubusercontent.com/LloydAsp/OsMutation/main/OsMutation.sh && chmod u+x OsMutation.sh && ./OsMutation.sh; then
    ok "Nat DD 脚本执行完成"
  else
    err "Nat DD 脚本执行失败"
    return 1
  fi
}

script_collection_menu() {
  while true; do
    clear
    echo "脚本合集"
    echo
    sep
    echo
    menu_line 1 "Singbox脚本"
    menu_line 2 "转发脚本"
    menu_line 3 "流量限额脚本"
    menu_line 4 "Caddy反代脚本"
    menu_line 5 "Docker管理脚本"
    menu_line 6 "BBR+FQ加速"
    menu_line 7 "WARP管理"
    sep
    echo
    menu_line 0 "返回主菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) launch_custom_script "Singbox脚本" "sb" 'wget -N --no-check-certificate https://raw.githubusercontent.com/SHINYUZ/sing-box/main/singbox.sh && chmod +x singbox.sh && ./singbox.sh' ;;
      2) launch_custom_script "转发脚本" "zf" 'wget -N --no-check-certificate https://raw.githubusercontent.com/Shinyuz/net-forwarder/main/forwarding.sh && chmod +x forwarding.sh && ./forwarding.sh' ;;
      3) launch_custom_script "流量限额脚本" "qo" 'wget -N --no-check-certificate "https://raw.githubusercontent.com/SHINYUZ/Quota/main/quota.sh" && chmod +x quota.sh && ./quota.sh' ;;
      4) launch_custom_script "Caddy反代脚本" "ca" 'wget -N --no-check-certificate "https://raw.githubusercontent.com/SHINYUZ/Caddy/main/caddy.sh" && chmod +x caddy.sh && ./caddy.sh' ;;
      5) launch_custom_script "Docker管理脚本" "dk" 'wget -N --no-check-certificate "https://raw.githubusercontent.com/SHINYUZ/Docker-Compose-Manager/main/docker.sh" && chmod +x docker.sh && ./docker.sh' ;;
      6) bbr_menu ;;
      7) clear; warp_menu; pause ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

script_manage_menu() {
  while true; do
    clear
    echo "脚本管理"
    echo
    sep
    echo
    menu_line 1 "更新脚本"
    menu_line 2 "卸载脚本"
    sep
    echo
    menu_line 0 "返回主菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) update_script_placeholder; pause ;;
      2) uninstall_script ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

update_script_placeholder() {
  clear
  echo "更新脚本"
  echo
  sep
  warn "更新脚本需要你的 GitHub 脚本链接。"
  echo
  warn "你提供链接后，我再把自动更新逻辑加进来。"
}

uninstall_script() {
  clear
  echo "卸载脚本"
  echo
  sep
  warn "该功能只会卸载当前 tools.sh 脚本和快捷键，不会卸载系统软件和其他配置"
  confirm "确定卸载当前脚本吗？" || return

  local script_path shortcut_path shortcut_target
  script_path="$(readlink -f "$0")"
  rm -f "/usr/local/bin/$DEFAULT_CMD" "/usr/bin/$DEFAULT_CMD" 2>/dev/null || true
  for shortcut_path in /usr/local/bin/* /usr/bin/*; do
    [[ -L "$shortcut_path" ]] || continue
    shortcut_target="$(readlink -f "$shortcut_path" 2>/dev/null || true)"
    [[ "$shortcut_target" == "$script_path" ]] && rm -f "$shortcut_path"
  done
  rm -f "$script_path"
  ok "脚本已卸载"
  exit 0
}

set_shortcut() {
  need_root || return
  clear
  read -r -p "请输入你的快捷键（输入0退出，默认 st）: " shortcut
  [[ "$shortcut" == "0" ]] && return
  shortcut="${shortcut:-$DEFAULT_CMD}"
  if [[ ! "$shortcut" =~ ^[A-Za-z0-9._-]+$ ]]; then
    err "快捷键只能包含字母、数字、点、下划线和短横线"
    return 1
  fi
  local script_path
  script_path="$(readlink -f "$0")"
  ln -sf "$script_path" "/usr/local/bin/$shortcut"
  ln -sf "$script_path" "/usr/bin/$shortcut" 2>/dev/null || true
  chmod +x "$script_path"
  ok "快捷键已设置: $shortcut"
}

auto_setup_default_shortcut() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || return

  local script_path current_target
  script_path="$(readlink -f "$0" 2>/dev/null || true)"
  [[ -n "$script_path" && -f "$script_path" ]] || return

  current_target="$(readlink -f "/usr/local/bin/$DEFAULT_CMD" 2>/dev/null || true)"
  if [[ "$current_target" == "$script_path" ]]; then
    chmod +x "$script_path" 2>/dev/null || true
    return
  fi

  ln -sf "$script_path" "/usr/local/bin/$DEFAULT_CMD" 2>/dev/null || true
  ln -sf "$script_path" "/usr/bin/$DEFAULT_CMD" 2>/dev/null || true
  chmod +x "$script_path" 2>/dev/null || true
}

generate_random_password() {
  local allowed_chars='ABDEFGHIKLOQRTUabdefghikloqrtu013456789!@#$%&*+_=.?-'
  local password
  while true; do
    password="$(LC_ALL=C tr -dc "$allowed_chars" < /dev/urandom | head -c 20)"
    [[ ${#password} -eq 20 && "$password" =~ [^[:alnum:]] ]] && {
      printf '%s' "$password"
      return
    }
  done
}

ssh_key_dir() {
  printf '%s' "/root/.ssh"
}

apply_authorized_key() {
  local public_key="$1"
  local ssh_dir authorized_keys sshd_config

  ssh_dir="$(ssh_key_dir)"
  authorized_keys="$ssh_dir/authorized_keys"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  printf '%s\n' "$public_key" > "$authorized_keys"
  chmod 600 "$authorized_keys"

  sshd_config="/etc/ssh/sshd_config"
  if [[ -f "$sshd_config" ]]; then
    sed -i 's/^[#[:space:]]*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$sshd_config"
    grep -q '^PubkeyAuthentication' "$sshd_config" || echo 'PubkeyAuthentication yes' >> "$sshd_config"
    restart_service ssh >/dev/null 2>&1 || restart_service sshd >/dev/null 2>&1 || true
  fi
}

append_authorized_key() {
  local public_key="$1"
  local ssh_dir authorized_keys sshd_config

  ssh_dir="$(ssh_key_dir)"
  authorized_keys="$ssh_dir/authorized_keys"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  touch "$authorized_keys"
  chmod 600 "$authorized_keys"

  if ! grep -Fxq "$public_key" "$authorized_keys"; then
    printf '%s\n' "$public_key" >> "$authorized_keys"
  fi

  sshd_config="/etc/ssh/sshd_config"
  if [[ -f "$sshd_config" ]]; then
    sed -i 's/^[#[:space:]]*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$sshd_config"
    grep -q '^PubkeyAuthentication' "$sshd_config" || echo 'PubkeyAuthentication yes' >> "$sshd_config"
    restart_service ssh >/dev/null 2>&1 || restart_service sshd >/dev/null 2>&1 || true
  fi
}

import_existing_ssh_key() {
  need_root || return
  clear
  echo "导入现有密钥"
  echo
  sep
  echo

  local public_key
  read -r -p "请粘贴你的SSH公钥: " public_key
  [[ -n "$public_key" ]] || return
  if [[ ! "$public_key" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]]+ ]]; then
    err "SSH公钥格式不正确"
    return 1
  fi
  append_authorized_key "$public_key"
  ok "登录密钥导入成功"
}

delete_all_ssh_keys() {
  need_root || return
  clear
  echo "删除所有密钥"
  echo
  sep
  confirm "确认删除所有登录密钥吗？" || return
  local ssh_dir authorized_keys
  ssh_dir="$(ssh_key_dir)"
  authorized_keys="$ssh_dir/authorized_keys"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  : > "$authorized_keys"
  chmod 600 "$authorized_keys"
  ok "所有登录密钥已删除"
}

generate_new_ssh_key() {
  need_root || return
  clear
  echo "随机生成新密钥"
  echo
  sep
  echo

  if ! command_exists ssh-keygen; then
    err "未找到 ssh-keygen"
    return 1
  fi

  local temp_dir key_path public_key

  temp_dir="$(mktemp -d)"
  key_path="$temp_dir/shinyuz_ed25519"
  if ! ssh-keygen -q -t ed25519 -a 100 -N "" -C "shinyuz-tools-$(date +%Y%m%d%H%M%S)" -f "$key_path"; then
    rm -rf "$temp_dir"
    err "密钥生成失败"
    return 1
  fi

  public_key="$(cat "$key_path.pub")"
  append_authorized_key "$public_key"

  echo "新的SSH私钥如下:"
  echo
  cat "$key_path"
  echo
  echo "新的SSH公钥如下:"
  echo
  cat "$key_path.pub"
  rm -rf "$temp_dir"
  ok "登录密钥修改成功"
}

change_ssh_key() {
  while true; do
    clear
    echo "修改登录密钥"
    echo
    sep
    echo
    menu_line 1 "导入现有密钥"
    menu_line 2 "随机生成新密钥"
    menu_line 3 "删除所有密钥"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) import_existing_ssh_key; pause ;;
      2) generate_new_ssh_key; pause ;;
      3) delete_all_ssh_keys; pause ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

change_password() {
  need_root || return
  clear
  echo "设置你的登录密码"
  echo
  sep
  echo
  local username first_pass second_pass
  username="${SUDO_USER:-${USER:-root}}"
  read -r -s -p "New password（直接回车随机生成）: " first_pass
  if [[ -z "$first_pass" ]]; then
    first_pass="$(generate_random_password)"
    echo
    echo
    echo -e "已随机生成密码: ${gl_huang}$first_pass${gl_bai}"
  else
    echo
    echo
    read -r -s -p "Retype new password: " second_pass
    echo
    if [[ -z "$second_pass" || "$first_pass" != "$second_pass" ]]; then
      err "密码修改失败"
      return 1
    fi
  fi
  if echo "$username:$first_pass" | chpasswd 2>/dev/null; then
    ok "密码修改成功"
  else
    err "密码修改失败"
    return 1
  fi
}

password_login_mode() {
  need_root || return
  clear
  local sshd_config="/etc/ssh/sshd_config"
  [[ -f "$sshd_config" ]] || { err "未找到 $sshd_config"; return 1; }
  echo "用户密码登录模式"
  echo
  sep
  echo
  menu_line 1 "开启密码登录" 2 "关闭密码登录"
  sep
  echo
  menu_line 0 "返回上一级菜单"
  sep
  echo
  read -r -p "请输入你的选择: " choice
  case "$choice" in
    1)
      set_sshd_option "PasswordAuthentication" "yes" "$sshd_config"
      set_sshd_option "PermitRootLogin" "yes" "$sshd_config"
      restart_service sshd || restart_service ssh
      ok "已开启密码登录"
      ;;
    2)
      confirm "关闭密码登录前，请确认你已配置 SSH 密钥登录，确定继续吗？" || return
      set_sshd_option "PasswordAuthentication" "no" "$sshd_config"
      set_sshd_option "PermitRootLogin" "prohibit-password" "$sshd_config"
      restart_service sshd || restart_service ssh
      ok "已关闭密码登录"
      ;;
    *) return ;;
  esac
}

install_python_version() {
  need_root || return
  clear
  echo "python版本管理"
  echo
  sep
  echo
  echo "该功能可安装 Python 官方支持的指定版本"
  local current_version
  current_version="$(python3 -V 2>&1 | awk '{print $2}')"
  echo
  echo -e "当前python版本号: ${gl_huang}${current_version:-未安装}${gl_bai}"
  echo
  echo "------------"
  echo
  echo "推荐版本:  3.12    3.11    3.10    3.9    3.8"
  echo
  echo "------------"
  echo
  read -r -p "输入你要安装的python版本号（输入0退出）: " version
  [[ "$version" == "0" || -z "$version" ]] && return
  [[ "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || { err "版本格式不正确"; return 1; }
  warn "该功能会安装 pyenv，并从 pyenv 官方安装脚本下载内容"
  confirm "继续安装 Python $version？" || return

  local pm
  pm="$(detect_pm)"
  case "$pm" in
    apt) install_pkg git curl build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev xz-utils tk-dev libffi-dev liblzma-dev ;;
    dnf|yum) install_pkg git curl gcc make openssl-devel bzip2-devel libffi-devel zlib-devel readline-devel sqlite-devel xz-devel ;;
    apk) install_pkg git curl bash gcc make musl-dev libffi-dev openssl-dev bzip2-dev zlib-dev readline-dev sqlite-dev xz-dev ;;
    *) err "当前系统暂未适配自动安装 pyenv 依赖"; return 1 ;;
  esac

  [[ -d "$HOME/.pyenv" ]] || curl -fsSL https://pyenv.run | bash
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - bash)"
  if ! grep -q 'PYENV_ROOT' "$HOME/.bashrc" 2>/dev/null; then
    {
      echo ''
      echo 'export PYENV_ROOT="$HOME/.pyenv"'
      echo '[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
      echo 'eval "$(pyenv init - bash)"'
    } >> "$HOME/.bashrc"
  fi
  pyenv install -s "$version"
  pyenv global "$version"
  ok "当前python版本号: $(python -V 2>&1)"
}

open_all_ports() {
  need_root || return
  clear
  echo "开放所有端口"
  echo
  sep
  warn "注意: 开放所有端口会显著降低服务器安全性"
  confirm "确定清空常见防火墙规则并开放所有端口吗？" || return
  command_exists ufw && ufw disable || true
  if command_exists firewall-cmd; then
    systemctl stop firewalld 2>/dev/null || true
    systemctl disable firewalld 2>/dev/null || true
  fi
  if command_exists iptables; then
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
  fi
  ok "端口已全部开放"
}

change_ssh_port() {
  need_root || return
  local sshd_config="/etc/ssh/sshd_config"
  [[ -f "$sshd_config" ]] || { err "未找到 $sshd_config"; return 1; }
  while true; do
    clear
    local current_port new_port
    current_port="$(awk '/^[[:space:]]*Port[[:space:]]+[0-9]+/{print $2; exit}' "$sshd_config")"
    current_port="${current_port:-22}"
    echo -e "当前的 SSH 端口号是:  ${gl_huang}$current_port ${gl_bai}"
    echo
    sep
    echo
    echo "输入0退出"
    echo
    read -r -p "请输入新的 SSH 端口号（直接回车随机生成）: " new_port
    [[ "$new_port" == "0" ]] && return
    if [[ -z "$new_port" ]]; then
      while :; do
        new_port="$((30000 + RANDOM % 30001))"
        [[ "$new_port" != *2* ]] || continue
        [[ "${new_port: -1}" != "0" ]] || continue
        [[ ! "$new_port" =~ ([0-9])\1 ]] || continue
        [[ "${new_port:0:1}" == "${new_port:4:1}" && "${new_port:1:1}" == "${new_port:3:1}" ]] && continue
        [[ "$new_port" != "$current_port" ]] || continue
        break
      done
      ok "已随机生成 SSH 端口: $new_port"
    else
      [[ "$new_port" =~ ^[0-9]+$ ]] || { err "输入无效，请输入数字"; pause; continue; }
    fi
    cp -f "$sshd_config" "${sshd_config}.bak.$(date +%Y%m%d%H%M%S)"
    if grep -qE '^[#[:space:]]*Port[[:space:]]+' "$sshd_config"; then
      sed -i "s/^[#[:space:]]*Port[[:space:]].*/Port $new_port/" "$sshd_config"
    else
      echo "Port $new_port" >> "$sshd_config"
    fi
    if command_exists sshd; then
      sshd -t || { err "sshd_config 校验失败，已停止重启"; return 1; }
    fi
    restart_service sshd || restart_service ssh
    ok "SSH端口已修改为 $new_port，请新开终端测试后再关闭当前连接"
    return
  done
}

port_status() {
  clear
  echo "查看端口占用状态"
  echo
  sep
  echo
  if command_exists ss; then
    ss -tulnape
  elif command_exists netstat; then
    netstat -tulnape
  else
    err "未找到 ss/netstat"
  fi
}

swap_menu() {
  while true; do
    clear
    echo "设置虚拟内存"
    echo
    local swap_info
    swap_info="$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) percentage=0; else percentage=used*100/total; printf "%dM/%dM (%d%%)", used, total, percentage}')"
    echo -e "当前虚拟内存: ${gl_huang}$swap_info${gl_bai}"
    echo
    sep
    echo
    menu_line 1 "分配1024M" 2 "分配2048M"
    menu_line 3 "分配4096M" 4 "自定义大小"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) set_swap 1024; pause ;;
      2) set_swap 2048; pause ;;
      3) set_swap 4096; pause ;;
      4) read -r -p "请输入虚拟内存大小（单位M）: " size; set_swap "$size"; pause ;;
      *) return ;;
    esac
  done
}

set_swap() {
  need_root || return
  local size="$1"
  [[ "$size" =~ ^[0-9]+$ ]] || { err "大小必须是数字"; return 1; }
  (( size >= 256 )) || { err "建议至少设置 256M"; return 1; }
  confirm "确认设置虚拟内存为 ${size}M？" || return
  swapoff /swapfile 2>/dev/null || true
  rm -f /swapfile
  if command_exists fallocate; then
    fallocate -l "${size}M" /swapfile
  else
    dd if=/dev/zero of=/swapfile bs=1M count="$size" status=progress
  fi
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  ok "虚拟内存已设置为 ${size}M"
}

timezone_menu() {
  need_root || return
  clear
  echo "系统时区调整"
  echo
  sep
  echo
  echo -e "当前时区: ${gl_huang}$(timedatectl 2>/dev/null | awk -F': ' '/Time zone/{print $2}')${gl_bai}"
  echo
  echo "常用时区: Asia/Shanghai  UTC  America/New_York  Europe/London"
  echo
  sep
  echo
  read -r -p "请输入时区（输入0退出）: " tz
  [[ "$tz" == "0" || -z "$tz" ]] && return
  timedatectl set-timezone "$tz"
  ok "当前时区: $(timedatectl 2>/dev/null | awk -F': ' '/Time zone/{print $2}')"
}

change_hostname() {
  need_root || return
  clear
  echo "修改主机名"
  echo
  sep
  echo
  echo -e "当前主机名: ${gl_huang}$(hostname)${gl_bai}"
  echo
  read -r -p "请输入新的主机名（输入0退出）: " new_name
  [[ "$new_name" == "0" || -z "$new_name" ]] && return
  [[ "$new_name" =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,62}$ ]] || { err "主机名格式不正确"; return 1; }
  hostnamectl set-hostname "$new_name"
  ok "主机名已更改为: $new_name"
}

switch_mirror() {
  need_root || return
  clear
  echo "切换系统更新源"
  echo
  sep
  warn "该功能会调用 linuxmirrors.cn 的换源脚本"
  confirm "确定继续切换系统更新源吗？" || return
  bash <(curl -sSL https://linuxmirrors.cn/main.sh)
}

cron_menu() {
  need_root || return
  while true; do
    clear
    echo "定时任务管理"
    echo
    sep
    echo
    crontab -l 2>/dev/null || echo "当前没有定时任务"
    echo
    sep
    echo
    menu_line 1 "添加定时任务" 2 "删除定时任务"
    menu_line 3 "编辑定时任务"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) add_cron_task; pause ;;
      2) delete_cron_task; pause ;;
      3) crontab -e; pause ;;
      *) return ;;
    esac
  done
}

add_cron_task() {
  local schedule cmd
  echo
  echo "添加定时任务"
  echo
  sep
  echo
  echo "示例: 0 3 * * * 表示每天 03:00 执行"
  echo
  read -r -p "请输入 cron 时间表达式: " schedule
  echo
  read -r -p "请输入要执行的命令: " cmd
  [[ -n "$schedule" && -n "$cmd" ]] || return
  (crontab -l 2>/dev/null; echo "$schedule $cmd") | crontab -
  ok "定时任务已添加"
}

delete_cron_task() {
  local keyword
  read -r -p "请输入需要删除任务的关键字: " keyword
  [[ -n "$keyword" ]] || return
  confirm "确认删除包含 '$keyword' 的定时任务？" || return
  crontab -l 2>/dev/null | grep -vF "$keyword" | crontab -
  ok "定时任务已删除"
}

limit_shutdown_menu() {
  need_root || return
  while true; do
    clear
    echo "限流关机功能"
    echo
    sep
    echo
    echo "当前流量使用情况，重启服务器流量计算会清零"
    echo
    awk -F'[: ]+' 'NR>2 && $1!="lo"{rx+=$3; tx+=$11} END{printf "总接收: %.2fG\n\n总发送: %.2fG\n", rx/1024/1024/1024, tx/1024/1024/1024}' /proc/net/dev
    echo
    sep
    echo
    echo "系统每分钟检测实际流量是否到达阈值，到达后会自动关闭服务器"
    echo
    sep
    echo
    menu_line 1 "开启限流关机功能" 2 "停用限流关机功能"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) enable_limit_shutdown; pause ;;
      2) disable_limit_shutdown; pause ;;
      *) return ;;
    esac
  done
}

enable_limit_shutdown() {
  local rx_gb tx_gb reset_day script_path
  echo "如果服务器有100G流量，可设置阈值为95G，提前关机避免流量溢出"
  read -r -p "请输入进站流量阈值（单位G，默认100G）: " rx_gb
  read -r -p "请输入出站流量阈值（单位G，默认100G）: " tx_gb
  read -r -p "请输入流量重置日期（默认每月1日重启，留空不设置）: " reset_day
  rx_gb="${rx_gb:-100}"
  tx_gb="${tx_gb:-100}"
  [[ "$rx_gb" =~ ^[0-9]+$ && "$tx_gb" =~ ^[0-9]+$ ]] || { err "阈值必须是数字"; return 1; }
  warn "达到阈值后会执行 shutdown -h now"
  confirm "确认开启限流关机功能吗？" || return

  script_path="/usr/local/bin/limit-shutdown-check"
  cat > "$script_path" <<EOF
#!/usr/bin/env bash
rx_limit_bytes=\$(( ${rx_gb} * 1024 * 1024 * 1024 ))
tx_limit_bytes=\$(( ${tx_gb} * 1024 * 1024 * 1024 ))
read rx_bytes tx_bytes < <(awk -F'[: ]+' 'NR>2 && \$1!="lo"{rx+=\$3; tx+=\$11} END{print rx+0, tx+0}' /proc/net/dev)
if (( rx_bytes >= rx_limit_bytes || tx_bytes >= tx_limit_bytes )); then
  logger "limit-shutdown: traffic limit reached, rx=\$rx_bytes, tx=\$tx_bytes"
  shutdown -h now
fi
EOF
  chmod +x "$script_path"
  (crontab -l 2>/dev/null | grep -vF "$script_path"; echo "* * * * * $script_path") | crontab -
  if [[ "$reset_day" =~ ^[0-9]+$ ]] && (( reset_day >= 1 && reset_day <= 28 )); then
    (crontab -l 2>/dev/null | grep -vF "monthly reboot for traffic counter"; echo "0 1 $reset_day * * /sbin/reboot # monthly reboot for traffic counter") | crontab -
  fi
  ok "限流关机已设置"
}

disable_limit_shutdown() {
  local script_path="/usr/local/bin/limit-shutdown-check"
  crontab -l 2>/dev/null | grep -vF "$script_path" | grep -vF "monthly reboot for traffic counter" | crontab -
  rm -f "$script_path"
  ok "已关闭限流关机功能"
}

bbr_menu() {
  while true; do
    clear
    local congestion_algorithm queue_algorithm
    congestion_algorithm="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo Unknown)"
    queue_algorithm="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo Unknown)"
    echo "BBR+FQ加速"
    echo
    sep
    echo
    echo -e "当前拥塞算法: ${gl_huang}$congestion_algorithm${gl_bai}"
    echo
    echo -e "当前队列算法: ${gl_huang}$queue_algorithm${gl_bai}"
    echo
    sep
    echo
    menu_line 1 "开启BBR+FQ加速"
    menu_line 2 "查看BBR+FQ状态"
    menu_line 3 "关闭BBR+FQ加速"
    sep
    echo
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) enable_bbr; pause ;;
      2) show_bbr_status; pause ;;
      3) disable_bbr; pause ;;
      0) return ;;
      *) echo "无效的输入"; pause ;;
    esac
  done
}

enable_bbr() {
  need_root || return
  if ! modprobe tcp_bbr 2>/dev/null; then
    err "当前内核不支持官方 BBR，请先升级到支持 BBR 的 Linux 内核"
    return 1
  fi
  cat > /etc/sysctl.d/99-tools-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  if sysctl --system >/dev/null 2>&1 &&
     [[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" == "bbr" ]] &&
     [[ "$(sysctl -n net.core.default_qdisc 2>/dev/null)" == "fq" ]]; then
    ok "BBR+FQ 加速已开启"
  else
    err "BBR+FQ 开启失败"
    return 1
  fi
}

show_bbr_status() {
  local congestion_algorithm queue_algorithm bbr_module
  congestion_algorithm="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo Unknown)"
  queue_algorithm="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo Unknown)"
  bbr_module="$(lsmod 2>/dev/null | awk '$1=="tcp_bbr"{print "已加载"; exit}')"
  bbr_module="${bbr_module:-未加载}"
  echo
  echo "BBR内核模块: $bbr_module"
  echo
  echo "当前拥塞算法: $congestion_algorithm"
  echo
  echo "当前队列算法: $queue_algorithm"
}

disable_bbr() {
  need_root || return
  rm -f /etc/sysctl.d/99-tools-bbr.conf
  sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1 || true
  sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1 || true
  sysctl --system >/dev/null 2>&1 || true
  ok "BBR+FQ 加速已关闭"
}

docker_menu() {
  while true; do
    clear
    echo "Docker管理"
    sep
    menu_line 1 "安装更新Docker环境"
    sep
    menu_line 2 "查看Docker全局状态"
    sep
    menu_line 3 "Docker容器管理" 4 "Docker镜像管理"
    menu_line 5 "清理无用Docker数据" 6 "卸载Docker环境"
    sep
    echo
    menu_line 0 "返回主菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) install_docker; pause ;;
      2) docker_status; pause ;;
      3) docker_container_menu ;;
      4) docker_image_menu ;;
      5) docker_prune; pause ;;
      6) uninstall_docker; pause ;;
      *) return ;;
    esac
  done
}

install_docker() {
  need_root || return
  warn "该功能会调用 Docker 官方安装脚本 get.docker.com"
  confirm "继续安装/更新 Docker 环境吗？" || return
  curl -fsSL https://get.docker.com | bash
  enable_service docker
  ok "Docker安装/更新完成"
}

docker_status() {
  clear
  echo "Docker全局状态"
  echo
  sep
  echo
  if ! command_exists docker; then err "Docker未安装"; return 1; fi
  echo "Docker版本"
  docker -v
  docker compose version 2>/dev/null || true
  echo
  echo -e "Docker镜像:"
  docker image ls
  echo
  echo -e "Docker容器:"
  docker ps -a
  echo
  echo -e "Docker卷:"
  docker volume ls
  echo
  echo -e "Docker网络:"
  docker network ls
}

docker_container_menu() {
  while true; do
    clear
    echo "Docker容器管理"
    echo
    sep
    echo
    docker ps -a 2>/dev/null || true
    sep
    menu_line 1 "启动容器" 2 "停止容器"
    menu_line 3 "重启容器" 4 "删除容器"
    menu_line 5 "查看容器日志"
    sep
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) read -r -p "容器名/ID: " n; docker start "$n"; pause ;;
      2) read -r -p "容器名/ID: " n; docker stop "$n"; pause ;;
      3) read -r -p "容器名/ID: " n; docker restart "$n"; pause ;;
      4) read -r -p "容器名/ID: " n; confirm "确定删除容器 $n 吗？" && docker rm -f "$n"; pause ;;
      5) read -r -p "容器名/ID: " n; docker logs --tail=200 "$n"; pause ;;
      *) return ;;
    esac
  done
}

docker_image_menu() {
  while true; do
    clear
    echo "Docker镜像管理"
    echo
    sep
    echo
    docker images 2>/dev/null || true
    sep
    menu_line 1 "拉取镜像" 2 "删除镜像"
    sep
    menu_line 0 "返回上一级菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) read -r -p "镜像名: " img; docker pull "$img"; pause ;;
      2) read -r -p "镜像名/ID: " img; confirm "确定删除镜像 $img 吗？" && docker rmi "$img"; pause ;;
      *) return ;;
    esac
  done
}

docker_prune() {
  need_root || return
  warn "将清理无用的镜像、容器、网络和卷，包括停止的容器"
  confirm "确定清理吗？" || return
  docker system prune -af --volumes
}

uninstall_docker() {
  need_root || return
  warn "卸载Docker环境可能删除容器、镜像、网络和卷"
  confirm "确定卸载docker环境吗？" || return
  docker ps -aq 2>/dev/null | xargs -r docker rm -f
  docker images -q 2>/dev/null | xargs -r docker rmi -f
  local pm
  pm="$(detect_pm)"
  case "$pm" in
    apt) apt remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ;;
    dnf) dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ;;
    yum) yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ;;
    apk) apk del docker docker-cli docker-compose 2>/dev/null || true ;;
  esac
}

warp_menu() {
  echo "WARP管理"
  echo
  sep
  warn "该功能会下载并运行 fscarmen/warp 的远程脚本"
  confirm "继续打开WARP管理脚本吗？" || return
  curl -fsSL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh -o /tmp/warp-menu.sh
  bash /tmp/warp-menu.sh
}

launch_custom_script() {
  local title="$1"
  local shortcut="$2"
  local install_cmd="$3"
  clear
  echo "$title"
  echo
  sep
  if command_exists "$shortcut"; then
    ok "已检测到快捷键 $shortcut，正在启动"
    "$shortcut"
    return
  fi
  warn "未检测到 $title，开始安装"
  confirm "确定安装并启动吗？" || return
  bash -c "$install_cmd"
}

test_menu() {
  while true; do
    clear
    echo "测试脚本合集"
    echo
    sep
    echo
    echo -e "${gl_kjlan}IP及解锁状态检测${gl_bai}"
    echo
    menu_line 1 "ChatGPT 解锁状态检测"
    menu_line 2 "Region 流媒体解锁测试"
    menu_line 3 "yeahwu 流媒体解锁检测"
    menu_line 4 "IP质量体检脚本"
    sep
    echo
    echo -e "${gl_kjlan}网络线路测速${gl_bai}"
    echo
    menu_line 5 "besttrace 回程路由测试"
    menu_line 6 "mtr_trace 回程线路测试"
    menu_line 7 "Superspeed 三网测速"
    menu_line 8 "nxtrace 快速回程测试"
    menu_line 9 "nxtrace 指定IP测试"
    sep
    echo
    echo -e "${gl_kjlan}硬件性能测试${gl_bai}"
    echo
    menu_line 10 "yabs 性能测试"
    sep
    echo
    echo -e "${gl_kjlan}综合性测试${gl_bai}"
    echo
    menu_line 11 "NodeQuality 综合测试"
    menu_line 12 "bench 性能测试"
    sep
    echo
    menu_line 0 "返回主菜单"
    sep
    echo
    read -r -p "请输入你的选择: " choice
    case "$choice" in
      1) run_remote "ChatGPT 解锁状态检测" "bash <(curl -Ls https://cdn.jsdelivr.net/gh/missuo/OpenAI-Checker/openai.sh)" ;;
      2) run_remote "Region 流媒体解锁测试" "bash <(curl -L -s check.unlock.media)" ;;
      3) run_remote "yeahwu 流媒体解锁检测" "wget -qO- https://github.com/yeahwu/check/raw/main/check.sh | bash" ;;
      4) run_remote "IP质量体检脚本" "bash <(curl -Ls IP.Check.Place)" ;;
      5) run_remote "besttrace 回程路由测试" "wget -qO- git.io/besttrace | bash" ;;
      6) run_remote "mtr_trace 回程线路测试" "curl https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh | bash" ;;
      7) run_remote "Superspeed 三网测速" "bash <(curl -Lso- https://git.io/superspeed_uxh)" ;;
      8) run_remote "nxtrace 快速回程测试" "curl nxtrace.org/nt | bash && nexttrace --fast-trace --tcp" "compact" ;;
      9) nxtrace_custom ;;
      10) run_remote "yabs 性能测试" "curl -sL yabs.sh | bash -s -- -i -5" ;;
      11) run_remote "NodeQuality 综合测试" "bash <(curl -sL https://run.NodeQuality.com)" ;;
      12) run_remote "bench 性能测试" "curl -Lso- bench.sh | bash" ;;
      *) return ;;
    esac
  done
}

run_remote() {
  local title="$1"
  local cmd="$2"
  local pause_mode="${3:-normal}"
  warn "$title 将执行第三方远程脚本:"
  echo
  echo "$cmd"
  confirm "确认执行吗？" || return
  echo
  bash -c "$cmd"
  if [[ "$pause_mode" == "compact" ]]; then
    read -r -p "按回车键继续..."
  else
    pause
  fi
}

nxtrace_custom() {
  local test_ip
  clear
  echo "nxtrace 指定IP测试"
  echo
  sep
  echo
  read -r -p "请输入一个指定IP: " test_ip
  [[ -n "$test_ip" ]] || return
  if [[ ! "$test_ip" =~ ^[A-Za-z0-9:.:-]+$ ]]; then
    err "IP/主机名格式不安全，已取消"
    return 1
  fi
  run_remote "nxtrace 指定IP测试" "curl nxtrace.org/nt | bash && nexttrace '$test_ip'"
}

auto_setup_default_shortcut

case "${1:-}" in
  info) system_info ;;
  update) system_update ;;
  clean) system_clean ;;
  bbr) bbr_menu ;;
  docker) docker_menu ;;
  warp) warp_menu ;;
  test) test_menu ;;
  tools) settings_menu ;;
  *) main_menu ;;
esac
