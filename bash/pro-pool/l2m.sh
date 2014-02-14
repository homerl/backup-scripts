#! /bin/bash
###########################################################################
# Script:       l2m.sh
# Author:       Homer Li
# Modify:       Homer Li
# Date:         2013-01-16
# Email:        liyan2@genomics.cn
# Usage:        $0 [options]

###########################################################################


function run_cmd {
    ssh -n $line $cmd
    echo $line"finish"
    echo >&3
}

if [[ $# -lt 1 ]]
then
    echo "Please input command, USAGE:"$0" command 2>/tmp/error"
    echo "eg:"$0" shutdown -h now 2>/tmp/error"
    exit 2
fi

cmd=$*
echo $cmd

fifo="/tmp/$$.fifo"
mkfifo $fifo
exec 3<>$fifo
rm -f fifo

pro_num=64
for ((i=0;i<$pro_num;i++))
do
    echo
done >&3

nmap -v  | grep 4.[0-9]*
if [ $? -eq 0 ]
then
    nmap -sP -n 10.{0,1}.10.* |  nmap -sP -n 10.{0,1}.10.* | awk '{if($2~/10.*/) print $2}' | while read line
    do
        read -u 3
        {
            run_cmd
        } &
    done
else
    nmap -sP -n 10.{0,1}.10.* | awk '{gsub(/[()]/,"");if($NF~/10.*/) print $NF}' | while read line
    do
        read -u 3
        {
            run_cmd
        } &
    done
fi
