NORMAL=`echo "\033[m"`
BRED=`printf "\e[1;31m"`
BGREEN=`printf "\e[1;32m"`
BYELLOW=`printf "\e[1;33m"`
COLUMNS=12

printf "#   #  ###  #   #   #   ##### \n"
printf "#   # #   # ## ##  # #   #  #  \n"
printf "##### #   # # # # #####  #  # \n"
printf "#   # #   # #   # #   #  ####  \n"
printf "#   #  ###  #   # #   # #    # \n"
printf "\n"
nomad_action() {
	printf "\n${BGREEN}[+]${NORMAL} $1\n"
}

nomad_warning() {
	printf "\n${BYELLOW}[!]${NORMAL} $1\n"
}

nomad_error() {
	printf "\n${BRED}[!] $1${NORMAL}\n"
}

error_exit() {
	echo -e "\n$1\n" 1>&2
	exit 1
}

check_errors() {
	if [ $? -ne 0 ]; then
   		nomad_error "An error occurred..."
  		error_exit "Exiting..."
	fi
}

nomad_install(){
	CONF_PATH="/etc/nginx/sites-enabled/default"
	nomad_action "Installing Dependencies..."
	apt-get install -y vim less

	nomad_action "Updating apt-get..."
	apt-get update
	check_errors

	nomad_action "Installing Net Tools..."
	apt-get install -y inetutils-ping net-tools screen dnsutils curl
	check_errors

	nomad_action "Installing git nginx..."
	apt-get install -y nginx git

	nomad_action "Installing certbot..."
	sudo apt install certbot python3-certbot-nginx

	nomad_action "Scheduling Cron"
	touch /etc/cron.d/nomad_cron
	echo "0 0,12 * * * root python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/bin/certbot renew --quiet && service nginx restart" >> /etc/cron.d/nomad_cron
	check_errors

	nomad_action "Installing ufw..."
	sudo apt-get install ufw

	nomad_action "Finished Installing Dependancies."
}

nomad_init() {
	nomad_action "Configuring Nginx"
	sudo ufw allow 'Nginx Full'


	if [ "$#" -ne 2 ]; then
		read -r -p "What is the domain name? (ex: google.com) " domain_name
		read -r -p "What is the C2 server IP address? (IP:Port)" c2_server
	else
		domain_name=$1
		c2_server=$2
	fi

	cp ./default.conf $CONF_PATH

	sed -i.bak "s/<DOMAIN_NAME>/$domain_name/" $CONF_PATH
	rm $CONF_PATH.bak

	sed -i.bak "s/<C2_SERVER>/$c2_server/" $CONF_PATH
	rm $CONF_PATH.bak
	check_errors

	read -r -p "Would you like to configure HTTPS? (Y/N)" HTTPS
	if [ $HTTPS -ne "N" ]; then

		SSL_SRC="/etc/letsencrypt/live/$domain_name"
		nomad_action "Obtaining Certificates..."
		sudo certbot --nginx -d $domain_name -d www.$domain_name 

		nomad_action "Installing Certificates..."
		sed -i.bak "s/^#nomad#//g" $CONF_PATH
		rm $CONF_PATH.bak
		check_errors

		nomad_action "Restarting Nginx..."
		systemctl restart nginx.service
		check_errors
		nomad_action "Finished!"

	else

		nomad_action "Finished!"

	fi
}

nomad_setup() {
	nomad_install
	nomad_init $1 $2
}

nomad_status() {
	printf "\n**************************************** Processes ****************************************\n"
	ps -aux | grep -E 'nginx' | grep -v grep

	printf "\n**************************************** Network ****************************************\n"
	netstat -tulpn | grep -E 'nginx'
}

if ["$#" -ne 2]; then
	printf "NOMAD - Select an option"
	finished=0

	while (( !finished )); do
		printf "\n"
		options=("Setup Nginx Redirect", "Check Status", "Exit")
		select opt in "{$options[@]}"
		do
			case $opt in
				"Setup Nginx Redirect")
					nomad_setup
					break;
					;;
				"Check Status")
					nomad_status
					break;
					;;
				"Exit")
					finished=1
					break;
					;;
				*) printf "Try again" ;;
			esac
		done
	done
else
	nomad_setup $1 $2
fi
