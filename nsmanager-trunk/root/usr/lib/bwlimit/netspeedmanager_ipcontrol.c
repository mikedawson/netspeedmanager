
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char *argv[])
{
   setuid( 0 );
   char everythin[255] = "/usr/lib/bwlimit/netspeedmanager_ipcontrol.sh ";
   strcat(everythin, argv[1]);
   strcat(everythin, " ");
   strcat(everythin, argv[2]);
   strcat(everythin, " ");
   strcat(everythin, argv[3]);
   strcat(everythin, " ");
   strcat(everythin, argv[4]);
   strcat(everythin, " ");
   strcat(everythin, argv[5]);
   strcat(everythin, " ");
   strcat(everythin, argv[6]);
   strcat(everythin, " ");
   strcat(everythin, argv[7]);
   strcat(everythin, " ");
   strcat(everythin, argv[8]);
   strcat(everythin, " ");
   strcat(everythin, argv[9]);

   system( everythin );
   
   

   return 0;
}
