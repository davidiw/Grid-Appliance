/opt/condor/bin/condor_status -p 10.128.0.1 | awk /^C/ | awk -F. '{print $1}' > /tmp/cndor
/opt/condor/bin/condor_status -p 10.180.0.1 | awk /^C/ | awk -F. '{print $1}' >> /tmp/cndor
/opt/condor/bin/condor_status -p 10.190.0.1 | awk /^C/ | awk -F. '{print $1}' >> /tmp/cndor
echo "C128000001" >> /tmp/cndor
echo "C180000001" >> /tmp/cndor
echo "C190000001" >> /tmp/cndor
echo "C128001001" >> /tmp/cndor
echo "Starting new session" >> /usr/local/ipop/var/ping.log
date >> /usr/local/ipop/var/ping.log
for node in `cat /tmp/cndor`; do
  ping $node -c 3 -W 30 >> /usr/local/ipop/var/ping.log
done
date >> /usr/local/ipop/var/ping.log
echo "Done with ping test" >> /usr/local/ipop/var/ping.log
