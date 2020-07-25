#!/bin/sh

#Replace text in file
#sed -i 's/old-text/new-text/g' input.txt

#Check if envar exist
#if [ -z ${var+x} ]; then echo "var is unset"; else echo "var is set to '$var"; fi

CONFIG_FILE="/etc/unifi_proxy/unifi_proxy.conf"

if ! [ -z ${MAX_CLIENTS+x} ];
then echo "MaxClients=$MAX_CLIENTS" >> $CONFIG_FILE;
fi

if ! [ -z ${LISTEN_PORT+x} ];
then echo "ListenPort=$LISTEN_PORT" >> $CONFIG_FILE;
fi

if ! [ -z ${LISTEN_IP+x} ];
then echo "ListenIp=$LISTEN_IP" >> $CONFIG_FILE;
fi

if ! [ -z ${START_SERVERS+x} ];
then echo "StartServers=$START_SERVERS" >> $CONFIG_FILE;
fi

if ! [ -z ${MAX_REQUEST_PER_CHILD+x} ];
then echo "MaxRequestsPerChild=$MAX_REQUEST_PER_CHILD" >> $CONFIG_FILE;
fi

if ! [ -z ${CACHE_DIR+x} ];
then echo "CacheDir=$CACHE_DIR" >> $CONFIG_FILE;
fi

if ! [ -z ${CACHE_MAX_AGE+x} ];
then echo "CacheMaxAge=$CACHE_MAX_AGE" >> $CONFIG_FILE;
fi

if ! [ -z ${UNIFI_LOCATION+x} ];
then echo "UniFiLocation=$UNIFI_LOCATION" >> $CONFIG_FILE;
fi

if ! [ -z ${UNIFI_VERSION+x} ];
then echo "UniFiVersion=$UNIFI_VERSION" >> $CONFIG_FILE;
fi

if ! [ -z ${UNIFI_USER+x} ];
then echo "UniFiUser=$UNIFI_USER" >> $CONFIG_FILE;
fi

if ! [ -z ${UNIFI_PASS+x} ];
then echo "UniFiPass=$UNIFI_PASS" >> $CONFIG_FILE;
fi

if ! [ -z ${DEBUG_LEVEL+x} ];
then echo "DebugLevel=$DEBUG_LEVEL" >> $CONFIG_FILE;
fi

if ! [ -z ${JSON_OUTPUT+x} ];
then echo "JsonOutput=$JSON_OUTPUT" >> $CONFIG_FILE;
fi

if ! [ -z ${ACTION+x} ];
then echo "Action=$ACTION" >> $CONFIG_FILE;
fi

if ! [ -z ${OBJECT_TYPE+x} ];
then echo "ObjectType=$OBJECT_TYPE" >> $CONFIG_FILE;
fi

if ! [ -z ${SITE_NAME+x} ];
then echo "SiteName=$SITE_NAME" >> $CONFIG_FILE;
fi

#tail -f /dev/null
./unifi_proxy.pl