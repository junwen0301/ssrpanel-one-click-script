#!/bin/bash
#Time: 2017年11月2日17:14:50
#Author: 十一
#Blog: blog.67cc.cn
#GitHub版
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }
function install_ssrpanel(){
	yum -y remove httpd
	yum install -y unzip zip git
	#自动选择下载节点
	GIT='raw.githubusercontent.com'
	MY='gitee.com'
	GIT_PING=`ping -c 1 -w 1 $GIT|grep time=|awk '{print $7}'|sed "s/time=//"`
	MY_PING=`ping -c 1 -w 1 $MY|grep time=|awk '{print $7}'|sed "s/time=//"`
	echo "$GIT_PING $GIT" > ping.pl
	echo "$MY_PING $MY" >> ping.pl
	fileinfo=`sort -V ping.pl|sed -n '1p'|awk '{print $2}'`
	if [ "$fileinfo" == "$GIT" ];then
		fileinfo='https://raw.githubusercontent.com/junwen0301/ssrpanel-one-click-script/master/fileinfo.zip'
	else
		fileinfo='https://gitee.com/marisn/ssrpanel-new/raw/master/fileinfo.zip'
	fi
	rm -f ping.pl	
	wget -c https://raw.githubusercontent.com/junwen0301/ssrpanel-one-click-script/master/lnmp1.4.zip && unzip lnmp1.4.zip && cd lnmp1.4 && chmod +x install.sh && ./install.sh
	clear
	#安装fileinfo必须组件
	cd /root && wget --no-check-certificate $fileinfo
	File="/root/fileinfo.zip"
    if [ ! -f "$File" ]; then  
    echo "fileinfo.zip download be fail,please check the /root/fileinfo.zip"
	exit 0;
	else
    unzip fileinfo.zip
    fi
	cd /root/fileinfo && /usr/local/php/bin/phpize && ./configure --with-php-config=/usr/local/php/bin/php-config --with-fileinfo && make && make install
	cd /home/wwwroot/default/ && rm -rf index.html
	git clone https://github.com/ssrpanel/ssrpanel.git tmp && mv tmp/.git . && rm -rf tmp && git reset --hard
	#替换数据库配置
	wget -N -P /home/wwwroot/default/config/ https://raw.githubusercontent.com/junwen0301/ssrpanel-one-click-script/master/database.php
	wget -N -P /usr/local/php/etc/ https://raw.githubusercontent.com/junwen0301/ssrpanel-one-click-script/master/php.ini
	wget -N -P /usr/local/nginx/conf/ https://raw.githubusercontent.com/junwen0301/ssrpanel-one-click-script/master/nginx.conf
	service nginx restart
	#设置数据库
	#mysql -uroot -proot -e"create database ssrpanel;" 
	#mysql -uroot -proot -e"use ssrpanel;" 
	#mysql -uroot -proot ssrpanel < /home/wwwroot/default/sql/db.sql
	#开启数据库远程访问，以便对接节点
	#mysql -uroot -proot -e"use mysql;"
	#mysql -uroot -proot -e"GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;"
	#mysql -uroot -proot -e"flush privileges;"
mysql -hlocalhost -uroot -proot --default-character-set=utf8<<EOF
create database ssrpanel;
use ssrpanel;
source /home/wwwroot/default/sql/db.sql;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;
flush privileges;
EOF
	#安装依赖
	cd /home/wwwroot/default/
	php composer.phar install
	php artisan key:generate
    chown -R www:www storage/
    chmod -R 777 storage/
	chattr -i .user.ini
	mv .user.ini public
	chown -R root:root *
	chmod -R 777 *
	chown -R www:www storage
	chattr +i public/.user.ini
	service nginx restart
    service php-fpm restart
	#开启日志监控
	yum -y install vixie-cron crontabs
	rm -rf /var/spool/cron/root
	echo '* * * * * php /home/wwwroot/default/artisan schedule:run >> /dev/null 2>&1' >> /var/spool/cron/root
	service crond restart
	#修复数据库
	mv /home/wwwroot/default/phpmyadmin/ /home/wwwroot/default/public/
	cd /home/wwwroot/default/public/phpmyadmin
	chmod -R 755 *
	lnmp restart
	IPAddress=`wget http://members.3322.org/dyndns/getip -O - -q ; echo`;
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	echo "# A key to build success, go to http://${IPAddress}~               #"
	echo "# One click Install ssrpanel successed                             #"
	echo "# Author: marisn          Ssrpanel:ssrpanel                        #"
	echo "# Blog: http://blog.67cc.cn/                                       #"
	echo "# Github: https://github.com/junwen0301/ssrpanel-one-click-script #"
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
}
function install_log(){
    myFile="/root/shadowsocksr/ssserver.log"  
	if [ ! -f "$myFile" ]; then  
    echo "Your shadowsocksr backend is not installed"
	echo "Please check the/root/shadowsocksr/ssserver log exists"
	else
	cd /home/wwwroot/default/storage/app/public
	ln -S ssserver.log /root/shadowsocksr/ssserver.log
	chown www:www ssserver.log
	chmod 0777 /home/wwwroot/default/storage/app/public/ssserver.log
	chmod 777 -R /home/wwwroot/default/storage/logs/
	echo "Log analysis (currently supported only single-machine single node) - installation success"
    fi
}
function change_password(){
	echo -e "\033[31mNote: you must fill in the database password correctly or you can only modify it manually\033[0m"
	read -p "Please enter the database password (the initial password is root):" Default_password
	Default_password=${Default_password:-"root"}
	read -p "Please enter the database password to be set:" Change_password
	Change_password=${Change_password:-"root"}
	echo -e "\033[31mThe password you set is:${Change_password}\033[0m"
mysql -hlocalhost -uroot -p$Default_password --default-character-set=utf8<<EOF
use mysql;
update user set password=passworD("${Change_password}") where user='root';
flush privileges;
EOF
	echo "Start replacing the database information in the Settings file..."
	myFile="/root/shadowsocksr/server.py"
    if [ ! -f "$myFile" ]; then  
    sed -i "s/'password' => '"${Default_password}"'/'password' => '"${Change_password}"'/g" /home/wwwroot/default/config/database.php
	echo "The database password is complete, please remember."
	echo "Your database password is:${Change_password}"
	else
	sed -i 's/"password": "'${Default_password}'",/"password": "'${Change_password}'",/g' /root/shadowsocksr/usermysql.json
	sed -i "s/'password' => '"${Default_password}"'/'password' => '"${Change_password}"'/g" /home/wwwroot/default/config/database.php
	echo "Restart the configuration to take effect..."
	init 6
    fi

}
function install_ssr(){
	yum -y update
	yum -y install git 
	yum -y install python-setuptools && easy_install pip 
	yum -y groupinstall "Development Tools" 
	#512M chicks add 1 g of Swap
	#dd if=/dev/zero of=/var/swap bs=1024 count=1048576
	#mkswap /var/swap
	#chmod 0644 /var/swap
	#swapon /var/swap
	#echo '/var/swap   swap   swap   default 0 0' >> /etc/fstab
	#自动选择下载节点
	#GIT='raw.githubusercontent.com'
	#LIB='download.libsodium.org'
	#GIT_PING=`ping -c 1 -w 1 $GIT|grep time=|awk '{print $7}'|sed "s/time=//"`
	#LIB_PING=`ping -c 1 -w 1 $LIB|grep time=|awk '{print $7}'|sed "s/time=//"`
	#echo "$GIT_PING $GIT" > ping.pl
	#echo "$LIB_PING $LIB" >> ping.pl
	#libAddr=`sort -V ping.pl|sed -n '1p'|awk '{print $2}'`
	#if [ "$libAddr" == "$GIT" ];then
	#	libAddr='https://raw.githubusercontent.com/junwen0301/ssrv3-one-click-script/master/libsodium-1.0.13.tar.gz'
	#else
	#	libAddr='https://download.libsodium.org/libsodium/releases/libsodium-1.0.13.tar.gz'
	#fi
	#rm -f ping.pl
	wget --no-check-certificate https://github.com/jedisct1/libsodium/releases/download/1.0.16/libsodium-1.0.16.tar.gz
	tar xf libsodium-1.0.16.tar.gz && cd libsodium-1.0.16
	./configure && make -j2 && make install
	echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	ldconfig
	yum -y install python-setuptools
	easy_install supervisor
    cd /root
	wget https://raw.githubusercontent.com/junwen0301/ssrpanel-one-click-script/master/ssr-3.4.0.zip
	unzip ssr-3.4.0.zip
	cd shadowsocksr
	./setup_cymysql.sh
	./initcfg.sh
	sed -i "s#Userip#${Userip}#" /root/shadowsocksr/usermysql.json
	sed -i "s#Dbuser#${Dbuser}#" /root/shadowsocksr/usermysql.json
	sed -i "s#Dbport#${Dbport}#" /root/shadowsocksr/usermysql.json
	sed -i "s#Dbpassword#${Dbpassword}#" /root/shadowsocksr/usermysql.json
	sed -i "s#Dbname#${Dbname}#" /root/shadowsocksr/usermysql.json
	sed -i "s#UserNODE_ID#${UserNODE_ID}#" /root/shadowsocksr/usermysql.json
	yum -y install lsof lrzsz
	yum -y install python-devel
	yum -y install libffi-devel
	yum -y install openssl-devel
	yum -y install iptables
	systemctl stop firewalld.service
	systemctl disable firewalld.service
}
function install_node(){
	clear
	echo
    echo -e "\033[31m Add a node...\033[0m"
	echo
	sed -i '$a * hard nofile 512000\n* soft nofile 512000' /etc/security/limits.conf
	[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }
	echo -e "You can go back to the car if you don't know"
	echo -e "If the connection fails, check that the database remote access is open"
	read -p "Please enter your docking database IP (enter default Local IP address) :" Userip
	read -p "Please enter the database name (enter default ssrpanel):" Dbname
	read -p "Please enter the database port (enter default 3306):" Dbport
	read -p "Please enter the database account (enter default root):" Dbuser
	read -p "Please enter your database password (enter default root):" Dbpassword
	read -p "Please enter your node number (enter default 1):  " UserNODE_ID
	# IPAddress=`wget http://members.3322.org/dyndns/getip -O - -q ; echo`;
	Userip=${Userip:-"127.0.0.1"}
	Dbname=${Dbname:-"ssrpanel"}
	Dbport=${Dbport:-"3306"}
	Dbuser=${Dbuser:-"root"}
	Dbpassword=${Dbpassword:-"root"}
	UserNODE_ID=${UserNODE_ID:-"1"}
	install_ssr
    # 启用supervisord
	echo_supervisord_conf > /etc/supervisord.conf
	sed -i '$a [program:ssr]\ncommand = python2.7 /root/shadowsocksr/server.py\nuser = root\nautostart = true\nautorestart = true\nstartsecs=3' /etc/supervisord.conf
	supervisord
	#iptables
	iptables -F
	iptables -X  
	iptables -I INPUT -p tcp -m tcp --dport 22:65535 -j ACCEPT
	iptables -I INPUT -p udp -m udp --dport 22:65535 -j ACCEPT
	iptables-save >/etc/sysconfig/iptables
	iptables-save >/etc/sysconfig/iptables
	echo 'iptables-restore /etc/sysconfig/iptables' >> /etc/rc.local
	echo "/usr/bin/supervisord -c /etc/supervisord.conf" >> /etc/rc.local
	chmod +x /etc/rc.d/rc.local
	touch /root/shadowsocksr/ssserver.log
	chmod 0777 /root/shadowsocksr/ssserver.log
	cd /home/wwwroot/default/storage/app/public/
	ln -S ssserver.log /root/shadowsocksr/ssserver.log
    chown www:www ssserver.log
	chmod 777 -R /home/wwwroot/default/storage/logs/
	yum -y install ntp
	systemctl enable ntpd
	systemctl start ntpd
	ntpdate -u cn.pool.ntp.org
	timedatectl set-timezone Asia/Shanghai
	wget -N --no-check-certificate https://raw.githubusercontent.com/junwen0301/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh
	wget -N --no-check-certificate https://raw.githubusercontent.com/ssrpanel/ssrpanel/master/server/deploy_vnstat.sh;chmod +x deploy_vnstat.sh;./deploy_vnstat.sh
	clear
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	echo "# Add success to the node and log on to the front site             #"
	echo "# Restart the envoy's point of entry into force...                 #"
	echo "# Author: marisn          Ssrpanel:ssrpanel                        #"
	echo "# Blog: http://blog.67cc.cn/                                       #"
	echo "# Github: https://github.com/junwen0301/ssrpanel-one-click-script #"
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	reboot
}
function install_BBR(){
     wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh&&chmod +x bbr.sh&&./bbr.sh
}
function install_RS(){
     wget -N --no-check-certificate https://github.com/91yun/serverspeeder/raw/master/serverspeeder.sh && bash serverspeeder.sh
}
function Uninstall_Aliyun(){
yum -y install redhat-lsb
var=`lsb_release -a | grep Gentoo`
if [ -z "${var}" ]; then 
	var=`cat /etc/issue | grep Gentoo`
fi

if [ -d "/etc/runlevels/default" -a -n "${var}" ]; then
	LINUX_RELEASE="GENTOO"
else
	LINUX_RELEASE="OTHER"
fi

stop_aegis(){
	killall -9 aegis_cli >/dev/null 2>&1
	killall -9 aegis_update >/dev/null 2>&1
	killall -9 aegis_cli >/dev/null 2>&1
	killall -9 AliYunDun >/dev/null 2>&1
	killall -9 AliHids >/dev/null 2>&1
	killall -9 AliYunDunUpdate >/dev/null 2>&1
    printf "%-40s %40s\n" "Stopping aegis" "[  OK  ]"
}

remove_aegis(){
if [ -d /usr/local/aegis ];then
    rm -rf /usr/local/aegis/aegis_client
    rm -rf /usr/local/aegis/aegis_update
	rm -rf /usr/local/aegis/alihids
fi
}

uninstall_service() {
   
   if [ -f "/etc/init.d/aegis" ]; then
		/etc/init.d/aegis stop  >/dev/null 2>&1
		rm -f /etc/init.d/aegis 
   fi

	if [ $LINUX_RELEASE = "GENTOO" ]; then
		rc-update del aegis default 2>/dev/null
		if [ -f "/etc/runlevels/default/aegis" ]; then
			rm -f "/etc/runlevels/default/aegis" >/dev/null 2>&1;
		fi
    elif [ -f /etc/init.d/aegis ]; then
         /etc/init.d/aegis  uninstall
	    for ((var=2; var<=5; var++)) do
			if [ -d "/etc/rc${var}.d/" ];then
				 rm -f "/etc/rc${var}.d/S80aegis"
		    elif [ -d "/etc/rc.d/rc${var}.d" ];then
				rm -f "/etc/rc.d/rc${var}.d/S80aegis"
			fi
		done
    fi

}

stop_aegis
uninstall_service
remove_aegis

printf "%-40s %40s\n" "Uninstalling aegis"  "[  OK  ]"

var=`lsb_release -a | grep Gentoo`
if [ -z "${var}" ]; then 
	var=`cat /etc/issue | grep Gentoo`
fi

if [ -d "/etc/runlevels/default" -a -n "${var}" ]; then
	LINUX_RELEASE="GENTOO"
else
	LINUX_RELEASE="OTHER"
fi

stop_aegis(){
	killall -9 aegis_cli >/dev/null 2>&1
	killall -9 aegis_update >/dev/null 2>&1
	killall -9 aegis_cli >/dev/null 2>&1
    printf "%-40s %40s\n" "Stopping aegis" "[  OK  ]"
}

stop_quartz(){
	killall -9 aegis_quartz >/dev/null 2>&1
        printf "%-40s %40s\n" "Stopping quartz" "[  OK  ]"
}

remove_aegis(){
if [ -d /usr/local/aegis ];then
    rm -rf /usr/local/aegis/aegis_client
    rm -rf /usr/local/aegis/aegis_update
fi
}

remove_quartz(){
if [ -d /usr/local/aegis ];then
	rm -rf /usr/local/aegis/aegis_quartz
fi
}


uninstall_service() {
   
   if [ -f "/etc/init.d/aegis" ]; then
		/etc/init.d/aegis stop  >/dev/null 2>&1
		rm -f /etc/init.d/aegis 
   fi

	if [ $LINUX_RELEASE = "GENTOO" ]; then
		rc-update del aegis default 2>/dev/null
		if [ -f "/etc/runlevels/default/aegis" ]; then
			rm -f "/etc/runlevels/default/aegis" >/dev/null 2>&1;
		fi
    elif [ -f /etc/init.d/aegis ]; then
         /etc/init.d/aegis  uninstall
	    for ((var=2; var<=5; var++)) do
			if [ -d "/etc/rc${var}.d/" ];then
				 rm -f "/etc/rc${var}.d/S80aegis"
		    elif [ -d "/etc/rc.d/rc${var}.d" ];then
				rm -f "/etc/rc.d/rc${var}.d/S80aegis"
			fi
		done
    fi

}
stop_aegis
stop_quartz
uninstall_service
remove_aegis
remove_quartz
printf "%-40s %40s\n" "Uninstalling aegis_quartz"  "[  OK  ]"
pkill aliyun-service
rm -fr /etc/init.d/agentwatch /usr/sbin/aliyun-service
rm -rf /usr/local/aegis*
iptables -I INPUT -s 140.205.201.0/28 -j DROP
iptables -I INPUT -s 140.205.201.16/29 -j DROP
iptables -I INPUT -s 140.205.201.32/28 -j DROP
iptables -I INPUT -s 140.205.225.192/29 -j DROP
iptables -I INPUT -s 140.205.225.200/30 -j DROP
iptables -I INPUT -s 140.205.225.184/29 -j DROP
iptables -I INPUT -s 140.205.225.183/32 -j DROP
iptables -I INPUT -s 140.205.225.206/32 -j DROP
iptables -I INPUT -s 140.205.225.205/32 -j DROP
iptables -I INPUT -s 140.205.225.195/32 -j DROP
iptables -I INPUT -s 140.205.225.204/32 -j DROP
}

