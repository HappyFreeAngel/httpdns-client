#这是个httpdns 实现方案.
#作为 mesos-dns  httpdns 客户端。确保域名解析实时有效。


依赖 tq  awk  命令, 如果系统上没有请先安装.

用法: 
cp /etc/hosts hosts.j2
sudo ./httpdns.sh 
