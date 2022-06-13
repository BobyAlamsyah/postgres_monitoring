set -x
hostnamectl
date
uptime
uname -a
echo "   "
df -h
echo "   "
vmstat 2 10
echo "   "
free -mt; free -gt
echo "   "
ps -ef|grep mysql
echo "   "
ip a
cat /proc/meminfo | grep MemTotal
cat /proc/meminfo | grep Swap
cat /proc/cpuinfo | grep "model name"
cat /proc/cpuinfo | grep "model name" | wc -l
cat /etc/hosts
cat /etc/sysctl.conf
