#!/bin/bash

#Prerequisites:
# - curl

#Default values
FORCE=false

usage() {
	echo "Usage: $0 ( -u <URL> | -f <FILE> ) [ -y ]"
	echo "-u <URL>: Unshorten the given URL."
	echo "-f <FILE>: Unshorten all URLs in file."
	echo "-y : In case the URL seems not to be shortened, bypass the asking message (force check)"
	exit 0
}

arguments_checks(){
	#Check if we cannot use both arguments.
	if [ ! -z "$URL" ] && [ ! -z "$FILE" ]
	then
	        echo -e '\e[0;31m[-] You cannot choose both options -u and -f. See -h or --help for more information.\e[0m' >&2
	        exit 1
	fi

	#Check at least one option is specified.
	if [ -z "$URL" ] && [ -z "$FILE" ]
	then
	        echo -e '\e[0;31m[-] You must choose at least one option: -u or -f. See -h or --help for more information.\e[0m' >&2
	        exit 1
	fi

	#Check that the file exists and is readable, only if the FILE argument is specified
	if [ ! -z "$FILE" ] 
	then
		if [ ! -r "$FILE" ]
		then
	        echo -e "\e[0;31m[-] $FILE is not accessible. Verify if file exists and have corect permissions.\e[0m" >&2
	        exit 1
	    fi
	fi
}

#Check if a wrong URL is given
check_valid_url(){
	STATUS=$(curl -Is "$1")
	if [ "$?" -ne 0 ]
	then
		echo -e "\e[0;31m[-] $1 -> Not valid or the host is not responding...\e[0m"
		return 1
	fi
}

#Check if URL is possibly a shortened one or not
check_shortened_url(){
	URL_PATH=$(echo "$1"|cut -d "/" -f4)
	LENGTH=${#URL_PATH}
	#If length > 11 then not a shortened link
	if [ "$LENGTH" -gt 11 ]
	then
		return 1
	else
		return 0
	fi
}

ask_user_force_check(){
	while true; do
		#Add </dev/tty to force input from user, instead we have an infinite loop.
	    read -p "Do you still want to check this URL? (y/n): " ANSWER </dev/tty
	    case $ANSWER in
	        [Yy]* ) return 0;;
	        [Nn]* ) exit 1;;
	        * ) echo "Please answer yes or no (y/n)";;
	    esac
	done
}

check_same_url(){
	if [ "$1" == "$2" ]
	then
		echo -e "\e[0;31m[-] $1 -> No redirection\e[0m"
	else
		echo -e "\e[0;32m[+] $1 -> redirection to $2\e[0m"
	fi
}

run_unshortener(){
	if ! check_shortened_url "$1"
	then
		echo -e "\e[1;33m[?] $1 -> seems not to be a shortened link...\e[0m"
		if [ "$FORCE" == false ]
		then
			ask_user_force_check
		fi
	fi

	if check_valid_url "$1"
	then
		RESPONSE=$(curl -Ls -o /dev/null -w %{url_effective} "$1")
		#Remove last slash
		RESPONSE="${RESPONSE%/}"
		check_same_url "$1" "$RESPONSE"
	fi
}

main(){
	#Case of unique URL
	if [ ! -z "$URL" ]
	then
		run_unshortener "$URL"
		exit 0
	#Case of file
	else
		LINES_COUNT=$(cat "$FILE"|wc -l)
		echo -e "\e[1;33m[+] Testing $LINES_COUNT URLs\e[0m"
		while read CURRENT_URL
		do
			run_unshortener "$CURRENT_URL"
			echo
		done < "$FILE"
		exit 0
	fi
}



while getopts ":u:f:hy" options
do
	case "${options}" in
		u)
			URL=${OPTARG}
			#Remove last slash if present
			URL="${URL%/}"
			;;
		f)
			FILE=${OPTARG}
			;;
		y)
			FORCE=true
			;;
		h)
			usage
			;;
		:)
      		echo -e "\e[0;31m[-] Error: -${OPTARG} requires an argument.\e[0m"
      		exit 1
	    	;;
	    *)
			echo -e "\e[0;31m[-] Unkown option... See -h or --help for more information\e[0m"
			exit 1
	      ;;
  	esac
done



arguments_checks
main
