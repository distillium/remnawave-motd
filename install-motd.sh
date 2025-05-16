#!/bin/bash

set -e

echo "Updating package lists..."
apt-get update -qq

echo "Installing toilet and dependencies..."
apt-get install -y toilet figlet > /dev/null

echo "Installing custom MOTD..."

mkdir -p /etc/update-motd.d

cat << 'EOF' > /etc/update-motd.d/00-remnawave
#!/bin/bash
clear
echo -e "\e[1;37m"
toilet -f standard -F metal "remnawave"
echo

LAST_LOGIN=$(last -n 1 $(whoami) | head -1)
LAST_DATE=$(echo "$LAST_LOGIN" | awk '{print $4, $5, $6, $7}')
LAST_IP=$(echo "$LAST_LOGIN" | awk '{print $3}')
echo "🔑 Last login............: $LAST_DATE from IP $LAST_IP"
echo "👤 User..................: $(whoami)"
echo "⏳ Uptime................: $(uptime -p | sed 's/up //')"

CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d ':' -f2 | sed 's/^ //')
echo "🖥️ CPU Model.............: $CPU_MODEL"

CPU_USAGE=$(top -bn2 | grep "Cpu(s)" | tail -n1 | awk -F'id,' '{split($1, vs, ","); v=vs[length(vs)]; sub("%", "", v); print 100 - v}')
echo "⚡️ CPU Usage............: ${CPU_USAGE}%"

echo "📈 Load Average.........: $(cat /proc/loadavg | awk '{print $1 " / " $2 " / " $3}')"
echo "⚙️ Processes Running....: $(ps -e --no-headers | wc -l)"
echo "🧠 Memory...............: $(free -h | awk '/Mem:/ {print "Used: " $3 " | Free: " $4 " | Total: " $2}')"
echo "💾 Disk.................: $(df -h / | awk 'NR==2{print "Used: " $3 " | Free: " $4 " | Total: " $2}')"
echo "🖥 Hostname.............: $(hostname)"
echo "🧬 OS...................: $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"

# Network traffic for primary interface
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

# UFW firewall status
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status | head -1)
    UFW_RULES=$(ufw status numbered | grep -c '\[')
    echo "🛡️ Firewall (UFW)......: $UFW_STATUS, Rules: $UFW_RULES"
else
    echo "🛡️ Firewall (UFW)......: not installed"
fi

if command -v docker &>/dev/null; then
  RUNNING_CONTAINERS=$(docker ps -q | wc -l)
  TOTAL_CONTAINERS=$(docker ps -a -q | wc -l)
  echo "🐳 Docker containers.....: $RUNNING_CONTAINERS / $TOTAL_CONTAINERS running"
  if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    echo "  Running container list:"
    docker ps --format "    • {{.Names}}"
  fi
else
  echo "🐳 Docker................: not installed"
fi

echo
EOF

chmod +x /etc/update-motd.d/00-remnawave

rm -f /etc/motd
ln -sf /var/run/motd /etc/motd

echo "✅ MOTD installed successfully!"
