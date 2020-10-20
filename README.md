### webmin-dhcp-dns
fork rhastie/webmin-dhcp-dns

## ubuntu:latest webmin isc-dhcp-server bind9


docker run -d --name "" --net=host \
-e ROOT_PASSWORD="" \
-e DHCP_INTERFACES="" \
-v "path":/data \
-v /etc/timezone:/etc/timezone \
-v /etc/localtime:/etc/localtime
