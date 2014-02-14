function echo_color() {
red='\e[0;31m'
green='\e[0;32m'
NC='\e[0m' #No Color
if [ $1 == "red" ]
then
	echo -e "${red}$2${NC}"
elif [ $1 == "green" ]
then
	echo -e "${green}$2${NC}"
fi
}

function check_err() {
if [ $1 != 0 ]
then
        echo_color "red" "return $1"
else
	echo_color "green" "return $1"
fi
}
