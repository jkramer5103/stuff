#!/bin/bash
# Secure WireGuard server installer (non-interactive, default options)
# https://github.com/angristan/wireguard-install

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

#############################
# Grundlegende Prüfungen
#############################

function isRoot() {
    if [ "${EUID}" -ne 0 ]; then
        echo "Du musst dieses Skript als root ausführen"
        exit 1
    fi
}

function checkVirt() {
    function openvzErr() {
        echo "OpenVZ wird nicht unterstützt"
        exit 1
    }
    function lxcErr() {
        echo "LXC wird (noch) nicht unterstützt."
        echo "WireGuard kann zwar in einem LXC-Container laufen, jedoch muss das Kernelmodul im Host installiert sein."
        exit 1
    }
    if command -v virt-what &>/dev/null; then
        if [ "$(virt-what)" == "openvz" ]; then
            openvzErr
        fi
        if [ "$(virt-what)" == "lxc" ]; then
            lxcErr
        fi
    else
        if [ "$(systemd-detect-virt)" == "openvz" ]; then
            openvzErr
        fi
        if [ "$(systemd-detect-virt)" == "lxc" ]; then
            lxcErr
        fi
    fi
}

function checkOS() {
    source /etc/os-release
    OS="${ID}"
    if [[ ${OS} == "debian" || ${OS} == "raspbian" ]]; then
        if [[ ${VERSION_ID} -lt 10 ]]; then
            echo "Deine Debian-Version (${VERSION_ID}) wird nicht unterstützt – bitte benutze Debian 10 (Buster) oder neuer"
            exit 1
        fi
        OS=debian
    elif [[ ${OS} == "ubuntu" ]]; then
        RELEASE_YEAR=$(echo "${VERSION_ID}" | cut -d'.' -f1)
        if [[ ${RELEASE_YEAR} -lt 18 ]]; then
            echo "Deine Ubuntu-Version (${VERSION_ID}) wird nicht unterstützt – bitte benutze Ubuntu 18.04 oder neuer"
            exit 1
        fi
    elif [[ ${OS} == "fedora" ]]; then
        if [[ ${VERSION_ID} -lt 32 ]]; then
            echo "Deine Fedora-Version (${VERSION_ID}) wird nicht unterstützt – bitte benutze Fedora 32 oder neuer"
            exit 1
        fi
    elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
        if [[ ${VERSION_ID} == 7* ]]; then
            echo "Deine CentOS-Version (${VERSION_ID}) wird nicht unterstützt – bitte benutze CentOS 8 oder neuer"
            exit 1
        fi
    elif [[ -e /etc/oracle-release ]]; then
        source /etc/os-release
        OS=oracle
    elif [[ -e /etc/arch-release ]]; then
        OS=arch
    elif [[ -e /etc/alpine-release ]]; then
        OS=alpine
        if ! command -v virt-what &>/dev/null; then
            apk update && apk add virt-what
        fi
    else
        echo "Dein Betriebssystem wird nicht unterstützt."
        exit 1
    fi
}

function getHomeDirForClient() {
    local CLIENT_NAME=$1

    if [ -z "${CLIENT_NAME}" ]; then
        echo "Fehler: getHomeDirForClient() benötigt einen Clientnamen als Argument"
        exit 1
    fi

    if [ -e "/home/${CLIENT_NAME}" ]; then
        HOME_DIR="/home/${CLIENT_NAME}"
    elif [ "${SUDO_USER}" ]; then
        if [ "${SUDO_USER}" == "root" ]; then
            HOME_DIR="/root"
        else
            HOME_DIR="/home/${SUDO_USER}"
        fi
    else
        HOME_DIR="/root"
    fi

    echo "$HOME_DIR"
}

function initialCheck() {
    isRoot
    checkOS
    checkVirt
}

#############################
# Installation ohne User-Eingaben
#############################

