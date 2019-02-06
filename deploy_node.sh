#!/usr/bin/env bash
# Require Root Permission
# panel node deploy script
# Author: 阿拉凹凸曼 (https://sobaigu.com)

[ $(id -u) != "0" ] && { echo "错误: 请用root执行"; exit 1; }
sys_bit=$(uname -m)
if [[ -f /usr/bin/apt ]] || [[ -f /usr/bin/yum && -f /bin/systemctl ]]; then
	if [[ -f /usr/bin/yum ]]; then
		cmd="yum"
		$cmd -y install epel-release
	fi
	if [[ -f /usr/bin/apt ]]; then
		cmd="apt"
	fi
	if [[ -f /bin/systemctl ]]; then
		systemd=true
	fi

else
	echo -e " 哈哈……这个 ${red}辣鸡脚本${none} 不支持你的系统。 ${yellow}(-_-) ${none}" && exit 1
fi

service_Cmd() {
	if [[ $systemd ]]; then
		systemctl $1 $2
	else
		service $2 $1
	fi
}

$cmd update -y
$cmd install -y wget curl unzip git gcc vim lrzsz screen ntp ntpdate cron net-tools telnet python-pip m2crypto
# 设置时区为CST
echo yes | cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
ntpdate cn.pool.ntp.org
hwclock -w
sed -i '/^.*ntpdate*/d' /etc/crontab
sed -i '$a\* * * * 1 ntpdate cn.pool.ntp.org >> /dev/null 2>&1' /etc/crontab
service_Cmd restart crond

