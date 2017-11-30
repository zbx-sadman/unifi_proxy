/*
** Zabbix
** Copyright (C) 2001-2016 Zabbix SIA
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
**/

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

/* module SHOULD define internal functions as static and use a naming pattern different from Zabbix internal */
/* symbols (zbx_*) and loadable module API functions (zbx_module_*) to avoid conflicts                       */
static int	unifi_alive(AGENT_REQUEST *request, AGENT_RESULT *result);
static int	unifi_proxy(AGENT_REQUEST *request, AGENT_RESULT *result);

static ZBX_METRIC keys[] =
/*      KEY                     FLAG		FUNCTION        	TEST PARAMETERS */
{
    {"unifi.alive",		0,		unifi_alive,	NULL},
    {"unifi.proxy",		CF_HAVEPARAMS,	unifi_proxy, "discovery"},
    {NULL}
};

/******************************************************************************
 *                                                                            *
 * Function: zbx_module_api_version                                           *
 *                                                                            *
 * Purpose: returns version number of the module interface                    *
 *                                                                            *
 * Return value: ZBX_MODULE_API_VERSION - version of module.h module is       *
 *               compiled with, in order to load module successfully Zabbix   *
 *               MUST be compiled with the same version of this header file   *
 *                                                                            *
 ******************************************************************************/
int	zbx_module_api_version(void)
{
    return ZBX_MODULE_API_VERSION;
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

static int	unifi_alive(AGENT_REQUEST *request, AGENT_RESULT *result)
{
    SET_UI64_RESULT(result, 1);

    return SYSINFO_RET_OK;
}

static int	unifi_proxy(AGENT_REQUEST *request, AGENT_RESULT *result)
{
        int             ret;
        int 		i, p, np;
        // Since Zabbix3 zbx_sock_t => zbx_socket_t
        zbx_socket_t	s;
        char		send_buf[MAX_STRING_LEN];
        const char		*recv_buf;
        
        *send_buf='\0';

        np = request->nparam;
    if (9 < request->nparam)
    {
	/* set optional error message */
	SET_MSG_RESULT(result, strdup("So much parameters given."));
	return SYSINFO_RET_FAIL;
    }
        // make request string by concatenate all params
        for (i=0; i < np; i++) 
          {
            strcat(send_buf, get_rparam(request, i));
            p=strlen(send_buf);
            send_buf[p]=(i < (np-1)) ? ',' : '\n';
            send_buf[p+1]='\0';
          }

        // Connect to UniFi Proxy
        // item_timeout or (item_timeout-1) ?

        // Since Zabbix3 zbx_tcp_connect: 
        //     configured_tls_connect_mode = ZBX_TCP_SEC_UNENCRYPTED
        //     tls_arg1 = NULL
        //     tls_arg2 = NULL
        if (SUCCEED == (ret = zbx_tcp_connect(&s, CONFIG_SOURCE_IP, UNIFI_PROXY_SERVER, UNIFI_PROXY_PORT, CONFIG_TIMEOUT, ZBX_TCP_SEC_UNENCRYPTED, NULL, NULL)))
        {
            // Send request
            if (SUCCEED == (ret = zbx_tcp_send_raw(&s, send_buf)))
               {
                  // Recive answer from UniFi Proxy
                  if (NULL != (recv_buf = zbx_tcp_recv_line(&s))) {
//                        zbx_rtrim(recv_buf, "\r\n");
                        SET_STR_RESULT(result, strdup(recv_buf));
                     }
                 else { ret = FAIL; }
               }
            zbx_tcp_close(&s);
        }

        if (FAIL == ret)
           {
			
        // Since Zabbix3 zbx_tcp_strerror() => zbx_socket_strerror()
	zabbix_log(LOG_LEVEL_DEBUG, "%s: communication error: %s", ZBX_MODULE_NAME, zbx_socket_strerror());
	SET_MSG_RESULT(result, strdup(zbx_socket_strerror()));
                return SYSINFO_RET_FAIL;
           }

    return SYSINFO_RET_OK;
}

/******************************************************************************
*                                                                            *
* Function: unifi_set_defaults                                               *
*                                                                            *
* Purpose:                                                                   *
*                                                                            *
* Comment:                                                                   *
*                                                                            *
******************************************************************************/
static void	unifi_set_defaults()
{
    if (NULL == UNIFI_PROXY_SERVER)
	    UNIFI_PROXY_SERVER = zbx_strdup(UNIFI_PROXY_SERVER, DEFAULT_UNIFI_PROXY_SERVER);

    if (0 == UNIFI_PROXY_PORT)
	    UNIFI_PROXY_PORT = DEFAULT_UNIFI_PROXY_PORT;
}
	    
	    
/******************************************************************************
*                                                                             *
* Function: unifi_load_config                                                 *
*                                                                             *
* Purpose:                                                                    *
*                                                                             *
* Return value:                                                               *
*                                                                             *
*                                                                             *
* Comment:                                                                    *
*                                                                             *
******************************************************************************/
static void	unifi_load_config()
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
    unifi_load_config();
    unifi_set_defaults();

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

/******************************************************************************
 *                                                                            *
 * Function: zbx_module_history_write_cbs                                     *
 *                                                                            *
 * Purpose: returns a set of module functions Zabbix will call to export      *
 *          different types of historical data                                *
 *                                                                            *
 * Return value: structure with callback function pointers (can be NULL if    *
 *               module is not interested in data of certain types)           *
 *                                                                            *
 ******************************************************************************/
ZBX_HISTORY_WRITE_CBS	zbx_module_history_write_cbs(void)
{
    static ZBX_HISTORY_WRITE_CBS	dummy_callbacks =
    {
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
    };

    return dummy_callbacks;

}