function installQuestions() {
    # Alle Werte werden automatisch auf den Default gesetzt
    echo "Starte non-interaktive WireGuard-Installation mit Default-Optionen."

    # Öffentliche IP (IPv4 bevorzugt, sonst IPv6)
    SERVER_PUB_IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | awk '{print $1}' | head -1)
    if [[ -z ${SERVER_PUB_IP} ]]; then
        SERVER_PUB_IP=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)
    fi

    # Öffentliches Interface ermitteln
    SERVER_NIC="$(ip -4 route ls | grep default | awk '/dev/ {for (i=1; i<=NF; i++) if ($i == "dev") print $(i+1)}' | head -1)"
    SERVER_PUB_NIC="${SERVER_NIC}"

    # Default WireGuard Interface
    SERVER_WG_NIC="wg0"

    # Default WireGuard IP-Adressen
    SERVER_WG_IPV4="10.66.66.1"
    SERVER_WG_IPV6="fd42:42:42::1"

    # Zufälliger Port im privaten Bereich
    RANDOM_PORT=$(shuf -i49152-65535 -n1)
    SERVER_PORT="${RANDOM_PORT}"

    # DNS-Resolver
    CLIENT_DNS_1="1.1.1.1"
    CLIENT_DNS_2="1.0.0.1"

    # Allowed IPs
    ALLOWED_IPS="0.0.0.0/0,::/0"

    echo "Verwende folgende Einstellungen:"
    echo "  Öffentliche IP: ${SERVER_PUB_IP}"
    echo "  Öffentliches Interface: ${SERVER_PUB_NIC}"
    echo "  WireGuard Interface: ${SERVER_WG_NIC}"
    echo "  WireGuard IPv4: ${SERVER_WG_IPV4}"
    echo "  WireGuard IPv6: ${SERVER_WG_IPV6}"
    echo "  WireGuard Port: ${SERVER_PORT}"
    echo "  DNS: ${CLIENT_DNS_1}, ${CLIENT_DNS_2}"
    echo "  Allowed IPs: ${ALLOWED_IPS}"
}

function installWireGuard() {
    installQuestions

    # Installation der Pakete – abhängig vom Betriebssystem
    if [[ ${OS} == 'ubuntu' ]] || { [[ ${OS} == 'debian' ]] && [[ ${VERSION_ID} -gt 10 ]]; }; then
        apt-get update
        apt-get install -y wireguard iptables resolvconf qrencode
    elif [[ ${OS} == 'debian' ]]; then
        if ! grep -rqs "^deb .* buster-backports" /etc/apt/; then
            echo "deb http://deb.debian.org/debian buster-backports main" >/etc/apt/sources.list.d/backports.list
            apt-get update
        fi
        apt update
        apt-get install -y iptables resolvconf qrencode
        apt-get install -y -t buster-backports wireguard
    elif [[ ${OS} == 'fedora' ]]; then
        if [[ ${VERSION_ID} -lt 32 ]]; then
            dnf install -y dnf-plugins-core
            dnf copr enable -y jdoss/wireguard
            dnf install -y wireguard-dkms
        fi
        dnf install -y wireguard-tools iptables qrencode
    elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
        if [[ ${VERSION_ID} == 8* ]]; then
            yum install -y epel-release elrepo-release
            yum install -y kmod-wireguard
            yum install -y qrencode
        fi
        yum install -y wireguard-tools iptables
    elif [[ ${OS} == 'oracle' ]]; then
        dnf install -y oraclelinux-developer-release-el8
        dnf config-manager --disable -y ol8_developer
        dnf config-manager --enable -y ol8_developer_UEKR6
        dnf config-manager --save -y --setopt=ol8_developer_UEKR6.includepkgs='wireguard-tools*'
        dnf install -y wireguard-tools qrencode iptables
    elif [[ ${OS} == 'arch' ]]; then
        pacman -S --needed --noconfirm wireguard-tools qrencode
    elif [[ ${OS} == 'alpine' ]]; then
        apk update
        apk add wireguard-tools iptables build-base libpng-dev
        curl -O https://fukuchi.org/works/qrencode/qrencode-4.1.1.tar.gz
        tar xf qrencode-4.1.1.tar.gz
        (cd qrencode-4.1.1 && ./configure && make && make install && ldconfig)
    fi

    mkdir -p /etc/wireguard
    chmod 600 -R /etc/wireguard/

    SERVER_PRIV_KEY=$(wg genkey)
    SERVER_PUB_KEY=$(echo "${SERVER_PRIV_KEY}" | wg pubkey)

    # Speichere WireGuard-Einstellungen
    cat <<EOF >/etc/wireguard/params
SERVER_PUB_IP=${SERVER_PUB_IP}
SERVER_PUB_NIC=${SERVER_PUB_NIC}
SERVER_WG_NIC=${SERVER_WG_NIC}
SERVER_WG_IPV4=${SERVER_WG_IPV4}
SERVER_WG_IPV6=${SERVER_WG_IPV6}
SERVER_PORT=${SERVER_PORT}
SERVER_PRIV_KEY=${SERVER_PRIV_KEY}
SERVER_PUB_KEY=${SERVER_PUB_KEY}
CLIENT_DNS_1=${CLIENT_DNS_1}
CLIENT_DNS_2=${CLIENT_DNS_2}
ALLOWED_IPS=${ALLOWED_IPS}
EOF

    # Erstelle die Server-Konfiguration
    cat <<EOF >"/etc/wireguard/${SERVER_WG_NIC}.conf"
[Interface]
Address = ${SERVER_WG_IPV4}/24,${SERVER_WG_IPV6}/64
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_PRIV_KEY}
EOF

    if pgrep firewalld; then
        FIREWALLD_IPV4_ADDRESS=$(echo "${SERVER_WG_IPV4}" | cut -d"." -f1-3)".0"
        FIREWALLD_IPV6_ADDRESS=$(echo "${SERVER_WG_IPV6}" | sed 's/:[^:]*$/:0/')
        cat <<EOF >>"/etc/wireguard/${SERVER_WG_NIC}.conf"
