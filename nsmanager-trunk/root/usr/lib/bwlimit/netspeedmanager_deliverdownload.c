#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

/*
 * this will 'deliver' a download to the user by finding it in the
 *
 * arg1 the username
 *
 * arg2 the basename of the file
 *
 * For security reasons it works this way only so that we can't just change
 * arbitary files
 *
 */
int main(int argc, char *argv[])
{
   setuid( 0 );
   char *username = argv[1];
   char *filename = argv[2];

   //build the command to move the file
   char movecmd[2048] = "/bin/mv /var/lib/bwlimit/xfertmp/";
   strcat(movecmd, username);
   strcat(movecmd, "/\"");
   strcat(movecmd, filename);

   strcat(movecmd, "\" /home/e-smith/files/users/");
   strcat(movecmd, username);
   strcat(movecmd, "/home/\"");
   strcat(movecmd, filename);
   strcat(movecmd, "\"");
   
   system( movecmd );

   //now chown the file and finish
   char chowncmd[2048] = "/bin/chown ";
   strcat (chowncmd, username);
   strcat (chowncmd, ":");
   strcat (chowncmd, username);

   strcat (chowncmd, " /home/e-smith/files/users/");
   strcat (chowncmd, username);
   strcat (chowncmd, "/home/\"");
   strcat (chowncmd, filename);
   strcat (chowncmd, "\"");

   system ( chowncmd );


   return 0;
}
