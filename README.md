## UniFi Proxy
Actual release is NONE: no releases, testing stage in progress.  
Command-line version of UniFi Proxy is [UniFi Miner](https://github.com/zbx-sadman/unifi_miner)

It is a TCP server written in Perl, which helps deliver to the monitoring system (Zabbix) operational data - metrics and settings obtained from the UniFi controller via API, provided by Ubiquiti. Zabbix's Low-level Discovery (LLD) protocol are supported.

![Zabbix: connected clients](http://community.ubnt.com/t5/image/serverpage/image-id/53219iB1CA79D24EFB2BEB/image-size/original)

If you have a question about Proxy, please, refer to [UniFi Proxy Russian Guide] (https://github.com/zbx-sadman/unifi_proxy/wiki/UniFi-Proxy-Guide-in-Russian). Translation to English in progress.

If u have an problem, you can search the existing closed or open [issues](https://github.com/zbx-sadman/unifi_proxy/issues). 

Templates for Zabbix [here](https://raw.githubusercontent.com/zbx-sadman/unifi_proxy/master/Zabbix_Templates)

Response time compare table (6 UAPs installation):

| Miner 1.0.0 (без PPerl) | Miner 1.0.0 (PPerl) | Proxy (netcat) | Proxy (unifi_proxy_get) | Proxy (unifi.so) |
|-------------------------|---------------------|----------------|-------------------------|------------------|
| ~0m0.056s               | ~0m0.023s           | ~0m0.011s      |  ~0m0.009s              |  ~0m0.007s       |

### My other projects
 [_UniFi Miner_](https://github.com/zbx-sadman/unifi_miner) - Command-line version of UniFi Proxy   
 [_Zabbuino_](https://github.com/zbx-sadman/zabbuino) - Zabbix agent for Arduino 