PostUp = firewall-cmd --zone=public --add-interface=${SERVER_WG_NIC} && firewall-cmd --add-port ${SERVER_PORT}/udp && firewall-cmd --add-rich-rule='rule family=ipv4 source address=${FIREWALLD_IPV4_ADDRESS}/24 masquerade' && firewall-cmd --add-rich-rule='rule family=ipv6 source address=${FIREWALLD_IPV6_ADDRESS}/24 masquerade'
PostDown = firewall-cmd --zone=public --add-interface=${SERVER_WG_NIC} && firewall-cmd --remove-port ${SERVER_PORT}/udp && firewall-cmd --remove-rich-rule='rule family=ipv4 source address=${FIREWALLD_IPV4_ADDRESS}/24 masquerade' && firewall-cmd --remove-rich-rule='rule family=ipv6 source address=${FIREWALLD_IPV6_ADDRESS}/24 masquerade'
EOF
    else
        cat <<EOF >>"/etc/wireguard/${SERVER_WG_NIC}.conf"
PostUp = iptables -I INPUT -p udp --dport ${SERVER_PORT} -j ACCEPT
PostUp = iptables -I FORWARD -i ${SERVER_PUB_NIC} -o ${SERVER_WG_NIC} -j ACCEPT
PostUp = iptables -I FORWARD -i ${SERVER_WG_NIC} -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostUp = ip6tables -I FORWARD -i ${SERVER_WG_NIC} -j ACCEPT
PostUp = ip6tables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostDown = iptables -D INPUT -p udp --dport ${SERVER_PORT} -j ACCEPT
PostDown = iptables -D FORWARD -i ${SERVER_PUB_NIC} -o ${SERVER_WG_NIC} -j ACCEPT
PostDown = iptables -D FORWARD -i ${SERVER_WG_NIC} -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostDown = ip6tables -D FORWARD -i ${SERVER_WG_NIC} -j ACCEPT
PostDown = ip6tables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
EOF
    fi

    # Aktiviere IP-Forwarding
    cat <<EOF >/etc/sysctl.d/wg.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

    if [[ ${OS} == 'alpine' ]]; then
        sysctl -p /etc/sysctl.d/wg.conf
        rc-update add sysctl
        ln -s /etc/init.d/wg-quick "/etc/init.d/wg-quick.${SERVER_WG_NIC}"
        rc-service "wg-quick.${SERVER_WG_NIC}" start
        rc-update add "wg-quick.${SERVER_WG_NIC}"
    else
        sysctl --system
        systemctl start "wg-quick@${SERVER_WG_NIC}"
        systemctl enable "wg-quick@${SERVER_WG_NIC}"
    fi

    # Erstelle automatisch den einzigen Client "client"
    newClient

    echo -e "${GREEN}WireGuard wurde installiert – Client 'client' wurde erstellt.${NC}"

    if [[ ${OS} == 'alpine' ]]; then
        rc-service --quiet "wg-quick.${SERVER_WG_NIC}" status
    else
        systemctl is-active --quiet "wg-quick@${SERVER_WG_NIC}"
    fi
    WG_RUNNING=$?

    if [[ ${WG_RUNNING} -ne 0 ]]; then
        echo -e "\n${RED}WARNUNG: WireGuard scheint nicht zu laufen.${NC}"
        if [[ ${OS} == 'alpine' ]]; then
            echo -e "${ORANGE}Status kannst du prüfen mit: rc-service wg-quick.${SERVER_WG_NIC} status${NC}"
        else
            echo -e "${ORANGE}Status: systemctl status wg-quick@${SERVER_WG_NIC}${NC}"
        fi
        echo -e "${ORANGE}Sollte z. B. \"Cannot find device ${SERVER_WG_NIC}\" angezeigt werden, starte den Server neu!${NC}"
    else
        echo -e "\n${GREEN}WireGuard läuft einwandfrei.${NC}"
        if [[ ${OS} == 'alpine' ]]; then
            echo -e "${GREEN}Status: rc-service wg-quick.${SERVER_WG_NIC} status\n${NC}"
        else
            echo -e "${GREEN}Status: systemctl status wg-quick@${SERVER_WG_NIC}\n${NC}"
        fi
        echo -e "${ORANGE}Falls der Client keine Internetverbindung hat, starte den Server neu.${NC}"
    fi
}