error() {

	echo -e "\n$red 输入错误！$none\n"

}
pause() {

	read -rsp "$(echo -e "按$green Enter 回车键 $none继续....或按$red Ctrl + C $none取消.")" -d $'\n'
	echo
}
get_ip() {
	ip=$(curl -s https://ipinfo.io/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.ip.sb/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.ipify.org)
	[[ -z $ip ]] && ip=$(curl -s https://ip.seeip.org)
	[[ -z $ip ]] && ip=$(curl -s https://ifconfig.co/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.myip.com | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
	[[ -z $ip ]] && ip=$(curl -s icanhazip.com)
	[[ -z $ip ]] && ip=$(curl -s myip.ipip.net | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
	[[ -z $ip ]] && echo -e "\n$red 这小鸡鸡还是割了吧！$none\n" && exit
}

config_v2ray_caddy() {
	read -p "伪装域名，如 sobaigu.com ：" fake_Domain
	read -p "伪装端口，如 443 ：" fake_port
	read -p "Cloudflare email: " CUSTOM_CLOUDFLARE_EMAIL
	read -p "Cloudflare api key: " CUSTOM_CLOUDFLARE_API_KEY
	read -p "$(echo -e "$yellow转发路径$none(不要带/，默认：${cyan}game$none)")：" forward_Path
		[ -z "$forward_Path" ] && forward_Path="game"
	read -p "$(echo -e "$yellow V2Ray端口$none(不可80/443，默认：${cyan}10086$none)")：" v2ray_Port
		[ -z "$v2ray_Port" ] && v2ray_Port="10086"
	read -p "$(echo -e "$yellow V2Ray额外ID$none(默认：${cyan}16$none)")：" alter_Id
		[ -z "$alter_Id" ] && alter_Id="16"
	read -p "$(echo -e "$yellow配置同步端口$none(不可80/443，默认：${cyan}10085$none)")：" usersync_Port
		[ -z "$usersync_Port" ] && usersync_Port="10085"
	read -p "面板分配的节点ID，如 6 ：" node_Id
	read -p "数据库地址，如 1.1.1.1 ：" db_Host
	read -p "$(echo -e "$yellow数据库名称$none(默认：${cyan}3306$none)")：" db_Port
		[ -z "$db_Port" ] && db_Port="3306"
	read -p "$(echo -e "$yellow数据库名称$none(默认：${cyan}ssrpanel$none)")：" db_Name
		[ -z "$db_Name" ] && db_Name="ssrpanel"
	read -p "$(echo -e "$yellow数据库用户$none(默认：${cyan}ssrpanel$none)")：" db_User
		[ -z "$db_User" ] && db_User="ssrpanel"
	read -p "数据库密码，如 ssrpanel ：" db_Password
	install_caddy
	install_v2ray
	firewall_set
	service_Cmd status caddy
	service_Cmd status v2ray
}

config_v2ray() {
	read -p "面板分配的节点ID，如 6 ：" node_Id
	read -p "$(echo -e "$yellow V2Ray端口$none(不可80/443，默认：${cyan}10086$none)")：" v2ray_Port
		[ -z "$v2ray_Port" ] && v2ray_Port="10086"
	read -p "$(echo -e "$yellow配置同步端口$none(不可80/443，默认：${cyan}10085$none)")：" usersync_Port
		[ -z "$usersync_Port" ] && usersync_Port="10085"
	read -p "$(echo -e "$yellow转发路径$none(不要带/，默认：${cyan}game$none)")：" forward_Path
		[ -z "$forward_Path" ] && forward_Path="game"
	read -p "$(echo -e "$yellow V2Ray额外ID$none(默认：${cyan}16$none)")：" alter_Id
		[ -z "$alter_Id" ] && alter_Id="16"
	read -p "数据库地址，如 1.1.1.1 ：" db_Host
	read -p "$(echo -e "$yellow数据库名称$none(默认：${cyan}3306$none)")：" db_Port
		[ -z "$db_Port" ] && db_Port="3306"
	read -p "$(echo -e "$yellow数据库名称$none(默认：${cyan}ssrpanel$none)")：" db_Name
		[ -z "$db_Name" ] && db_Name="ssrpanel"
	read -p "$(echo -e "$yellow数据库用户$none(默认：${cyan}ssrpanel$none)")：" db_User
		[ -z "$db_User" ] && db_User="ssrpanel"
	read -p "数据库密码，如 ssrpanel ：" db_Password
	install_v2ray
	firewall_set
	service_Cmd status v2ray
	echo -e "默认日志输出级别为debug，搞定后建议修改为error"
	echo -e "完整配置示例可以参考这里：http://sobaigu.com/ssrpanel-v2ray-go.html#V2Ray"
}

config_caddy() {
	read -p "伪装域名，如 sobaigu.com ：" fake_Domain
	read -p "伪装端口，如 443 ：" fake_port
	read -p "Cloudflare email: " CUSTOM_CLOUDFLARE_EMAIL
	read -p "Cloudflare api key: " CUSTOM_CLOUDFLARE_API_KEY
	read -p "$(echo -e "$yellow转发路径$none(不要带/，默认：${cyan}game$none)")：" forward_Path
		[ -z "$forward_Path" ] && forward_Path="game"
	read -p "$(echo -e "$yellow转发到V2Ray端口$none(不可80/443，默认：${cyan}10086$none)")：" v2ray_Port
		[ -z "$v2ray_Port" ] && v2ray_Port="10086"
	install_caddy
	firewall_set
	service_Cmd status caddy
}

install_v2ray(){
	curl -L -s https://raw.githubusercontent.com/ColetteContreras/v2ray-ssrpanel-plugin/master/install-release.sh | bash
	wget --no-check-certificate -O config.json https://raw.githubusercontent.com/yulewang/Shell/master/resource/v2ray-config.json
	sed -i -e "s/v2ray_Port/$v2ray_Port/g" config.json
	sed -i -e "s/alter_Id/$alter_Id/g" config.json
	sed -i -e "s/forward_Path/$forward_Path/g" config.json
	sed -i -e "s/usersync_Port/$usersync_Port/g" config.json
	sed -i -e "s/node_Id/$node_Id/g" config.json
	sed -i -e "s/db_Host/$db_Host/g" config.json
	sed -i -e "s/db_Port/$db_Port/g" config.json
	sed -i -e "s/db_Name/$db_Name/g" config.json
	sed -i -e "s/db_User/$db_User/g" config.json
	sed -i -e "s/db_Password/$db_Password/g" config.json
	mv -f config.json /etc/v2ray/
	service_Cmd restart v2ray
}

install_caddy() {
	if [[ $cmd == "yum" ]]; then
		[[ $(pgrep "httpd") ]] && systemctl stop httpd
		[[ $(command -v httpd) ]] && yum remove httpd -y
	else
		[[ $(pgrep "apache2") ]] && service apache2 stop
		[[ $(command -v apache2) ]] && apt remove apache2* -y
	fi

	local caddy_tmp="/tmp/install_caddy/"
	local caddy_tmp_file="/tmp/install_caddy/caddy.tar.gz"
	if [[ $sys_bit == "i386" || $sys_bit == "i686" ]]; then
		local caddy_download_link="https://caddyserver.com/download/linux/386?license=personal&plugins=tls.dns.cloudflare"
	elif [[ $sys_bit == "x86_64" ]]; then
		local caddy_download_link="https://caddyserver.com/download/linux/amd64?license=personal&plugins=tls.dns.cloudflare"
	else
		echo -e "$red 自动安装 Caddy 失败！不支持你的系统。$none" && exit 1
	fi

	mkdir -p $caddy_tmp

	if ! wget --no-check-certificate -O "$caddy_tmp_file" $caddy_download_link; then
		echo -e "$red 下载 Caddy 失败！$none" && exit 1
	fi

	tar zxf $caddy_tmp_file -C $caddy_tmp
	cp -f ${caddy_tmp}caddy /usr/local/bin/

	if [[ ! -f /usr/local/bin/caddy ]]; then
		echo -e "$red 安装 Caddy 出错！" && exit 1
	fi

	setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/caddy

	wget --no-check-certificate -O caddy.service https://raw.githubusercontent.com/yulewang/Shell/master/resource/caddy.service
	if [[ $systemd ]]; then
		sed -i -e "s/CUSTOM_CLOUDFLARE_EMAIL/$CUSTOM_CLOUDFLARE_EMAIL/g" caddy.service
		sed -i -e "s/CUSTOM_CLOUDFLARE_API_KEY/$CUSTOM_CLOUDFLARE_API_KEY/g" caddy.service
		mv -f caddy.service /lib/systemd/system/caddy.service
		# cp -f ${caddy_tmp}init/linux-systemd/caddy.service /lib/systemd/system/
		# sed -i "s/www-data/root/g" /lib/systemd/system/caddy.service
		sed -i "s/on-failure/always/" /lib/systemd/system/caddy.service
		systemctl enable caddy
	else
		cp -f ${caddy_tmp}init/linux-sysvinit/caddy /etc/init.d/caddy
		# sed -i "s/www-data/root/g" /etc/init.d/caddy
		chmod +x /etc/init.d/caddy
		update-rc.d -f caddy defaults
	fi

	mkdir -p /etc/ssl/caddy

	if [ -z "$(grep www-data /etc/passwd)" ]; then
		useradd -M -s /usr/sbin/nologin www-data
	fi
	chown -R www-data.www-data /etc/ssl/caddy

	# if [[ -d /home/${fake_Domain}_rsa ]]; then
	# 	cp /home/${fake_Domain}_rsa/fullchain.cer /etc/ssl/caddy/fullchain.cer
	# 	cp /home/${fake_Domain}_rsa/${fake_Domain}.key /etc/ssl/caddy/${fake_Domain}.key
	# fi

	rm -rf $caddy_tmp
	echo -e "Caddy安装完成！"

	# 放个本地游戏网站
	wget --no-check-certificate -O www.zip https://raw.githubusercontent.com/yulewang/Shell/master/resource/www.zip
	unzip -n www.zip -d /srv/ && rm -f www.zip
	# 修改配置
	mkdir -p /etc/caddy/
	wget --no-check-certificate -O Caddyfile https://raw.githubusercontent.com/yulewang/Shell/master/resource/Caddyfile
	# local user_Name=$(((RANDOM << 22)))
	# sed -i -e "s/user_Name/$user_Name/g" Caddyfile
	# local full_Chain=$(/etc/ssl/caddy/fullchain.cer)
	# local key_Chain=$(/etc/ssl/caddy/${fake_Domain}.key)
	# sed -i -e "s/full_chain/$full_Chain/g" Caddyfile
	# sed -i -e "s/key_chain/$key_Chain/g" Caddyfile
	sed -i -e "s/fake_Domain/$fake_Domain/g" Caddyfile
	sed -i -e "s/fake_port/$fake_port/g" Caddyfile
	sed -i -e "s/forward_Path/$forward_Path/g" Caddyfile
	sed -i -e "s/v2ray_Port/$v2ray_Port/g" Caddyfile
	mv -f Caddyfile /etc/caddy/
	service_Cmd restart caddy
}

# Firewall
firewall_set(){
	echo -e "[${green}Info${plain}] firewall set start..."
	if command -v firewall-cmd >/dev/null 2>&1; then
		systemctl status firewalld > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			firewall-cmd --permanent --zone=public --remove-port=443/tcp
			firewall-cmd --permanent --zone=public --remove-port=80/tcp
			firewall-cmd --permanent --zone=public --add-port=443/tcp
			firewall-cmd --permanent --zone=public --add-port=80/tcp
			if [[ $v2ray_Port ]]; then
				firewall-cmd --permanent --zone=public --remove-port=${v2ray_Port}/tcp
				firewall-cmd --permanent --zone=public --remove-port=${v2ray_Port}/udp
				firewall-cmd --permanent --zone=public --add-port=${v2ray_Port}/tcp
				firewall-cmd --permanent --zone=public --add-port=${v2ray_Port}/udp
				firewall-cmd --reload
			fi
			if [[ $single_Port_Num ]]; then
				firewall-cmd --permanent --zone=public --remove-port=${single_Port_Num}/tcp
				firewall-cmd --permanent --zone=public --remove-port=${single_Port_Num}/udp
				firewall-cmd --permanent --zone=public --add-port=${single_Port_Num}/tcp
				firewall-cmd --permanent --zone=public --add-port=${single_Port_Num}/udp
				firewall-cmd --reload
			fi
		else
			echo -e "[${yellow}Warning${plain}] firewalld looks like not running or not installed, please manually set it if necessary."
		fi
	elif command -v iptables >/dev/null 2>&1; then
		/etc/init.d/iptables status > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			iptables -D INPUT -p tcp --dport 443 -j ACCEPT
			iptables -D INPUT -p tcp --dport 80 -j ACCEPT
			iptables -A INPUT -p tcp --dport 443 -j ACCEPT
			iptables -A INPUT -p tcp --dport 80 -j ACCEPT
			ip6tables -D INPUT -p tcp --dport 443 -j ACCEPT
			ip6tables -D INPUT -p tcp --dport 80 -j ACCEPT
			ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT
			ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
			iptables -L -n | grep -i ${v2ray_Port} > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				iptables -D INPUT -p tcp --dport ${v2ray_Port} -j ACCEPT
				iptables -A INPUT -p tcp --dport ${v2ray_Port} -j ACCEPT
				iptables -D INPUT -p udp --dport ${v2ray_Port} -j ACCEPT
				iptables -A INPUT -p udp --dport ${v2ray_Port} -j ACCEPT
				ip6tables -D INPUT -p tcp --dport ${v2ray_Port} -j ACCEPT
				ip6tables -A INPUT -p tcp --dport ${v2ray_Port} -j ACCEPT
				ip6tables -D INPUT -p udp --dport ${v2ray_Port} -j ACCEPT
				ip6tables -A INPUT -p udp --dport ${v2ray_Port} -j ACCEPT
				/etc/init.d/iptables save
				/etc/init.d/iptables restart
				/etc/init.d/ip6tables save
				/etc/init.d/ip6tables restart
			else
				echo -e "[${green}Info${plain}] port 80, 443, ${v2ray_Port} has been set up."
			fi
			iptables -L -n | grep -i ${single_Port_Num} > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				iptables -D INPUT -p tcp --dport ${single_Port_Num} -j ACCEPT
				iptables -A INPUT -p tcp --dport ${single_Port_Num} -j ACCEPT
				iptables -D INPUT -p udp --dport ${single_Port_Num} -j ACCEPT
				iptables -A INPUT -p udp --dport ${single_Port_Num} -j ACCEPT
				ip6tables -D INPUT -p tcp --dport ${single_Port_Num} -j ACCEPT
				ip6tables -A INPUT -p tcp --dport ${single_Port_Num} -j ACCEPT
				ip6tables -D INPUT -p udp --dport ${single_Port_Num} -j ACCEPT
				ip6tables -A INPUT -p udp --dport ${single_Port_Num} -j ACCEPT
				/etc/init.d/iptables save
				/etc/init.d/iptables restart
				/etc/init.d/ip6tables save
				/etc/init.d/ip6tables restart
			else
				echo -e "[${green}Info${plain}] port 80, 443, ${single_Port_Num} has been set up."
			fi
		else
			echo -e "[${yellow}Warning${plain}] iptables looks like shutdown or not installed, please manually set it if necessary."
		fi
	fi
	echo -e "[${green}Info${plain}] firewall set completed..."
}

install_ssr(){
	pip install pymysql peewee pickle 
	clear
	cd /usr/
	rm -rf /usr/libsodium-1.0.16
	wget https://github.com/jedisct1/libsodium/releases/download/1.0.16/libsodium-1.0.16.tar.gz
	tar xf libsodium-1.0.16.tar.gz && cd libsodium-1.0.16
	./configure && make -j2 && make install
	echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	rm -rf libsodium-1.0.16.tar.gz
	echo 'libsodium安装完成'
	
	cd /usr/
	rm -rf /usr/shadowsocksr
	echo 'SSR下载中...'
	git clone -b master https://github.com/yulewang/shadowsocksr.git && cd shadowsocksr && bash setup_cymysql.sh && bash initcfg.sh
	echo 'SSR安装完成'
	echo '开始配置节点连接信息...'
	read -p "数据库服务器地址:" db_Host
	read -p "$(echo -e "$yellow数据库连接端口$none(默认：${cyan}3306$none)")：" db_Port
		[ -z "$db_Port" ] && db_Port="3306"
	read -p "$(echo -e "$yellow数据库名称$none(默认：${cyan}ssrpanel$none)")：" db_Name
		[ -z "$db_Name" ] && db_Name="ssrpanel"
	read -p "$(echo -e "$yellow数据库用户名$none(默认：${cyan}ssrpanel$none)")：" db_User
		[ -z "$db_User" ] && db_User="ssrpanel"
	read -p "$(echo -e "$yellow数据库密码$none(默认：${cyan}ssrpanel$none)")：" db_Password
		[ -z "$db_Password" ] && db_Password="ssrpanel"
	read -p "本节点ID:" node_Id
	read -p "流量计算比例:" transfer_Ratio
	sed -i -e "s/db_Host/$db_Host/g" usermysql.json
	sed -i -e "s/db_Port/$db_Port/g" usermysql.json
	sed -i -e "s/db_Name/$db_Name/g" usermysql.json
	sed -i -e "s/db_User/$db_User/g" usermysql.json
	sed -i -e "s/db_Password/$db_Password/g" usermysql.json
	sed -i -e "s/node_Id/$node_Id/g" usermysql.json
	sed -i -e "s/transfer_Ratio/$transfer_Ratio/g" usermysql.json
	echo -e "配置完成!\n如果无法连上数据库，请检查本机防火墙或者数据库防火墙!\n下一步配置user-config.json，配置节点加密方式、混淆、协议等"
	
	echo -e "是否强制单端口："$yellow"true"" or "$yellow"false"$none
	read -p "$(echo -e "(默认：${cyan}true$none)")：" single_Port_Enable
		[ -z "$single_Port_Enable" ] && single_Port_Enable="true"
	read -p "$(echo -e "$yellow输入单端口号$none(默认：${cyan}8080$none)")：" single_Port_Num
		[ -z "$single_Port_Num" ] && single_Port_Num="8080"
	read -p "$(echo -e "$yellow设置认证密码$none(默认：${cyan}forvip$none)")：" ss_Password
		[ -z "$ss_Password" ] && ss_Password="forvip"
	
	echo -e "选择加密方式：$yellow \n1. none\n2. aes-256-cfb\n3. chacha20\n4. aes-256-gcm"$none
	read -p "$(echo -e "(默认：${cyan}1. none$none)")：" ss_method
		[ -z "$ss_method" ] && ss_method="none"
	if [[ $ss_method ]]; then
		case $ss_method in
			1)
				ss_method="none"
				;;
			2)
				ss_method="aes-256-cfb"
				;;
			3)
				ss_method="chacha20"
				;;
			4)
				ss_method="aes-256-gcm"
				;;
		esac
	fi

	echo -e "选择传输协议：$yellow \n1. origin\n2. auth_sha1_v4\n3. auth_sha1_v4_compatible\n4. auth_chain_a\n5. auth_chain_a_compatible"$none
	read -p "$(echo -e "(默认：${cyan}1. origin$none)")：" ss_protocol
		[ -z "$ss_protocol" ] && ss_protocol="origin"
	if [[ $ss_protocol ]]; then
		case $ss_protocol in
			1)
				ss_protocol="origin"
				;;
			2)
				ss_protocol="auth_sha1_v4"
				;;
			3)
				ss_protocol="auth_sha1_v4_compatible"
				;;
			4)
				ss_protocol="auth_chain_a"
				;;
			5)
				ss_protocol="auth_chain_a_compatible"
				;;
		esac
	fi

	echo -e "选择混淆方式：$yellow \n1. plain\n2. http_simple\n3. tls1.2_ticket_auth\n4. tls1.2_ticket_auth_compatible"$none
	read -p "$(echo -e "(默认：${cyan}1. plain$none)")：" ss_obfs
		[ -z "$ss_obfs" ] && ss_obfs="plain"
	if [[ $ss_obfs ]]; then
		case $ss_obfs in
			1)
				ss_obfs="plain"
				;;
			2)
				ss_obfs="http_simple"
				;;
			3)
				ss_obfs="tls1.2_ticket_auth"
				;;
			4)
				ss_obfs="tls1.2_ticket_auth_compatible"
				;;
		esac
	fi

	read -p "$(echo -e "输入限制使用设备数：(默认：${cyan}不限制，直接回车即可$none)")：" ss_Online_Num
		[ -z "$ss_Online_Num" ] && ss_Online_Num=""

	read -p "$(echo -e "用户限速值(K)：(默认：${cyan}不限制，直接回车即可$none)")：" ss_Ban_Limit
		[ -z "$ss_Ban_Limit" ] && ss_Ban_Limit="0"

	sed -i -e "s/single_Port_Enable/$single_Port_Enable/g" user-config.json
	sed -i -e "s/single_Port_Num/$single_Port_Num/g" user-config.json
	sed -i -e "s/ss_Password/$ss_Password/g" user-config.json
	sed -i -e "s/ss_method/$ss_method/g" user-config.json
	sed -i -e "s/ss_protocol/$ss_protocol/g" user-config.json
	sed -i -e "s/ss_obfs/$ss_obfs/g" user-config.json
	sed -i -e "s/ss_Online_Num/$ss_Online_Num/g" user-config.json
	sed -i -e "s/ss_Ban_Limit/$ss_Ban_Limit/g" user-config.json

	#启动并设置开机自动运行
	chmod +x run.sh && ./run.sh
	sed -i "/shadowsocksr\/run.sh$/d"  /etc/rc.d/rc.local
	echo "/usr/shadowsocksr/run.sh" >> /etc/rc.d/rc.local
	firewall_set
}

open_bbr(){
	cd
	wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh
	chmod +x bbr.sh
	./bbr.sh
}

config_ssl(){
	cd
	wget --no-check-certificate https://raw.githubusercontent.com/yulewang/acme/master/acme_2.0.sh
	chmod +x acme_2.0.sh
	./acme_2.0.sh
}

echo -e "1.Install V2Ray+Caddy"
echo -e "2.Install V2Ray"
echo -e "3.Install Caddy"
echo -e "4.Install SSR"
echo -e "5.Open BBR"
echo -e "6.手动配置ssl with Let's Encrypt"
read -p "请输入数字进行安装[1-6]:" menu_Num
case "$menu_Num" in
	1)
	config_v2ray_caddy
	;;
	2)
	config_v2ray
	;;
	3)
	config_caddy
	;;
	4)
	install_ssr
	;;
	5)
	open_bbr
	;;
	6)
	config_ssl
	;;
	*)
	echo "请输入正确数字[1-5]:"
	;;
esac