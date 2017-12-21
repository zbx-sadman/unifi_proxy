#include "sysinc.h"
#include "module.h"
#include "common.h"
#include "comms.h"
#include "zbxmedia.h"
#include "log.h"
#include "cfg.h"

static char	ZBX_MODULE_NAME[] 		  =  "unifi.so";
static char	DEFAULT_UNIFI_PROXY_SERVER[]      =  "localhost";
static char	DEFAULT_UNIFI_PROXY_CONFIG_FILE[] =  "unifi.conf";
static int	DEFAULT_UNIFI_PROXY_PORT	  =  8448;

extern char 	*CONFIG_LOAD_MODULE_PATH;

char 		*UNIFI_PROXY_SERVER;
int 		UNIFI_PROXY_PORT;

    

/* the variable keeps timeout setting for item processing */
static int	item_timeout = 0;

int	zbx_module_unifi_alive(AGENT_REQUEST *request, AGENT_RESULT *result);
int	zbx_module_unifi_proxy(AGENT_REQUEST *request, AGENT_RESULT *result);

static ZBX_METRIC keys[] =
/*      KEY                     FLAG		FUNCTION        	TEST PARAMETERS */
{
	{"unifi.alive",		0,		zbx_module_unifi_alive,	NULL},
	{"unifi.proxy",		CF_HAVEPARAMS,	zbx_module_unifi_proxy, "discovery"},
	{NULL}
};

/******************************************************************************
 *                                                                            *
 * Function: zbx_module_api_version                                           *
 *                                                                            *
 * Purpose: returns version number of the module interface                    *
 *                                                                            *
 * Return value: ZBX_MODULE_API_VERSION_ONE - the only version supported by   *
 *               Zabbix currently                                             *
 *                                                                            *
 ******************************************************************************/
int	zbx_module_api_version()
{
	return ZBX_MODULE_API_VERSION_ONE;
}

/******************************************************************************
 *                                                                            *
 * Function: zbx_module_item_timeout                                          *
 *                                                                            *
 * Purpose: set timeout value for processing of items                         *
 *                                                                            *
 * Parameters: timeout - timeout in seconds, 0 - no timeout set               *
 *                                                                            *
 ******************************************************************************/
void	zbx_module_item_timeout(int timeout)
{
	item_timeout = timeout;
}

/******************************************************************************
 *                                                                            *
 * Function: zbx_module_item_list                                             *
 *                                                                            *
 * Purpose: returns list of item keys supported by the module                 *
 *                                                                            *
 * Return value: list of item keys                                            *
 *                                                                            *
 ******************************************************************************/
ZBX_METRIC	*zbx_module_item_list()
{
	return keys;
}

int	zbx_module_unifi_alive(AGENT_REQUEST *request, AGENT_RESULT *result)
{
	SET_UI64_RESULT(result, 1);

	return SYSINFO_RET_OK;
}

int	zbx_module_unifi_proxy(AGENT_REQUEST *request, AGENT_RESULT *result)
{
    struct sockaddr_in server_addr;
    struct hostent *server;
    char buffer[MAX_BUFFER_LEN];
    int i, p, np, sockfd, n, nbytes;

    np = request->nparam;
    if (9 < request->nparam)
    {
        SET_MSG_RESULT(result, strdup("Error: so much parameters specified"));
        return SYSINFO_RET_FAIL;
    }

    // Create query string string from params
    if ( 0 >= request->nparam ) 
    {
       buffer[0]='\n';
       buffer[1]='\0';
    } else {
      buffer[0]='\0';
      for (i=0; i < np; i++) 
      {
          strcat(buffer, get_rparam(request, i));
          p = strlen(buffer);
          buffer[p]=(i < (np-1)) ? ',' : '\n';
          buffer[p+1]='\0';
      }
    }
    // Create socket
    sockfd = socket(AF_INET, SOCK_STREAM , 0);
    if (-1 == sockfd)
    {
        zabbix_log(LOG_LEVEL_DEBUG, "%s: could not create socket", ZBX_MODULE_NAME);
        SET_MSG_RESULT(result, strdup("Error: could not create socket"));
        return SYSINFO_RET_FAIL;
    }

    // Resolve hostname
    server = gethostbyname(UNIFI_PROXY_SERVER);

    if (NULL == server)
    {
       zabbix_log(LOG_LEVEL_DEBUG, "%s: no such host '%s'", ZBX_MODULE_NAME, UNIFI_PROXY_SERVER);
       SET_MSG_RESULT(result, strdup("Error: no such host"));
       return SYSINFO_RET_FAIL;
    }

    // Prepare connection
    memset(&server_addr, 0x00, sizeof(server_addr));
    memcpy(&server_addr.sin_addr.s_addr, server->h_addr, server->h_length);
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(UNIFI_PROXY_PORT);

    nbytes = strlen(buffer);

    // Connect to remote server
    if (connect(sockfd, (struct sockaddr*) &server_addr , sizeof(server_addr)) < 0)
    {
       zabbix_log(LOG_LEVEL_DEBUG, "%s: connect to '%s' failed", ZBX_MODULE_NAME, UNIFI_PROXY_SERVER);
       SET_MSG_RESULT(result, strdup("Error: connect failed"));
       puts(UNIFI_PROXY_SERVER);
       return SYSINFO_RET_FAIL;
    }

    // Send query to the server
    n = write(sockfd, buffer, nbytes);

    if (n != nbytes)
    {
       zabbix_log(LOG_LEVEL_DEBUG, "%s: send failed", ZBX_MODULE_NAME);
       SET_MSG_RESULT(result, strdup("Error: send failed"));
       return SYSINFO_RET_FAIL;
    }

        // Receive reply from the server
    n = read(sockfd, buffer, sizeof(buffer));
    if (0 > n)
    {
       zabbix_log(LOG_LEVEL_DEBUG, "%s: recieve failed", ZBX_MODULE_NAME);
       SET_MSG_RESULT(result, strdup("Error: recieve failed"));
       return SYSINFO_RET_FAIL;
    }

    // Finalize connection
    close(sockfd);

    buffer[n]='\0';
    zbx_rtrim(buffer, "\r\n");

    SET_STR_RESULT(result, strdup(buffer));
    return SYSINFO_RET_OK;
}

