#!/bin/bash
#Time: 2017年11月2日17:14:50
#Author: 十一
#Blog: blog.67cc.cn
#GitHub版
[ $(id -u) != "0" ] && { echo "错误：你必须使用root用户登录"; exit 1; }
function install_ssrpanel(){
	yum -y remove httpd
	yum install -y unzip zip git
	wget -c https://raw.githubusercontent.com/echo-marisn/ssrpanel-one-click-script/master/lnmp1.4.zip && unzip lnmp1.4.zip && cd lnmp1.4 && chmod +x install.sh && ./install.sh
	cd /home/wwwroot/default/
	rm -rf index.html
	git clone https://github.com/ssrpanel/ssrpanel.git tmp && mv tmp/.git . && rm -rf tmp && git reset --hard
	#替换数据库配置
	#wget -N -P /home/wwwroot/default/config/ https://raw.githubusercontent.com/echo-marisn/ssrpanel-one-click-script/master/database.php
	wget -N -P /usr/local/php/etc/ https://raw.githubusercontent.com/echo-marisn/ssrpanel-one-click-script/master/php.ini
	wget -N -P /usr/local/nginx/conf/ https://raw.githubusercontent.com/echo-marisn/ssrpanel-one-click-script/master/nginx.conf
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
	echo -e "\033[31m#############################################################\033[0m"
	echo -e "\033[32m# 一键搭建成功，登录http://${IPAddress}看看吧~              #\033[0m"
	echo -e "\033[33m# 欢迎使用一键ssrpanel脚本+多节点搭建                       #\033[0m"
	echo -e "\033[33m# Author: 十一          Ssrpanel:胖虎                       #\033[0m"
	echo -e "\033[32m# Blog: http://blog.67cc.cn/                                #\033[0m"
	echo -e "\033[31m#############################################################\033[0m"
}
function install_log(){
    myFile="/root/shadowsocksr/ssserver.log"  
	if [ ! -f "$myFile" ]; then  
    echo "你的shadowsocksr后端未安装"
	echo "请检查/root/shadowsocksr/ssserver.log是否存在"
	else
	cd /home/wwwroot/default/storage/app/public
	ln -S ssserver.log /root/shadowsocksr/ssserver.log
	chown www:www ssserver.log
	chmod 0777 /home/wwwroot/default/storage/app/public/ssserver.log
	chmod 777 -R /home/wwwroot/default/storage/logs/
	echo "日志分析（目前仅支持单机单节点）-安装成功"
    fi
}
function change_password(){
	echo -e "\033[31m注意：你必须正确填写数据库原密码，否则只能手动修改\033[0m"
	read -p "请输入数据库原密码(初始密码为root):" Default_password
	Default_password=${Default_password:-"root"}
	read -p "请输入要设置的数据库密码:" Change_password
	Change_password=${Change_password:-"root"}
	echo -e "\033[31m你设置的密码是:${Change_password}\033[0m"
mysql -hlocalhost -uroot -p$Default_password --default-character-set=utf8<<EOF
use mysql;
update user set password=passworD("${Change_password}") where user='root';
flush privileges;
EOF
	echo "开始替换设置文件中的数据库信息..."
	myFile="/root/shadowsocksr/server.py"
    if [ ! -f "$myFile" ]; then  
    sed -i "s/'password' => '"${Default_password}"'/'password' => '"${Change_password}"'/g" /home/wwwroot/default/config/database.php
	echo "数据库密码修改完成，请你牢记。"
	echo "你的数据库密码是：${Change_password}"
	else
	sed -i 's/"password": "'${Default_password}'",/"password": "'${Change_password}'",/g' /root/shadowsocksr/usermysql.json
	sed -i "s/'password' => '"${Default_password}"'/'password' => '"${Change_password}"'/g" /home/wwwroot/default/config/database.php
	echo "重启使配置生效中..."
	init 6
    fi

}
function install_ssr(){
	yum -y update
	yum -y install git 
	yum -y install python-setuptools && easy_install pip 
	yum -y groupinstall "Development Tools" 
	#512M的小鸡增加1G的Swap分区
	dd if=/dev/zero of=/var/swap bs=1024 count=1048576
	mkswap /var/swap
	chmod 0644 /var/swap
	swapon /var/swap
	echo '/var/swap   swap   swap   default 0 0' >> /etc/fstab
	wget https://download.libsodium.org/libsodium/releases/libsodium-1.0.13.tar.gz
	tar xf libsodium-1.0.13.tar.gz && cd libsodium-1.0.13
	./configure && make -j2 && make install
	echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	ldconfig
	yum -y install python-setuptools
	easy_install supervisor
    cd /root
	wget https://raw.githubusercontent.com/echo-marisn/ssrpanel-one-click-script/master/ssr-3.4.0.zip
	unzip ssr-3.4.0.zip
	cd shadowsocksr
	./setup_cymysql.sh
	./initcfg.sh
	wget -N -P /root/shadowsocksr/ https://raw.githubusercontent.com/echo-marisn/ssrpanel-one-click-script/master/user-config.json
	wget -N -P /root/shadowsocksr/ https://raw.githubusercontent.com/echo-marisn/ssrpanel-one-click-script/master/userapiconfig.py
	wget -N -P /root/shadowsocksr/ https://raw.githubusercontent.com/echo-marisn/ssrpanel-one-click-script/master/usermysql.json
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
    echo -e "\033[31m 添加节点...\033[0m"
	echo
	sed -i '$a * hard nofile 512000\n* soft nofile 512000' /etc/security/limits.conf
	[ $(id -u) != "0" ] && { echo "错误：你必须使用root用户登录"; exit 1; }
	echo -e "下面不会的都可以直接回车"
	echo -e "对接失败请检查数据库远程访问是否打开"
	read -p "请输入你的对接数据库IP(回车默认本机):" Userip
	read -p "请输入数据库名(回车默认ssrpanel):" Dbname
	read -p "请输入数据库端口(回车默认3306):" Dbport
	read -p "请输入数据库账号(回车默认root):" Dbuser
	read -p "请输入数据库密码(回车默认root):" Dbpassword
	read -p "请输入你的节点编号(回车默认1):  " UserNODE_ID
	IPAddress=`wget http://members.3322.org/dyndns/getip -O - -q ; echo`;
	Userip=${Userip:-"${IPAddress}"}
	Dbname=${Dbname:-"ssrpanel"}
	Dbport=${Dbport:-"3306"}
	Dbuser=${Dbuser:-"root"}
	Dbpassword=${Dbpassword:-"root"}
	UserNODE_ID=${UserNODE_ID:-"1"}
	install_ssr
    # 启用supervisord
	echo_supervisord_conf > /etc/supervisord.conf
	sed -i '$a [program:ssr]\ncommand = python /root/shadowsocksr/server.py\nuser = root\nautostart = true\nautorestart = true' /etc/supervisord.conf
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
	clear
	echo -e "\033[31m#################################################\033[0m"
	echo -e "\033[32m# 节点添加成功，登录前端站点看看吧              #\033[0m"
	echo -e "\033[33m# 重启使节点生效中...                           #\033[0m"
	echo -e "\033[33m# Author: 十一          Ssrpanel:胖虎           #\033[0m"
	echo -e "\033[32m# Blog: http://blog.67cc.cn/                    #\033[0m"
	echo -e "\033[31m#################################################\033[0m"
	reboot
}
function install_BBR(){
     wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh&&chmod +x bbr.sh&&./bbr.sh
}
function install_RS(){
     wget -N --no-check-certificate https://github.com/91yun/serverspeeder/raw/master/serverspeeder.sh && bash serverspeeder.sh
}
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
ulimit -c 0
rm -rf ssrpanel*
clear
echo
pass='blog.67cc.cn';
echo -e "Please verify the blog address: [\033[32m $pass \033[0m] "
read inputPass
if [ "$inputPass" != "$pass" ];then
    #网址验证
     echo -e "\033[31mI'm sorry for the input error.\033[0m";
     exit 1;
fi;
clear
echo -e "\033[31m#############################################################\033[0m"
echo -e "\033[32m#欢迎使用一键SS-panel V3_mod_panel搭建脚本 and 节点添加     #\033[0m"
echo -e "\033[33m#请选择你要搭建的脚本：                                     #\033[0m"
echo -e "\033[34m#1.  一键SSR-panel搭建                                      #\033[0m"
echo -e "\033[35m#2.  一键添加SS-panel节点                                   #\033[0m"
echo -e "\033[36m#3.  一键  BBR加速  搭建[来自秋水逸冰]                      #\033[0m"
echo -e "\033[37m#4.  一键锐速破解版搭建 [来自91yun]                         #\033[0m"
echo -e "\033[36m#5.  升级到最新SSR-panel [官方升级脚本]                     #\033[0m"
echo -e "\033[35m#6.  日志分析（目前仅支持单机单节点）                       #\033[0m" 
echo -e "\033[34m#7.  数据库密码一键更改                                     #\033[0m" 
echo -e "\033[33m#                      PS:建议先搭建加速再搭建胖虎的ssrpanel#\033[0m"
echo -e "\033[32m#                                     适用于 Centos  7.x系统#\033[0m"
echo -e "\033[31m#############################################################\033[0m"
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