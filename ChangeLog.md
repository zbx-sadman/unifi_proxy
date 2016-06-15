##UniFi Miner & Proxy change log 

###v1.3.3
Fixed:
- UniFi Controller v3: error with logging in;
- UniFi Controller v3: error in 'still connected' testing on fetching data from controller;
- UniFi Controller v3: mapping _mac_-key to {#NAME} macro (Zabbix's LLD) if _name_-key is empty;
- Debug: print of HTTP response output.

###v1.3.2
Fixed:
- fixed MAC detection procedure in 'id' field;
- site list obtaining ('site' object processing does not work).

###v1.3.1
Fixed:
- removed "no sites walking" problem when 'sitename' field  used with no value;
- fixed code to avoid "push on reference is experimental" warning on perl > v5.20.

