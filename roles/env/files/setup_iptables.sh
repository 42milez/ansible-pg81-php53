#!/bin/bash

LOCALNET=192.168.33.0/24

# ----------------------------------------------------------------------
#  Default Rules
# ----------------------------------------------------------------------
IPTABLES_CONFIG=`mktemp`
echo "*filter" >> $IPTABLES_CONFIG
echo ":INPUT DROP [0:0]" >> $IPTABLES_CONFIG        # approve all INCOMING packets
echo ":FORWARD DROP [0:0]" >> $IPTABLES_CONFIG      # discard all FORWARDING packets
echo ":OUTPUT ACCEPT [0:0]" >> $IPTABLES_CONFIG     # approve all OUTGOING packets
echo ":LOG_PINGDEATH - [0:0]" >> $IPTABLES_CONFIG   # discard Ping of Death attack

# ----------------------------------------------------------------------
#  Approve incoming packets from:
# ----------------------------------------------------------------------
# known hosts
echo "-A INPUT -i lo -j ACCEPT" >> $IPTABLES_CONFIG

# private network
echo "-A INPUT -s $LOCALNET -j ACCEPT" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Approve incoming packets relates to related/established session
# ----------------------------------------------------------------------
echo "-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Enable SYN Cookies for preventing from TCP SYN Flood attack
# ----------------------------------------------------------------------
sysctl -w net.ipv4.tcp_syncookies=1 > /dev/null
sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf

# ----------------------------------------------------------------------
#  Don't reply for the ping sent to broadcast address for preventing from Smurf attack
# ----------------------------------------------------------------------
sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 > /dev/null
sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.conf

# ----------------------------------------------------------------------
#  Reject ICMP Redirect packets
# ----------------------------------------------------------------------
sed -i '/net.ipv4.conf.*.accept_redirects/d' /etc/sysctl.conf
for dev in `ls /proc/sys/net/ipv4/conf/`
do
  sysctl -w net.ipv4.conf.$dev.accept_redirects=0 > /dev/null
  echo "net.ipv4.conf.$dev.accept_redirects=0" >> /etc/sysctl.conf
done

# ----------------------------------------------------------------------
#  Reject Source Routed packets
# ----------------------------------------------------------------------
sed -i '/net.ipv4.conf.*.accept_source_route/d' /etc/sysctl.conf
for dev in `ls /proc/sys/net/ipv4/conf/`
do
  sysctl -w net.ipv4.conf.$dev.accept_source_route=0 > /dev/null
  echo "net.ipv4.conf.$dev.accept_source_route=0" >> /etc/sysctl.conf
done

# ----------------------------------------------------------------------
#  Discard fragmented packets
# ----------------------------------------------------------------------
echo "-A INPUT -f -j LOG --log-prefix \"[IPTABLES FRAGMENT] : \"" >> $IPTABLES_CONFIG
echo "-A INPUT -f -j DROP" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Discard the packets sent between NetBIOS and external network
#  for preventing from logging unnecessary logs
# ----------------------------------------------------------------------
echo "-A INPUT ! -s $LOCALNET -p tcp -m multiport --dports 135,137,138,139,445 -j DROP" >> $IPTABLES_CONFIG
echo "-A INPUT ! -s $LOCALNET -p udp -m multiport --dports 135,137,138,139,445 -j DROP" >> $IPTABLES_CONFIG
echo "-A OUTPUT ! -d $LOCALNET -p tcp -m multiport --sports 135,137,138,139,445 -j DROP" >> $IPTABLES_CONFIG
echo "-A OUTPUT ! -d $LOCALNET -p udp -m multiport --sports 135,137,138,139,445 -j DROP" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Discard the ping sent over 4 times in a second for preventing from
#  Ping of Death attack
# ----------------------------------------------------------------------
echo "-A LOG_PINGDEATH -m limit --limit 1/s --limit-burst 4 -j ACCEPT" >> $IPTABLES_CONFIG
echo "-A LOG_PINGDEATH -j LOG --log-prefix \"[IPTABLES PINGDEATH] : \"" >> $IPTABLES_CONFIG
echo "-A LOG_PINGDEATH -j DROP" >> $IPTABLES_CONFIG
echo "-A INPUT -p icmp --icmp-type echo-request -j LOG_PINGDEATH" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Discard the packet sent to broadcase/multicast address for preventing from
#  logging unnecessary logs
# ----------------------------------------------------------------------
echo "-A INPUT -d 255.255.255.255 -j DROP" >> $IPTABLES_CONFIG
echo "-A INPUT -d 224.0.0.1 -j DROP" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Reject all incoming packets sent to port 113 (IDENT) for preventing mail server
#  from dropping the performance
# ----------------------------------------------------------------------
echo "-A INPUT -p tcp --dport 113 -j REJECT --reject-with tcp-reset" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Approve other connections
# ----------------------------------------------------------------------
echo "-A INPUT -p tcp --dport 22 -j ACCEPT" >> $IPTABLES_CONFIG
echo "-A INPUT -p tcp --dport 80 -j ACCEPT" >> $IPTABLES_CONFIG
echo "-A INPUT -p tcp --dport 443 -j ACCEPT" >> $IPTABLES_CONFIG
echo "-A INPUT -p tcp --dport 3306 -j ACCEPT" >> $IPTABLES_CONFIG
echo "-A INPUT -p tcp --dport 5432 -j ACCEPT" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Discard all packets does not match the rules above
# ----------------------------------------------------------------------
echo "-A INPUT -m limit --limit 1/s -j LOG --log-prefix \"[IPTABLES INPUT] : \"" >> $IPTABLES_CONFIG
echo "-A INPUT -j DROP" >> $IPTABLES_CONFIG
echo "-A FORWARD -m limit --limit 1/s -j LOG --log-prefix \"[IPTABLES FORWARD] : \"" >> $IPTABLES_CONFIG
echo "-A FORWARD -j DROP" >> $IPTABLES_CONFIG

# ----------------------------------------------------------------------
#  Commit changes
# ----------------------------------------------------------------------
echo "COMMIT" >> $IPTABLES_CONFIG
cat $IPTABLES_CONFIG > /etc/sysconfig/iptables
if [ -f /usr/libexec/iptables/iptables.init ]; then
  /usr/libexec/iptables/iptables.init restart
else
  /etc/rc.d/init.d/iptables restart
fi
rm -f $IPTABLES_CONFIG
