How to make a choice between "Active checks" and "Passive checks" templates set:
- Zabbix agent with UniFi Controller is placed behind NAT => active checks;
- You use UniFi Proxy and want to bring many metric values to Zabbix =>  active checks may be better;
- Debug is processing => passive checks is more predictable;
- You are lazy or/and take a few metrics with UniFi Miner from UniFi Controller => passive checks;

If you **choose template with "Zabbix agent (active)" data items**, please, make sure you finished setting up Zabbix Agent, which communicate to UniFi Proxy/Miner, and "Active mode" related options of _zabbix_agentd.conf_ is filled correctly:

`ServerActive=<Zabbix server IP>`

`Hostname=<hostname from Zabbix web interface>`

Note: you must use `UnsafeUserParameters=1` option of Zabbix Agentd to avoid following error: _"Special characters "\, ', ", `, *, ?, [, ], {, }, ~, $, !, &, ;, (, ), <, >, |, #, @, 0x0a" are not allowed in the parameters"_. 
