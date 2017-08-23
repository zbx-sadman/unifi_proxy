## UniFi Proxy
Actual release is v1.3.5.

Read [change log](https://github.com/zbx-sadman/unifi_proxy/blob/master/ChangeLog.md) before update to new release.

Installable package is not exist, DYI-ers must explore _/etc_ , _/usr/local_ and _/src_ dirs and get that what they need:

- [usr/local/sbin/unifi_proxy.pl](https://github.com/zbx-sadman/unifi_proxy/blob/master/usr/local/sbin/unifi_proxy.pl) - UniFi Proxy executable file;
- [etc/unifi_proxy/unifi_proxy.conf](https://github.com/zbx-sadman/unifi_proxy/blob/master/etc/unifi_proxy/unifi_proxy.conf) - UniFi Proxy config file;
- [etc/init.d/unifi_proxy](https://github.com/zbx-sadman/unifi_proxy/blob/master/etc/init.d/unifi_proxy) - system start-up service script;
- [src/unifi_proxy_get.c](https://github.com/zbx-sadman/unifi_proxy/blob/master/src/unifi_proxy_get.c) - _unifi_proxy_get_ utility source code;
- [etc/zabbix/zbx_unifi.conf](https://github.com/zbx-sadman/unifi_proxy/blob/master/etc/zabbix/zbx_unifi.conf) - plugged to _zabbix_agentd.conf_ config file;
- [src/modules/](https://github.com/zbx-sadman/unifi_proxy/blob/master/src/modules) - _unifi.so_ Zabbix's v2 & Zabbix's v3 loadable module source code;
- [usr/local/lib/unifi.conf](https://github.com/zbx-sadman/unifi_proxy/blob/master/usr/local/lib/zabbix/unifi.conf) - config file for _unifi.so_.

Command-line version of UniFi Proxy is [UniFi Miner](https://github.com/zbx-sadman/unifi_miner)

It is a TCP server written in Perl, which helps deliver to the monitoring system (Zabbix or other, that used shell's utility to taken data - like Cacti) operational data - metrics and settings obtained from the UniFi controller via API, provided by Ubiquiti. Zabbix's Low-level Discovery (LLD) protocol are supported.

![Zabbix: connected clients](http://community.ubnt.com/t5/image/serverpage/image-id/53219iB1CA79D24EFB2BEB/image-size/original)

If you have a question about Proxy, please, refer to [UniFi Proxy Russian Guide](https://github.com/zbx-sadman/unifi_proxy/wiki/UniFi-Proxy-Guide-in-Russian) or [UniFi Proxy English Guide](https://github.com/zbx-sadman/unifi_proxy/wiki/UniFi-Proxy-Guide-in-English).

Also, answers to many questions and troubleshooting issues may be found in  
[UniFi Miner Russian Guide](https://github.com/zbx-sadman/unifi_miner/wiki/UniFi-Miner-Guide-in-Russian) or [UniFi Miner English Guide](https://github.com/zbx-sadman/unifi_miner/wiki/UniFi-Miner-Guide-in-English).

If u have an problem, you can search the existing closed or open [issues](https://github.com/zbx-sadman/unifi_proxy/issues). 

Templates for Zabbix [here](https://github.com/zbx-sadman/unifi_proxy/tree/master/Zabbix_Templates)

Response time compare table (6 UAPs installation):

| Miner 1.0.0 (w/o PPerl) | Miner 1.0.0 (w/PPerl) | Proxy (netcat) | Proxy (unifi_proxy_get) | Proxy (unifi.so) |
|-------------------------|-----------------------|----------------|-------------------------|------------------|
| ~0m0.056s               | ~0m0.023s             | ~0m0.005s      |  ~0m0.003s              |  ~0m0.006s       |

Note: time in measurement "Proxy (unifi.so)" include start & runtime overhead of _zabbix_agentd_/_zabbix_get_. Streaming speed of queries processed by server was ~1000resp/sec (using special written utility)

[![donation](https://camo.githubusercontent.com/1d4c796d0043ba18176a68767c2ee55188d55cc1/68747470733a2f2f7777772e70617970616c6f626a656374732e636f6d2f656e5f47422f692f62746e2f62746e5f646f6e6174655f4c472e676966)](https://www.paypal.me/GrigoryP)

### My other projects
 [_UniFi Miner_](https://github.com/zbx-sadman/unifi_miner) - Command-line version of UniFi Proxy   
 [_Zabbuino_](https://github.com/zbx-sadman/zabbuino) - Zabbix agent for Arduino 
