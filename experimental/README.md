## UniFi Proxy 1.4.0

### 03.05.2023
Proxy 1.4.0

 - Changed processing: _raw_ actions output includes all selected content as array now. On previous releases only first item returned. Zabbix JSONPath feature can to be used freely to select required items.
 - Added new object: _device_ object represent all devices on UniFi Controller. This object can be used with Zabbix's JSONPath feature.
 - Miner is tested on UniFi Controller v7 & Zabbix v6. New templates uses Zabbix 6 preprocessing deeply.

```
./unifi_proxy_get 127.0.0.1 8448 "raw,wlan,default,*"
[{"schedule_with_duration":[], ... many data here ... "wpa3_transition":false,"_id":"63737384ae690c0390dd7ced"}]

./unifi_proxy_get 127.0.0.1 8448 "raw,device,default,*"
[{"adopted_by_client":"web","fixed_ap_available":true, ... many data here ..."meshv3_peer_mac":"","guest_token":"CF38A385630E3B55ECE0229CC6A856FBC"}]

```
 
 Note: be sure to use virtual key \"*\" (all items) with `raw` action.
 
 Note: _device_ object query produce huge JSON.

## UniFi Proxy 1.3.0

### 22.12.2019
Proxy 1.3.8

 - New feature added: JSON's _pretty_ and _inline_ stringify methods for results of _discovery_ or _raw_ actions output. Use it with _JsonOutput_ directive in the _unifi\_proxy.conf_.

### 22.12.2017
 - New feature added: regexp for filters. Regexp pattern can be used for filtering values of JSON keys. Refer to Perl Regexp tutorial for details. Use simple pattern, please. Example: 

```
# Count connected users on UAPs, which MAC's contained '16:5c' or '73:13' substrings.
    ./unifi_proxy_get 127.0.0.1 8448 "count,uap,default,[mac=~16:5c|mac=~73:13].num_sta,,,0"
```

