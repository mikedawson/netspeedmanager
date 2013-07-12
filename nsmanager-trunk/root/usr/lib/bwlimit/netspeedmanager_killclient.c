#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

//using namespace std;

/*
 Wrapper to call script as root
*/
int main(int argc, char *argv[])
{
   setuid( 0 );
   char everythin[255] = "/usr/lib/bwlimit/killclient.sh ";
   strcat(everythin, argv[1]);
   system( everythin );
//   cout << everythin;
   return 0;
}
