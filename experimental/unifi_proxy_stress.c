#include<stdio.h> //printf
#include<string.h>    //strlen
#include<sys/socket.h>    //socket
#include<arpa/inet.h> //inet_addr
#include <time.h>
#include <signal.h>

#define MAX_BUFFER_LEN 65536
#define MAX_STRING_LEN 255

int main(int argc , char *argv[])
{

    time_t start, stop;
    int sock, i, success, seconds;
    float speed;
    int samples;
    struct sockaddr_in server;
    char message[MAX_STRING_LEN];
    char expected[MAX_BUFFER_LEN];
    char server_reply[MAX_BUFFER_LEN];

//    server.sin_addr.s_addr = inet_addr("127.0.0.1");
//    server.sin_port = htons(8447);
//    server.sin_family = AF_INET;
   if (6 != argc)
      {
        printf("[!] To few arguments. Use: %s <IP> <port> <request> <expected_result> <samples_number>\n", argv[0]);
        printf("[!] example: %s 127.0.0.1 8448 \"get,uap,default,name,<uap_id>\" 10000\n", argv[0]);
        return 1;
      }

    success=0;
    sock = socket(AF_INET , SOCK_STREAM , 0);
    if (sock == -1) { puts("Could not create socket"); }
    // 1-st arg - addr to connect
    server.sin_addr.s_addr = inet_addr(argv[1]);
    server.sin_family = AF_INET;
    // 2-nd arg - port to connect
    server.sin_port = htons(atoi(argv[2]));
    sprintf(message,"%s\n",argv[3]);
    sprintf(expected,"%s\0",argv[4]);
    samples=atoi(argv[5]);

//    printf("go with %d samples, \"%s\" request, \"%s\" expected\n", samples, message, expected);
    time(&start);
    //Connect to remote server
    if (connect(sock , (struct sockaddr *)&server , sizeof(server)) < 0) { puts("connect failed. Error"); return 1; }
    //Create socket
    for (i=0; i< samples; i++) 
      {
    //Send some data

        if( send(sock , message , strlen(message) , 0) < 0) { puts("Send failed"); return 1; }
        //Receive a reply from the server
        if( recv(sock , server_reply , 65535 , 0) < 0) {   puts("recv failed"); return 1; }
        server_reply[strlen(server_reply)-1]='\0';
//        puts(server_reply);
//        printf("sample %d: server_reply=\"%s\" \n", i, server_reply);
    
        if (0 == strcmp(server_reply, expected)) {  success++;}
   

      }
       shutdown(sock,SHUT_RDWR);
    time(&stop);
    seconds = difftime(stop, start);

    if (seconds < 1) {seconds=1;}
    speed = success/seconds;

    printf ("Requests: %d\nSuccess answers: %d\nSpended time: %d\nSpeed is: %0.3f req/sec\n", samples, success, seconds, speed);

    return 0;
}