### 21.12.2017
[Proxy 1.3.6](https://github.com/zbx-sadman/unifi_proxy/blob/master/experimental/unifi_proxy.pl) is testing:

 - New action added: _raw_ (can be renamed later). New key _*_ added too. This pair must helps to get RAW JSON of UniFi object (or its nested object) for using with Zabbix v3.4 JSON preprocessing.
   Example:
```
    ./unifi_proxy_get 127.0.0.1 8448 "raw,site,default,*,,,0"
{"attr_no_delete":true,"_id":"5523f87e99320d293df816fd","desc":"Default","name":"default","attr_hidden_id":"default","role":"readonly"}
```

    
### 13/02/2016
    
Изменен порядок следования параметров в ключе unifi.proxy: поля _maxcacheage_ и _nullchar_ поменяны местами. Это должно сократить количество "лишних" запятых и уменьшить количество ошибок в процессе использования, так как статистически поле _maxcacheage_ заполняется крайне редкою   

    08/02/2016

Исправлена работа с фильтрами - ранее не все значения последнего уровня JSON включались в массив результатов.

Добавлена новая агрегирующая функция (действие)
- median - вычисление статистической медианы из массива значений отфильтрованных JSON-ключей.

Для ключей-фильтров стали доступны:
- операции _<_, _>_, _<=_, _>=_ - меньше, больше, меньше-или-равно, больше-или-равно;

В ключ добавлен новый параметр - _nullchar_. Это позволяет указывать Unifi Proxy какое значение следует вернуть, если в результате выполнения запроса результат окажется несуществующим (null). К таким случаям можно отнести запросы на применение агрегирующей функции на массив результатов, который по результатам фильтрации оказался пустым. 

Т.е. ключ _"median,user,default,[ap_mac=00:27:22:d8:33:23].noise,,,-100"_ следует понимать так: если при отборе пользователей по JSON-ключу _ap_mac_ оказалось, что таковых пользователей нет (никто не подключен к точке), следует вернуть значение -100 (минимальный уровень шума).

### Примеры

Средний (по медиане) "RX rate" активных клиентов, зарегистрированных на точке доступа с заданным MAC-адресом.

    ./unifi_proxy_get 127.0.0.1 8448 "median,user,default,[ap_mac=00:27:22:d8:33:23].rx_rate,,,0"
    
Процент потерь пользователей на точке доступа с заданным MAC-адресом при установке MinRSSI=20

    ./unifi_proxy_get 127.0.0.1 8448 "percount,user,default,[ap_mac=00:27:22:d8:33:23].[rssi<20].rssi,,,0"
    
Процент пользователей сайта 'default' с хорошим (не наилучшим) соотношением сигнал/шум

    ./unifi_proxy_get 127.0.0.1 8448 "percount,user,default,[rssi>25&rssi<=40].rssi,,,0"
    

## UniFi Proxy 1.2.0
    04/02/2016

Добавлены новые действия:
- avgsum -  вычисление среднего арифметического суммы значений отфильтрованных JSON-ключей.

Переименованы действия:
- psum -> persum;
- pcount -> percount.

### Примеры

Средний уровень шума для активных клиентов, зарегистрированных на точке доступа с заданным MAC-адресом

    ./unifi_proxy_get 127.0.0.1 8448 "avgsum,user,default,[ap_mac=00:27:22:d8:33:23].noise"


## UniFi Proxy 1.1.0
### 18/01/2016
    
Основная функция getMetric() полностью переписана. Теперь вместо рекурсивного вызова при обходе JSON дерева используется стековая модель.

Введена обработка запроса во всех найденных на контроллере сайтов в том случае, если в запросе имя сайта не указано.

Добавлены новые действия:
- psum - вычисление процента суммы значений подпадающих под фильтр JSON-ключей от общей суммы.
- pcount - вычисление процента количества значений подпадающих под фильтр JSON-ключей от общего количества.

Для ключей-фильтров доступны:
- логическая операция _&_ (_and_)  - фильтр считается пройденным при выполнении всех условий;
- логическая операция _|_ (_or_)  - фильтр считается пройденным при выполнении любого условия;
- состояние равенства в условии _=_;
- состояние неравенства в условии _<>_ .

Добавлены новые объекты:
- alluser - все пользователи в базе данных (объект user определяет только активных пользователей);
- health - состояние контроллера UniFi (см. дашбоард в v4);
- setting - некоторые настройки контроллера (Settings -> Site);
- network - определенные на контроллере сети (Settings -> Networks);
- usergroup - пользовательские группы (Settings -> User Groups);
- sysinfo - некоторая системная информация;
- number - информация о сопоставленных voip-устройствам абонентских номерах;
- extension - информация о зарегистрированных на контроллере voip-устройствах.

Введена возможность получения LLD-JSON с произвольного поддерева JSON. Обрабатываемые на текущий момент объекты:
- uap_vap_table - список виртуальных точек доступа в пределах заданной UAP;
- usw_port_table - таблица портов UniFi Switch;

### Примеры

LLD-JSON для всех UAP для сайта "default"

    ./unifi_proxy_get 127.0.0.1 8448 "discovery,uap,default"

LLD-JSON для всех UAP во всех сайтах контроллера

    ./unifi_proxy_get 127.0.0.1 8448 "discovery,uap"

Количество активных пользователей во всех сайтах контроллера

    ./unifi_proxy_get 127.0.0.1 8448 "sum,site,,num_sta"

Количество активных UAP во всех сайтах контроллера

    ./unifi_proxy_get 127.0.0.1 8448 "count,uap,,[state=1].state"

Процент активных UAP от их общего числа во всех сайтах контроллера

    ./unifi_proxy_get 127.0.0.1 8448 "pcount,uap,,[state=1].state"

Процент траффика, генерируемого гостевыми виртуальными точками доступа

    ./unifi_proxy_get 127.0.0.1 8448 "psum,uap,,vap_table.[is_guest=1].rx_bytes"

Процент активных пользователей, поключенных с помощью продукции фирмы Apple

    ./unifi_proxy_get 127.0.0.1 8448 "pcount,user,,[oui=Apple].oui"

Процент активных пользователей, поключенных с помощью любых иных устройств, кроме продукции фирмы Apple.

    ./unifi_proxy_get 127.0.0.1 8448 "pcount,user,,[oui<>Apple].oui"

Процент когда-либо подключавшихся пользователей, использовавших продукцию фирмы Apple или Samsung.

    ./unifi_proxy_get 127.0.0.1 8448 "pcount,user,,[oui=Apple|oui=SamsungE].oui"

Версия ПО контроллера UniFi
    
    ./unifi_proxy_get 127.0.0.1 8448 "get,sysinfo,,version"

Состояние модуля WLAN, отображаемого на dashboard веб-интерфейса контроллера UniFi
    
    ./unifi_proxy_get 127.0.0.1 8448 "get,health,default,[subsystem=wlan].status"

Количество активных пользователей, зарегистрированных модулем WLAN
    
    ./unifi_proxy_get 127.0.0.1 8448 "get,health,default,[subsystem=wlan].num_user"

LLD-JSON для VOIP-устройств, зарегистрированных на контроллере
    
    ./unifi_proxy_get 127.0.0.1 8448 "discovery,extension,default"

Абонентский номер VOIP-устройства, ассоциированный с extension с заданным ID

    ./unifi_proxy_get 127.0.0.1 8448 "get,number,default,[extension_id=5698e7779932af54c74bad18].number"


-------------------

Core function getMetric() was reworked and built now on stack mechanism instead recursive self call on JSON tree traversal.
New actions:
- psum
- pcount
