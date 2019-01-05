#!/bin/bash

rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}

wireguard_install(){
    version=$(cat /etc/os-release | awk -F '[".]' '$1=="VERSION="{print $2}')
    if [ $version == 18 ]
    then
        sudo apt-get update -y
        sudo apt-get install -y software-properties-common
        sudo apt-get install -y openresolv
    else
        sudo apt-get update -y
        sudo apt-get install -y software-properties-common
    fi
    sudo add-apt-repository -y ppa:wireguard/wireguard
    sudo apt-get update -y
    sudo apt-get install -y wireguard curl

    sudo echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf
    sysctl -p
    echo "1"> /proc/sys/net/ipv4/ip_forward
    
    mkdir /etc/wireguard
    cd /etc/wireguard
    wg genkey | tee sprivatekey | wg pubkey > spublickey
    wg genkey | tee cprivatekey | wg pubkey > cpublickey
    s1=$(cat sprivatekey)
    s2=$(cat spublickey)
    c1=$(cat cprivatekey)
    c2=$(cat cpublickey)
    serverip=$(curl ipv4.icanhazip.com)
    port=$(rand 10000 60000)
    eth=$(ls /sys/class/net | awk '/^e/{print}')

sudo cat > /etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.0.0.1/24 
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $c2
AllowedIPs = 10.0.0.2/32
EOF


sudo cat > /etc/wireguard/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.0.0.2/24 
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $s2
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

    sudo apt-get install -y qrencode

sudo cat > /etc/init.d/wgstart <<-EOF
#! /bin/bash
### BEGIN INIT INFO
# Provides:		wgstart
# Required-Start:	$remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	wgstart
### END INIT INFO
sudo wg-quick up wg0
EOF

    sudo chmod +x /etc/init.d/wgstart
    cd /etc/init.d
    if [ $version == 14 ]
    then
        sudo update-rc.d wgstart defaults 90
    else
        sudo update-rc.d wgstart defaults
    fi
    
    sudo wg-quick up wg0
    
    content=$(cat /etc/wireguard/client.conf)
    echo -e "\033[43;42m Please Download /etc/wireguard/client.conf，For mobile phone you can directly scan QR code \033[0m"
    echo "${content}" | qrencode -o - -t UTF8
}

wireguard_remove(){

    sudo wg-quick down wg0
    sudo apt-get remove -y wireguard
    sudo rm -rf /etc/wireguard

}

add_user(){
    echo -e "\033[37;41mGive a new user a name that cannot be repeated with an existing user\033[0m"
    read -p "please enter user name：" newname
    cd /etc/wireguard/client
    cp client.conf $newname.conf
    wg genkey | tee temprikey | wg pubkey > tempubkey
    ipnum=$(grep Allowed /etc/wireguard/wg0.conf | tail -1 | awk -F '[ ./]' '{print $6}')
    newnum=$((10#${ipnum}+1))
    sed -i 's%^PrivateKey.*$%'"PrivateKey = $(cat temprikey)"'%' $newname.conf
    sed -i 's%^Address.*$%'"Address = 10.0.0.$newnum\/24"'%' $newname.conf

cat >> /etc/wireguard/wg0.conf <<-EOF
[Peer]
PublicKey = $(cat tempubkey)
AllowedIPs = 10.0.0.$newnum/32
EOF

    content=$(cat $newname.conf)
    echo -e "\033[37;41mAdd complete Please Download, file：/etc/wireguard/client/$newname.conf\033[0m"
    echo -e "\033[37;41mFor mobile phone you can directly scan QR code\033[0m"
    echo "${content}" | qrencode -o - -t UTF8
}

#Start Menu
start_menu(){
    clear
    echo -e "\033[43;42m ====================================\033[0m"
    echo -e "\033[43;42m Introduction：wireguard+udpspeeder+udp2raw  \033[0m"
    echo -e "\033[43;42m system：Ubuntu                      \033[0m"
    echo -e "\033[43;42m Author：atrandys                      \033[0m"
    echo -e "\033[43;42m website：www.atrandys.com              \033[0m"
    echo -e "\033[43;42m Youtube：atrandys                   \033[0m"
    echo -e "\033[43;42m ====================================\033[0m"
    echo
    echo -e "\033[0;33m 1. installation wireguard\033[0m"
    echo -e "\033[0;33m 2. View client QR code\033[0m"
    echo -e "\033[0;31m 3. delete wireguard\033[0m"
    echo -e "\033[0;31m 4. Add user\033[0m"
    echo -e " 0. Exit script"
    echo
    read -p "Please enter the number:" num
    case "$num" in
    1)
    wireguard_install
    ;;
    2)
    content=$(cat /etc/wireguard/client.conf)
    echo "${content}" | qrencode -o - -t UTF8
    ;;
    3)
    wireguard_remove
    ;;
    4)
    add_user
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    echo -e "Please enter the correct number"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
