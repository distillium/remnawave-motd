#!/bin/bash

set -e

echo "Installing dependencies..."
apt-get update -qq
apt-get install -y toilet figlet procps lsb-release whiptail > /dev/null

echo "Creating MOTD config..."
CONFIG_FILE="/etc/rw-motd.conf"
cat <<EOF > "$CONFIG_FILE"
SHOW_CPU=true
SHOW_MEM=true
SHOW_NET=true
SHOW_DOCKER=true
SHOW_FIREWALL=true
EOF

echo "Installing main MOTD script..."
mkdir -p /etc/update-motd.d

cat << 'EOF' > /etc/update-motd.d/00-remnawave
#!/bin/bash

source /etc/rw-motd.conf

echo -e "\e[1;37m"
toilet -f standard -F metal "remnawave"
echo

LAST_LOGIN=$(last -i -w $(whoami) | grep -v "still logged in" | grep -v "0.0.0.0" | grep -v "127.0.0.1" | sed -n 2p)
LAST_DATE=$(echo "$LAST_LOGIN" | awk '{print $4, $5, $6, $7}')
LAST_IP=$(echo "$LAST_LOGIN" | awk '{print $3}')
echo "🔑 Last login...........: $LAST_DATE from IP $LAST_IP"

echo "👤 User.................: $(whoami)"
echo "⏳ Uptime...............: $(uptime -p | sed 's/up //')"

CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d ':' -f2 | sed 's/^ //')
echo "🖥️ CPU Model............: $CPU_MODEL"

if [ "$SHOW_CPU" = true ]; then
  CPU_IDLE=$(vmstat 1 2 | tail -1 | awk '{print $15}')
  CPU_USAGE=$((100 - CPU_IDLE))
  echo "⚡️ CPU Usage............: ${CPU_USAGE}%"
fi

echo "📈 Load Average.........: $(cat /proc/loadavg | awk '{print $1 " / " $2 " / " $3}')"

if [ "$SHOW_MEM" = true ]; then
  echo "🧠 Memory...............: $(free -h | awk '/Mem:/ {print "Used: " $3 " | Free: " $4 " | Total: " $2}')"
  echo "💾 Disk.................: $(df -h / | awk 'NR==2{print "Used: " $3 " | Free: " $4 " | Total: " $2}')"
fi

echo "🖥 Hostname.............: $(hostname)"
echo "🧬 OS...................: $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"

if [ "$SHOW_NET" = true ]; then
  NET_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
  if [ -n "$NET_IFACE" ]; then
      RX_BYTES=$(cat /sys/class/net/$NET_IFACE/statistics/rx_bytes)
      TX_BYTES=$(cat /sys/class/net/$NET_IFACE/statistics/tx_bytes)

      function human_readable {
        local BYTES=$1
        local UNITS=('B' 'KB' 'MB' 'GB' 'TB')
        local UNIT=0
        while (( BYTES > 1024 && UNIT < 4 )); do
          BYTES=$((BYTES / 1024))
          ((UNIT++))
        done
        echo "${BYTES} ${UNITS[$UNIT]}"
      }

      RX_HR=$(human_readable $RX_BYTES)
      TX_HR=$(human_readable $TX_BYTES)
      echo "🌐 Network Traffic......: Received: $RX_HR | Transmitted: $TX_HR"
  else
      echo "🌐 Network Traffic......: Interface not found"
  fi
fi

if [ "$SHOW_FIREWALL" = true ]; then
  if command -v ufw &>/dev/null; then
      UFW_STATUS=$(ufw status | head -1)
      UFW_RULES=$(ufw status numbered | grep -c '\[')
      echo "🛡️ Firewall (UFW).......: $UFW_STATUS, Rules: $UFW_RULES"
  else
      echo "🛡️ Firewall (UFW).......: not installed"
  fi
fi

if [ "$SHOW_DOCKER" = true ]; then
  if command -v docker &>/dev/null; then
    RUNNING_CONTAINERS=$(docker ps -q | wc -l)
    TOTAL_CONTAINERS=$(docker ps -a -q | wc -l)
    echo "🐳 Docker containers....: $RUNNING_CONTAINERS / $TOTAL_CONTAINERS running"
    if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
      echo "  Running container list:"
      docker ps --format "    • {{.Names}}"
    fi
  else
    echo "🐳 Docker...............: not installed"
  fi
fi

echo
EOF

chmod +x /etc/update-motd.d/00-remnawave
rm -f /etc/motd
ln -sf /var/run/motd /etc/motd
ln -sf /etc/update-motd.d/00-remnawave /usr/local/bin/rw-motd

echo "Installing 'rw-motd-set' command..."

cat << 'EOF' > /usr/local/bin/rw-motd-set
#!/bin/bash

CONFIG="/etc/rw-motd.conf"

CHOICES=$(whiptail --title "MOTD Settings" --checklist \
"Выберите, что отображать в MOTD:" 20 60 10 \
"SHOW_CPU" "Загрузка процессора" $(grep -q 'SHOW_CPU=true' "$CONFIG" && echo ON || echo OFF) \
"SHOW_MEM" "Память и диск" $(grep -q 'SHOW_MEM=true' "$CONFIG" && echo ON || echo OFF) \
"SHOW_NET" "Сетевой трафик" $(grep -q 'SHOW_NET=true' "$CONFIG" && echo ON || echo OFF) \
"SHOW_FIREWALL" "Статус UFW" $(grep -q 'SHOW_FIREWALL=true' "$CONFIG" && echo ON || echo OFF) \
"SHOW_DOCKER" "Контейнеры Docker" $(grep -q 'SHOW_DOCKER=true' "$CONFIG" && echo ON || echo OFF) \
3>&1 1>&2 2>&3)

for VAR in SHOW_CPU SHOW_MEM SHOW_NET SHOW_FIREWALL SHOW_DOCKER; do
  if echo "$CHOICES" | grep -q "$VAR"; then
    sed -i "s/^$VAR=.*/$VAR=true/" "$CONFIG"
  else
    sed -i "s/^$VAR=.*/$VAR=false/" "$CONFIG"
  fi
done

echo "Настройки обновлены. Проверь командой: rw-motd"
EOF

chmod +x /usr/local/bin/rw-motd-set

echo "✅ Установка завершена. Используй 'rw-motd' для ручного вывода или 'rw-motd-set' для настройки."
