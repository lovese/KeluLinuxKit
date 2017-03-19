#!/bin/bash

. /etc/profile

JSON_FILE=/var/local/ss-bash/ssmlt.json
USER_FILE=/var/local/ss-bash/ssusers
TMPL_FILE=/var/local/ss-bash/ssmlt.template
SERVERNAME="tokyo"
IS_LOG=1

create_json () {
    echo '{' > $JSON_FILE.tmp
    sed -E 's/(.*)/    \1/' $TMPL_FILE >> $JSON_FILE.tmp
    awk '
    BEGIN {
        i=1;
        printf("    \"port_password\": {\n");
    }
    ! /^#|^\s*$/ {
        port=$1;
        pw=$2;
        ports[i++] = port;
        pass[port]=pw;
    }
    END {
        for(j=1;j<i;j++) {
            port=ports[j];
            printf("        \"%s\": \"%s\"", port, pass[port]);
            if(j<i-1) printf(",");
            printf("\n");
        }
        printf("    }\n");
    }
    ' $USER_FILE >> $JSON_FILE.tmp
    echo '}' >> $JSON_FILE.tmp
    mv $JSON_FILE.tmp $JSON_FILE
}

get_file_h(){
FILE=$1
NUM=`ls -l $FILE | awk '{print $(NF-1)}' | cut -d ':' -f 1`;
echo $NUM
}

get_file_m(){
FILE=$1
NUM=`ls -l $FILE | awk '{print $(NF-1)}' | cut -d ':' -f 2`;
echo $NUM
}

cmp_file(){
FILE1=$1
FILE2=$2

H=`get_file_h $FILE1`;
M=`get_file_m $FILE1`;
DH=`get_file_h $FILE2`;
DM=`get_file_m $FILE2`;

FLAG=1;
# 目标文件更新时间 大于 源文件
if [ $DH -gt $H ]; then
    FLAG=0;
    # 文件更新小时相等，目标文件更新分钟大于源文件，还是不需要改
  elif [ $DH -eq $H ]; then
    if [ $DM -gt $M ]; then
    FLAG=0;
    fi
fi

echo $FLAG;
}

ppp_to_client(){
PPP="/var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets";
PPPD="/etc/ppp/chap-secrets";

FLAG=`cmp_file $PPP $PPPD`;
if [ $FLAG -eq 1 ]; then
  cp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets /etc/ppp/chap-secrets;
  cp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets /tmp/restart_ppp.tmp;

  scp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets tokyo2:/etc/ppp/chap-secrets;
  scp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets tokyo2:/tmp/restart_ppp.tmp;

#  scp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets tokyo3:/etc/ppp/chap-secrets;
#  scp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets tokyo3:/tmp/restart_ppp.tmp;

  scp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets aliyun:/etc/ppp/chap-secrets;
  scp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets aliyun:/tmp/restart_ppp.tmp;
fi
}

check_if_update(){
    if [ -e /tmp/restart_ppp.tmp ]; then
        echo 'restart ppp';
        docker restart pptp;
        service pppd-dns restart
        service ipsec restart
        service xl2tpd restart
        rm /tmp/restart_ppp.tmp;
    fi

    if [ -e /tmp/restart_ss.tmp ]; then
        echo 'restart ss';
        docker restart ss;
        rm /tmp/restart_ss.tmp;
    fi
}

ss_to_client(){
SS="/var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/ssusers";
SSD="/var/local/ss-bash/ssusers";

FLAG=`cmp_file $SS $SSD`;
if [ $FLAG -eq 1 ]; then
  cp /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/ssusers $USER_FILE;
  create_json
  scp $JSON_FILE tokyo2:/var/local/ss-bash/ssmlt.json;
  scp $JSON_FILE tokyo2:/tmp/restart_ss.tmp;

#  scp $JSON_FILE tokyo3:/var/local/ss-bash/ssmlt.json;
#  scp $JSON_FILE tokyo3:/tmp/restart_ss.tmp;

  scp $JSON_FILE aliyun:/var/local/ss-bash/ssmlt.json;
  scp $JSON_FILE aliyun:/tmp/restart_ss.tmp;
fi
}

heartbeat(){
# heartbeat
REMOTEURL=$WECAT_MASTER_API"/pptp"
ifconfig=`ifconfig`;
type='heartbeat';
client=`hostname`;

REMOTE_CONTENT="type=$type&client=$client&ifconfig=$ifconfig";
# REMOTERESULT=`curl -d "$REMOTE_CONTENT" $REMOTEURL`;
}

if [ `hostname` = 'tokyo' ]; then
ppp_to_client
ss_to_client
heartbeat
# cmp_file /var/local/fpm-pools/wechat/www/storage/app/vpn/ppp/chap-secrets /etc/ppp/chap-secrets
fi

check_if_update
