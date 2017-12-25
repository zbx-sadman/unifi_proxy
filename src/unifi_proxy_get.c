#include<stdio.h> //printf
#include<string.h>    //strlen
#include<sys/socket.h>    //socket
#include<arpa/inet.h> //inet_addr
#include <netdb.h>

#define MAX_BUFFER_LEN    65536
#define MAX_STRING_LEN    255 
#define SYSINFO_RET_FAIL  1
#define SYSINFO_RET_OK    0

int main(int argc , char *argv[])
{
    struct sockaddr_in server_addr;
    struct hostent *server;
    char buffer[MAX_BUFFER_LEN];
    int p, np, sockfd;
    unsigned int i, n, nbytes;

    if (4 > argc)
      {
        printf("Error: to few parameters specified.\nTry this: % <IP> <port> <request>\n\n", argv[0]);
        return 1;
      }

    // Create socket
    sockfd = socket(AF_INET, SOCK_STREAM , 0);
    if (-1 == sockfd)
    {
        puts("Error: could not create socket");
        return SYSINFO_RET_FAIL;
    }

    // Resolve hostname
    // 1-st arg - addr to connect 
    server = gethostbyname(argv[1]);

    if (NULL == server)
    {
       printf("Error: no such host '%s'", argv[1]);
       return SYSINFO_RET_FAIL;
    }

    // Prepare connection
    memset(&server_addr, 0x00, sizeof(server_addr));
    memcpy(&server_addr.sin_addr.s_addr, server->h_addr, server->h_length);
    server_addr.sin_family = AF_INET;
    // 2-nd arg - port to connect 
    server_addr.sin_port = htons(atoi(argv[2]));


    // Connect to remote server
    if (connect(sockfd, (struct sockaddr*) &server_addr , sizeof(server_addr)) < 0)
    {
       printf("Error: connect to '%s' failed'", argv[1]);
       return SYSINFO_RET_FAIL;
    }

    // Send query to the server
    nbytes = snprintf(buffer, sizeof(buffer), "%s\n", argv[3]);

    n = write(sockfd, buffer, nbytes);

    if (n != nbytes)
    {
       printf("Error: sending to '%s' failed'", argv[1]);
       return SYSINFO_RET_FAIL;
    }

    // Receive reply from the server
    n = read(sockfd, buffer, sizeof(buffer));

    if (0 > n)
    {
       printf("Error: recieving from '%s' failed'", argv[1]);
       return SYSINFO_RET_FAIL;
    }

    // Finalize connection
    close(sockfd);

    buffer[n] = '\0';
/*
    for (i = 0; n < i; i++) {
        if ('\n' == buffer[n] || '\r' == buffer[n]) {
           buffer[i] = '\0';
           break;
        }
    }

*/ 
    printf("%s", buffer);

    return SYSINFO_RET_OK;
}