/******************************************************************************
*                                                                            *
* Function: zbx_module_set_defaults                                          *
*                                                                            *
* Purpose:                                                                   *
*                                                                            *
* Comment:                                                                   *
*                                                                            *
******************************************************************************/
static void	zbx_module_set_defaults()
{
	if (NULL == UNIFI_PROXY_SERVER)
            UNIFI_PROXY_SERVER = (char*) &DEFAULT_UNIFI_PROXY_SERVER;

	if (0 == UNIFI_PROXY_PORT)
    	    UNIFI_PROXY_PORT = DEFAULT_UNIFI_PROXY_PORT;
}
    		
    		
/******************************************************************************
*                                                                             *
* Function: zbx_module_load_config                                            *
*                                                                             *
* Purpose:                                                                    *
*                                                                             *
* Return value:                                                               *
*                                                                             *
*                                                                             *
* Comment:                                                                    *
*                                                                             *
******************************************************************************/
static void	zbx_module_load_config()
{
        char	conf_file[MAX_STRING_LEN];


	static struct cfg_line cfg[] =
        {
    	    {"UniFiProxyServer",	&UNIFI_PROXY_SERVER,	TYPE_STRING,	PARM_OPT,	0,	0},
    	    {"UniFiProxyPort",		&UNIFI_PROXY_PORT,	TYPE_UINT64,	PARM_OPT,	0,	0},
        };
        		    
	zbx_snprintf(conf_file, MAX_STRING_LEN, "%s/%s", CONFIG_LOAD_MODULE_PATH, DEFAULT_UNIFI_PROXY_CONFIG_FILE);
	zabbix_log(LOG_LEVEL_DEBUG, "%s: load & parse config stage. Config file is %s", ZBX_MODULE_NAME, conf_file);
        parse_cfg_file(conf_file, cfg, ZBX_CFG_FILE_OPTIONAL, ZBX_CFG_STRICT);
}        					
        					
/******************************************************************************
 *                                                                            *
 * Function: zbx_module_init                                                  *
 *                                                                            *
 * Purpose: the function is called on agent startup                           *
 *          It should be used to call any initialization routines             *
 *                                                                            *
 * Return value: ZBX_MODULE_OK - success                                      *
 *               ZBX_MODULE_FAIL - module initialization failed               *
 *                                                                            *
 * Comment: the module won't be loaded in case of ZBX_MODULE_FAIL             *
 *                                                                            *
 ******************************************************************************/
int	zbx_module_init()
{
	zabbix_log(LOG_LEVEL_DEBUG, "%s: init module stage", ZBX_MODULE_NAME);
	zbx_module_load_config();
	zbx_module_set_defaults();

	zabbix_log(LOG_LEVEL_DEBUG, "%s: UniFi Proxy host is '%s:%d'", ZBX_MODULE_NAME, UNIFI_PROXY_SERVER, UNIFI_PROXY_PORT);
	return ZBX_MODULE_OK;
}

/******************************************************************************
 *                                                                            *
 * Function: zbx_module_uninit                                                *
 *                                                                            *
 * Purpose: the function is called on agent shutdown                          *
 *          It should be used to cleanup used resources if there are any      *
 *                                                                            *
 * Return value: ZBX_MODULE_OK - success                                      *
 *               ZBX_MODULE_FAIL - function failed                            *
 *                                                                            *
 ******************************************************************************/
int	zbx_module_uninit()
{
	zabbix_log(LOG_LEVEL_DEBUG, "%s: Un-init module stage", ZBX_MODULE_NAME);
	return ZBX_MODULE_OK;
}
