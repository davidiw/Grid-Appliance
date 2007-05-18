#!/bin/bash
iptables -I INPUT -p tcp -i eth0 --dport 14999 -j ACCEPT
iptables -I OUTPUT -p tcp -o eth0 --sport 14999 -j ACCEPT
/usr/sbin/sshd -f /root/.ssh/sshd_config
