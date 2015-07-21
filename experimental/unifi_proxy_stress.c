#include<stdio.h> //printf
#include<string.h>    //strlen
#include<sys/socket.h>    //socket
#include<arpa/inet.h> //inet_addr
#include <time.h>
#include <signal.h>

int main(int argc , char *argv[])
{

    time_t start, stop;
    int sock, i, success, seconds;
    float speed;
    int samples;
    struct sockaddr_in server;
    char message[]="get,uap,default,name,5523fd299932508ffaf3b400\n";
    char server_reply[65536];

    server.sin_addr.s_addr = inet_addr("127.0.0.1");
    server.sin_port = htons(8447);
    server.sin_family = AF_INET;
    samples=atoi(argv[1]);
    success=0;
    time(&start);
    sock = socket(AF_INET , SOCK_STREAM , 0);
    if (sock == -1) { puts("Could not create socket"); }
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
        if (0 == strcmp(server_reply, "UAP01-B2floor")) {  success++;}
   

      }
       shutdown(sock,SHUT_RDWR);
    time(&stop);
    seconds = difftime(stop, start);

    if (seconds < 1) {seconds=1;}
    speed = success/seconds;

    printf ("Requests: %d\nSuccess answers: %d\nSpended time: %d\nSpeed is: %0.3f req/sec\n", samples, success, seconds, speed);

    return 0;
}
