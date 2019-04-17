#!/bin/bash

export MARATHON_HTTP_PORT=8080
export MARATHON_HOST_LIST="10.2.1.71,10.2.1.72,10.2.1.73"

#确保shell 切换到当前shell 脚本文件夹
current_file_path=$(cd "$(dirname "$0")"; pwd)
cd ${current_file_path}




while true
do
    date
    echo "判断marathon leader"
    for marathon_host in $(echo $MARATHON_HOST_LIST | tr ',' "\n")
         do
            leader_query_result=$(curl --silent http://${marathon_host}:8080/v2/leader | grep '\"leader\":' | tr '\"' ' ' | tr ':' ' ' | awk '{ print $3}')
            if [[ ! -z "$leader_query_result" ]];
            then
                MARATHON_LEADER=$leader_query_result
                break
            fi
         done
    #get marathon leader
    #http://10.20.5.71:8080/v2/leader
    #{"leader":"10.20.5.72:8080"}
    if [[ -z "$MARATHON_LEADER" ]];
    then
         echo "ERROR! Marathon Leader is unknown!"     #todo 如果是单个marathon 会不会报错?
         exit 1
    fi

    app_id_list=$(curl --silent http://${MARATHON_LEADER}:8080/v2/apps/ | jq '.apps' | jq [.[].id] | tr '[' " " | tr ']' " " | tr '\"' " " | tr '\,' " ")

    touch temp_hosts.txt

    `rm -f temp_hosts_latest.txt`
    touch temp_hosts_latest.txt

    for app_id in $app_id_list
        do
            arr=(`echo $app_id | tr '/' ' '`)
            count=${#arr[@]}
            app_domain=""
            for(( i=count-1;i>=0;i--))
            {
               if [[ -z $app_domain ]];
               then
                   app_domain=${arr[i]}
               else
                  app_domain="${app_domain}.${arr[i]}"
               fi
            }
            app_domain="${app_domain}.marathon.mesos"
            #row_host_record=$(curl http://10.2.1.71:8123/v1/hosts/jenkins.devops.marathon.mesos | jq .[] | jq  '(.ip +" "+ .host)')
            ip=$(curl --silent http://${MARATHON_LEADER}:8123/v1/hosts/${app_domain} | jq .[] | jq  '.ip' | tr '"' " ")
            row_host_record="${ip}  ${app_domain}"
            echo $row_host_record >> temp_hosts_latest.txt
       done

       #判断过去的时间里是否有变化。
       old_hosts_md5_value=$(md5 temp_hosts.txt | awk '{print $4}')
       latest_hosts_md5_value=$(md5 temp_hosts_latest.txt | awk '{print $4}')

       if [[ $latest_hosts_md5_value != $old_hosts_md5_value ]];
       then
             cp hosts.j2  /etc/hosts
             cat temp_hosts_latest.txt >> /etc/hosts

             #显示一下差异
              diff_result=$(diff temp_hosts.txt  temp_hosts_latest.txt)
              date >> ${current_file_path}/domain_change_history.log
              echo $diff_result >> ${current_file_path}/domain_change_history.log
              echo $diff_result

             `rm -f temp_hosts.txt`
             mv temp_hosts_latest.txt temp_hosts.txt
             echo "记录已经发生变化,主动更新了本地hosts记录."
             date
       else
           echo "休息30秒,再继续检测"
           sleep 30
       fi
done