clear
echo "#############################################################################"
echo "#Welcome to use One click Install ssrpanel and nodes scripts                #"
echo "#Please select the script you want to build：                               #"
echo "#1.  One click Install ssrpanel                                             #"
echo "#2.  One click Install ssrpanel nodes                                       #"
echo "#3.  One click Install BBR                                                  #"
echo "#4.  One click Install Serverspeeder                                        #"
echo "#5.  Upgrade to the latest ssr-panel [official update script]               #"
echo "#6.  Log analysis (currently only single node single node support)          #" 
echo "#7.  One click change the Database password                                 #" 
echo "#8.  Uninstall aliyun shield monitor & shield cloud shield IP               #"  
echo "#                      PS:Please build acceleration and build ssrpanel first#"
echo "#                                     Apply to Centos 7. X system           #"
echo "#############################################################################"
echo
read num
if [[ $num == "1" ]]
then
install_ssrpanel
fi;
if [[ $num == "2" ]]
then
install_node
fi;
if [[ $num == "3" ]]
then
install_BBR
fi;
if [[ $num == "4" ]]
then
install_RS
fi;
if [[ $num == "5" ]]
then
cd /home/wwwroot/default/
chmod a+x update.sh && sh update.sh
fi;
if [[ $num == "6" ]]
then
install_log
fi;
if [[ $num == "7" ]]
then
change_password
fi;
if [[ $num == "8" ]]
then
Uninstall_Aliyun
fi;
