Since UniFi Proxy / Miner v1.3.5 released, single template was splitted to following:
- Main template, Site & DPI related metrics - zbx\_v2\_4\_active\_Template\_UBNT\_**UniFi_Controller\_v\_5**.xml;
- UniFi Access Points (UAP) template - ...UniFi_Controller\_v\_5\_**UAP**...;
- UniFi Security Gateway (UGW / USG) template - ...UniFi_Controller\_v\_5\_**UGW**...;
- UniFi Connected users & guests template - ...UniFi_Controller\_v\_5\_**User**...;
- UniFi Switch (USW) template - ...UniFi_Controller\_v\_5\__**USW**...;
- UniFi VoIP Phone & extension template - ...UniFi_Controller\_v\_5\_**VoIP**...;
- UniFi Hotspot Voucher template - ...UniFi_Controller\_v\_5\_**Voucher**...;

How to make a choice between "Active checks" and "Passive checks" templates set:
- Zabbix agent with UniFi Controller is placed behind NAT => active checks;
- You use UniFi Proxy and want to bring many metric values to Zabbix =>  active checks may be better;
- Debug is processing => passive checks is more predictable;
- You are lazy or/and take a few metrics with UniFi Miner from UniFi Controller => passive checks;

If you **choose template with "Zabbix agent (active)" data items**, please, make sure you finished setting up Zabbix Agent, which communicate to UniFi Proxy/Miner, and "Active mode" related options of _zabbix_agentd.conf_ is filled correctly:

`ServerActive=<Zabbix server IP>`

`Hostname=<hostname from Zabbix web interface>`

**Note#1**: "Active checks" templates contain Discovery Rules that have passive 'Zabbix agent' type. It is a small feature trick to detect some configuration errors: if the Data Items were created from its prototypes, but data not coming in them - that means the user incorrectly configured the Zabbix agent's active mode. In the event that the Data Items were not created - it incorrectly configured the UniFi Proxy/MIner (LLD JSON was not returned to Zabbix Server). You can change Discovery Rules type to 'Zabbix agent (active)' if all issues solved or was not arrived.

**Note#2**: Not all metrics used in templates are available in all UniFi Controller releases. Some of them have been removed in newer releases, others have existed only in beta branches. Also, for example, UAP-Pro device have more metrics than UAP.

**Note#3**: You must use `UnsafeUserParameters=1` option of Zabbix Agentd to avoid following error: _"Special characters "\, ', ", `, *, ?, [, ], {, }, ~, $, !, &, ;, (, ), <, >, |, #, @, 0x0a" are not allowed in the parameters"_. 
