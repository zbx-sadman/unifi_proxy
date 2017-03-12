Please, make sure you finished setting up Zabbix Agent, which communicate to UniFi Proxy/Miner, and "Active mode" related options of _zabbix_agentd.conf_ is filled correctly:

`ServerActive=<Unifi Controller IP>`

`Hostname=<hostname from Zabbix web interface>`

**Template use "Zabbix agent (active)" item type.**

Note: you must use `UnsafeUserParameters=1` option of Zabbix Agentd to avoid following error: _"Special characters "\, ', ", `, *, ?, [, ], {, }, ~, $, !, &, ;, (, ), <, >, |, #, @, 0x0a" are not allowed in the parameters"_. 
