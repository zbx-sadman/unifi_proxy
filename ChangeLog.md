## UniFi Proxy change log 


### v1.3.5
Fixed:
- Metrics obtaining from UniFi Security Gateway;

Changes:
- TLS moved to 1.2 to works with UniFi Controller v5.5 / v5.6 and above;

Added:
- UniFi Controller v5 releases real support; 
- New objects: _voucher_ , _dpi_ / _sitedpi_.

### v1.3.4
Enhancements:
 - Use JSON module to allow flexibility in which JSON backend is used. Refer to [https://metacpan.org/pod/JSON#CHOOSING-BACKEND](https://metacpan.org/pod/JSON#CHOOSING-BACKEND) for more information;
 - IO::Socket::INET changed to IO::Socket::IP to enable IPv6 support. This feature not tested on real IPv6 system, send feedback to me please.

Thanks to [Ross Williams](https://github.com/overhacked) for ideas.


### v1.3.3
Fixed:
- UniFi Controller v3: error with logging in;
- UniFi Controller v3: error in 'still connected' testing on fetching data from controller;
- UniFi Controller v3: mapping _mac_-key to {#NAME} macro (Zabbix's LLD) if _name_-key is empty;
- Debug: print the HTTP response output.

### v1.3.2
Fixed:
- MAC detection procedure in 'id' field;
- site list obtaining ('site' object processing does not work).

### v1.3.1
Fixed:
- removed "no sites walking" problem when 'sitename' field  used with no value;
- fixed code to avoid "push on reference is experimental" warning on perl > v5.20.

