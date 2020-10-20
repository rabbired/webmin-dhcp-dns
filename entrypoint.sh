#!/bin/bash
set +e

ROOT_PASSWORD=${ROOT_PASSWORD:-password}
WEBMIN_ENABLED=${WEBMIN_ENABLED:-true}

BIND_DATA_DIR=${DATA_DIR}/bind
DHCP_DATA_DIR=${DATA_DIR}/dhcp
WEBMIN_DATA_DIR=${DATA_DIR}/webmin

BIND_USER=bind

create_bind_data_dir() {
  mkdir -p ${BIND_DATA_DIR}

  # populate default bind configuration if it does not exist
  if [ ! -d ${BIND_DATA_DIR}/etc ]; then
    mv /etc/bind ${BIND_DATA_DIR}/etc
  fi
  rm -rf /etc/bind
  ln -sf ${BIND_DATA_DIR}/etc /etc/bind
  chmod -R 0775 ${BIND_DATA_DIR}
  chown -R ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}

  if [ ! -d ${BIND_DATA_DIR}/lib ]; then
    mkdir -p ${BIND_DATA_DIR}/lib
    chown ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}/lib
  fi
  rm -rf /var/lib/bind
  ln -sf ${BIND_DATA_DIR}/lib /var/lib/bind
}

create_dhcp_data_dir() {
  mkdir -p ${DHCP_DATA_DIR}

  # populate default dhcp configuration if it does not exist
  if [ ! -d ${DHCP_DATA_DIR}/etc ]; then
    mv /etc/dhcp ${DHCP_DATA_DIR}/etc
  fi
  rm -rf /etc/dhcp
  ln -sf ${DHCP_DATA_DIR}/etc /etc/dhcp
  chmod -R 0775 ${DHCP_DATA_DIR}
  chown -R ${DHCP_USER}:${DHCP_USER} ${DHCP_DATA_DIR}

  if [ ! -d ${DHCP_DATA_DIR}/lib ]; then
    mkdir -p ${DHCP_DATA_DIR}/lib
    chown ${DHCP_USER}:${DHCP_USER} ${DHCP_DATA_DIR}/lib
  fi
  rm -rf /var/lib/dhcp
  ln -sf ${DHCP_DATA_DIR}/lib /var/lib/dhcp
}

create_webmin_data_dir() {
  mkdir -p ${WEBMIN_DATA_DIR}
  chmod -R 0755 ${WEBMIN_DATA_DIR}
  chown -R root:root ${WEBMIN_DATA_DIR}

  # populate the default webmin configuration if it does not exist
  if [ ! -d ${WEBMIN_DATA_DIR}/etc ]; then
    mv /etc/webmin ${WEBMIN_DATA_DIR}/etc
  fi
  rm -rf /etc/webmin
  ln -sf ${WEBMIN_DATA_DIR}/etc /etc/webmin
}

set_root_passwd() {
  echo "root:$ROOT_PASSWORD" | chpasswd
}

create_bind_pid_dir() {
  mkdir -m 0775 -p /var/run/named
  chown root:${BIND_USER} /var/run/named
}

create_dhcp_pid_dir() {
  mkdir -m 0775 -p /var/run/dhcp-server
  chown root:${DHCP_USER} /var/run/dhcp-server
}

create_bind_cache_dir() {
  mkdir -m 0775 -p /var/cache/bind
  chown root:${BIND_USER} /var/cache/bind
}

###
# Main body of entrypoint script starts here
###

echo -e "\nStart of container entrypoint.sh BASH script..."

# bind9
create_bind_pid_dir
create_bind_data_dir
create_bind_cache_dir

# isc-dhcp-server
create_dhcp_pid_dir
create_dhcp_data_dir

# allow arguments to be passed to named
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == named || ${1} == $(which named) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
fi

# Test for dhcpd.pid file and remove if it exists - This file can inhibit
# isc-dhcp-server from starting correctly

file="/run/dhcpd.pid"
if [ -f $file ] ; then
    echo -e "\nPID file for isc-dhcp-server found; removing..."
    rm $file
fi

file="/run/named/named.pid"
if [ -f $file ] ; then
    echo -e "\nPID file for bind9 found; removing..."
    rm $file
fi

# default behaviour is to launch dhcp, named and webmin
if [[ -z ${1} ]]; then
  if [ "${WEBMIN_ENABLED}" == "true" ]; then
    create_webmin_data_dir
    set_root_passwd
    echo -e "\nStarting webmin..."
    /etc/init.d/webmin start
  fi

  sleep 30
  echo -e "\nStarting dhcp..."
  service isc-dhcp-server start
# Old command: exec $(which dhcpd) -user ${DHCP_USER} -group ${DHCP_USER} -f -4 -pf /var/run/dhcp-server/dhcpd.pid -cf /etc/dhcp/dhcpd.conf ${DHCP_INTERFACES}

  echo -e "\nStarting named..."
  service bind9 start
# Old command: exec $(which named) -u ${BIND_USER} -g ${EXTRA_ARGS} 

# Stop script/container from terminating - maintain it running until external signal/termination
  sleep infinity

else
  exec "$@"
fi
