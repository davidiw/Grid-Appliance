if [[ -f /home/griduser/.xison || -f /home/griduser/.xdisabled ]]
  then
  echo &> /dev/null
else
  touch /home/griduser/.xison
  startx &> /dev/null
  rm /home/griduser/.xison
fi
