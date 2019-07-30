## UniFi Proxy change log 

### v1.3.8
Added:

- New cli key _-j stringify\_method_. User can enable/disable "Pretty JSON generation" feature. 

Note: "Pretty JSON" formatting allow put to Zabbix more that 65535 bytes data blocks and user can control more objects (UAPs, Users, etc).

### v1.3.7
Added new objects:
- _uap\_vap\_table_ for _vap\_table_ array contained in UAPs data object. LLD is supported;
- _uap\_vwire\_vap\_table_ for _vwire\_vap\_table_ array inside UAPs data object. LLD is supported;
- _fw\_update_ for latest version update info;
- _wdg\_health_ for Health widget's data fetching;
- _wdg\_switch_ for Switch widget's data fetching.

Note: some metrics was reorganized by Ubiquinty and moved to new JSON-tree places.

### v1.3.6
Fixed:
- Uncorrect socket closing on exit;
- Script execution error when object without id-key reached (probably it unadopted devices);

Added:
- RegExp feature for the filter expression; 
- New action _raw_ and new virtual key _*_ for taking raw JSON subtree from the tree. 

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

