## UniFi Proxy (Docker)
The docker version. 

### Note
Docker part does not tested by @zbx-sadman, please send all questions to the [@rfranky](https://github.com/rfranky)

### Build
From project root:
```
docker build -t unifi-proxy -f docker/Dockerfile . 
```
### Run example
```
docker run -p 8448:8448 --env UNIFI_LOCATION=https://192.168.1.2:8443 --env UNIFI_USER=myuser --env UNIFI_PASS=mypass --env SITE_NAME=home --name Unifi-Proxy unifi_proxy 
```
### Docker-Compose example
```
version: '3.3'
services:
    unifi_proxy:
        ports:
            - '8448:8448'
        environment:
            - UNIFI_LOCATION="https://192.168.1.2:8443"
            - UNIFI_USER="myuser"
            - UNIFI_PASS="mypass"
            - SITE_NAME="home"
        container_name: Unifi-Proxy
        image: unifi_proxy
```
### ENVIRONMENT VARIABLES
Refer to [etc/unifi_proxy/unifi_proxy.conf](https://github.com/zbx-sadman/unifi_proxy/blob/master/etc/unifi_proxy/unifi_proxy.conf) for more info
| VAR NAME | DEFAULT | DESCRIPTION |
| ------ | ------ | ------ |
| MAX_CLIENTS | 10 | The max number of concurrent connections to the UniFi Proxy TCP server |
| LISTEN_PORT | 8448 | The port number to accept incoming connections |
| LISTEN_IP | 127.0.0.1 | The IP address to listen for incoming connections |
| START_SERVERS | 5 | How much prefork server instances |
| MAX_REQUEST_PER_CHILD | 1024 | Requests number served before preforked server die for avoiding memory leaks |
| CACHE_DIR | /dev/shm | Where are cache file stored |
| CACHE_MAX_AGE | 60 | Max age of cache files (in seconds). Older files replaced with Controller's data |
| UNIFI_LOCATION | https://localhost:8443 | Where are UniFi Controller answer. |
| UNIFI_VERSION | v5 | UniFi controller version |
| UNIFI_USER | admin | UniFi user, which can read data with API |
| UNIFI_PASS | ubnt | Pass of UniFi user, which can read data with API |
| DEBUG_LEVEL | 0 | Level of debug details |
| JSON_OUTPUT | pretty | JSON stringify method |
| ACTION | discovery | Default action for group operation with UniFi object's metric |
| OBJECT_TYPE | wlan | Default object's type which used for group actions or other processing |
| SITE_NAME | default | Default UniFi site name |
