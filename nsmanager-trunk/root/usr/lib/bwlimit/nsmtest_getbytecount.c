
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

/*
 * Only here to enable a non root user to get the count
 * 
 */
int main(int argc, char *argv[])
{
   setuid( 0 );
   char everythin[255] = "/sbin/iptables -t mangle -L htb-gen.";
   //either up or down
   strcat(everythin, argv[1]);//dir
   strcat(everythin, " -n -v -x |  grep htb-gen.");
   strcat(everythin, argv[1]);//dir
   strcat(everythin, "-");
   strcat(everythin, argv[2]);//username
   strcat(everythin, " | grep ' ");
   strcat(everythin, argv[3]);//ip formatted for grep (including escape codes
   strcat(everythin, " ' | awk ' { print $1 }'");
   
   system( everythin );
   
   

   return 0;
}
