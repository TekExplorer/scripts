#!/usr/bin/env bash

# Made by TekExplorer with inspiration from https://docs.phoenixnodes.com/advanced-guides/install-nginx-reverse-proxy-on-ubuntu-18.04-for-dynmap
# Easily set up a Dynmap proxy with either Apache or Nginx
# Run this script as root (sudo su)
# ~$ bash <(curl https://raw.githubusercontent.com/TekExplorer/scripts/main/ptero/create-dynmap-proxy.sh)

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

setup

setup() {
    for i in {apt,yum,dnf}; do
        command -v $i && packageManager=$i
    done

    echo "What is the (sub)domain name you want to use for Dynmap? (Eg. map.yoursite.com)"
    read ccdomain

    echo "What is the IP address of your Minecraft server and the port Dynmap is running on (Eg. 192.168.1.101:8192)"
    read ccip

    webserverDetect

    command -v certbot || install certbot
    install webserver-config

    echo "Your Dynmap reverse proxy is now setup and should be available at https://$ccdomain"
}

install() {
    case ${1,,} in
        webserver ) $packageManager install -y ${prefferedWebserver[package]} ;;
        certbot   )
            case $packageManager in
                yum | dnf )
                    $packageManager install -y epel-release
                    [[ $(rpm --eval '%{centos_ver}') == 7 ]] && p=2
                    ;;
                apt )
                    apt install -y software-properties-common
                    add-apt-repository -y universe
                    add-apt-repository -y ppa:certbot/certbot
                    apt update
                    ;;
            esac
            $packageManager install -y certbot python${p:-3}-certbot-${prefferedWebserver[name]}
            ;;
        webserver-config )
            if [[ -f /etc/centos-release ]]; then
                webserverConfLocation[nginx]=/etc/nginx/conf.d/
                webserverConfLocation[apache]=/etc/httpd/conf.d/
            else
                linkServerConf=true
                webserverConfLocation[nginx]=/etc/nginx/sites-available/
                webserverConfLocation[apache]=/etc/apache2/sites-available/
            fi
            local line="
            "
            webserverConf[nginx]="# Dynmap config courtesy of TekExplorer
            server {
                server_name $ccdomain;
                listen 80;
                listen [::]:80;
                access_log /var/log/nginx/reverse-access.log;
                error_log /var/log/nginx/reverse-error.log;
                location / {
                    proxy_pass http://$ccip;
                }
            }"
            webserverConf[apache]="# Dynmap config courtesy of TekExplorer
            <VirtualHost *:80>
                ProxyPreserveHost On
                ServerName $ccdomain
                ProxyPass / http://$ccip/
                ProxyPassReverse / http://$ccip/
            </VirtualHost>"

            # Set up conf file.
            sed "s/^${line}//g" <<< ${webserverConf[${prefferedWebserver[name]}]} > webserverConfLocation[${prefferedWebserver[name]}]/$ccdomain.conf
            [[ $linkServerConf == true ]] && ln -s /etc/${prefferedWebserver[package]}/sites-available/$ccdomain.conf /etc/${prefferedWebserver[package]}/sites-enabled/$ccdomain.conf
            certbot --${prefferedWebserver[name]}
            systemctl restart ${prefferedWebserver[package]}
            ;;
    esac
}

webserverDetect() {
    declare -A prefferedWebserver
    command -v nginx   &&  nginxInstalled=true
    command -v apache2 && apacheInstalled=(true apache2)
    command -v httpd   && apacheInstalled=(true httpd)

    if [[ $nginxInstalled == true && ${apacheInstalled[0]} == true ]]; then # both are installed
        echo "Looks like you have both apache2 and nginx installed. Which would you like to use? (nginx or apache) "
        prefferedWebserverUserInput
        invertWebserver=(nginx ${apacheInstalled[1]})
        echo "Disabling ${invertWebserver/${prefferedWebserver[package]}}"
        systemctl disable ${invertWebserver/${prefferedWebserver[package]}}
    elif [[ $nginxInstalled == true && ${apacheInstalled[0]} != true ]]; then # only nginx is installed
        prefferedWebserver=([name]=nginx [package]=nginx)
    elif [[ $nginxInstalled != true && ${apacheInstalled[0]} == true ]]; then # only apache is installed
        prefferedWebserver=([name]=apache [package]=${apacheInstalled[1]})
    elif [[ $nginxInstalled != true && ${apacheInstalled[0]} != true ]]; then # neither are installed
        echo "Looks like you dont have a webserver installed. Which would you like to use? (nginx or apache) "
        prefferedWebserverUserInput
        install webserver
    fi
}

prefferedWebserverUserInput() {
    read pW
    case $pW in
        apache ) prefferedWebserver=([name]=apache [package]=apache2) ; [[ -f /etc/centos-release ]] && prefferedWebserver[package]=httpd;;
        nginx  ) prefferedWebserver=([name]=nginx [package]=nginx)  ;;
        * ) echo "Invalid option '$pW' Options: nginx or apache"; prefferedWebserverUserInput; return;;
    esac
}