#############################
# Client-Konfiguration (non-interaktiv)
#############################

function newClient() {
    # Der Client wird automatisch "client" heißen.
    CLIENT_NAME="client"

    # Ermittle die erste verfügbare IPv4-Adresse (von .2 bis .254)
    for DOT_IP in {2..254}; do
        DOT_EXISTS=$(grep -c "${SERVER_WG_IPV4%.*}.$DOT_IP" "/etc/wireguard/${SERVER_WG_NIC}.conf")
        if [[ ${DOT_EXISTS} == '0' ]]; then
            break
        fi
    done
    CLIENT_WG_IPV4="${SERVER_WG_IPV4%.*}.$DOT_IP"

    # Für IPv6 verwenden wir das Muster: Basis::DOT_IP
    BASE_IPV6=$(echo "$SERVER_WG_IPV6" | awk -F '::' '{ print $1 }')
    CLIENT_WG_IPV6="${BASE_IPV6}::${DOT_IP}"

    # Schlüsselgenerierung für den Client
    CLIENT_PRIV_KEY=$(wg genkey)
    CLIENT_PUB_KEY=$(echo "${CLIENT_PRIV_KEY}" | wg pubkey)
    CLIENT_PRE_SHARED_KEY=$(wg genpsk)

    HOME_DIR=$(getHomeDirForClient "${CLIENT_NAME}")

    # Falls die öffentliche IP IPv6 ist, in eckige Klammern setzen
    if [[ ${SERVER_PUB_IP} =~ .*:.* ]]; then
        if [[ ${SERVER_PUB_IP} != \[*\]* ]]; then
            SERVER_PUB_IP="[$SERVER_PUB_IP]"
        fi
    fi
    ENDPOINT="${SERVER_PUB_IP}:${SERVER_PORT}"

    # Erstelle die Client-Konfigurationsdatei
    cat <<EOF >"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128
DNS = ${CLIENT_DNS_1},${CLIENT_DNS_2}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
Endpoint = ${ENDPOINT}
AllowedIPs = ${ALLOWED_IPS}
EOF

    # Füge den Client als Peer in die Server-Konfiguration ein
    cat <<EOF >>"/etc/wireguard/${SERVER_WG_NIC}.conf"

### Client ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
AllowedIPs = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128
EOF

    wg syncconf "${SERVER_WG_NIC}" <(wg-quick strip "${SERVER_WG_NIC}")

    if command -v qrencode &>/dev/null; then
        echo -e "\nHier siehst du den Client als QR-Code:\n"
        qrencode -t ansiutf8 -l L <"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"
        echo ""
    fi

    echo -e "${GREEN}Client-Konfiguration wurde erstellt: ${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf${NC}"
}

#############################
# Hauptprogramm
#############################

initialCheck

# Falls bereits /etc/wireguard/params existiert, wird ein neuer Client hinzugefügt;
# andernfalls erfolgt die komplette Installation.
if [[ -e /etc/wireguard/params ]]; then
    source /etc/wireguard/params
    newClient
else
    installWireGuard
fi
