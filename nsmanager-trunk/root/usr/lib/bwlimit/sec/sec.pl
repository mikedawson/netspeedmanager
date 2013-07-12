#!/usr/bin/perl -w
#
# SEC (Simple Event Correlator) 2.5.3 - sec.pl
# Copyright (C) 2000-2009 Risto Vaarandi
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

package main::SEC;

# Parameters: par1 - perl code to be evaluated
#             par2 - if set to 0, the code will be evaluated in scalar
#                    context; if 1, list context is used for evaluation
# Action: calls eval() for the perl code par1, and returns an array with 
#         the eval() return value(s). The first element of the array 
#         indicates whether the code was evaluated successfully (i.e., 
#         the compilation didn't fail). If code evaluation fails, the
#         first element of the return array contains the error string.

sub call_eval {

  my($code) = $_[0];
  my($listcontext) = $_[1];
  my($ok, @result);

  $ok = 1;

  if ($listcontext) {
    @result = eval $code;
  } else {
    $result[0] = eval $code;
  }

  if ($@) {
    $ok = 0; 
    chomp($result[0] = $@);
  }

  return ($ok, @result);

}

######################################################################

package main;

use strict;

##### List of global variables #####

use vars qw(
  @actioncopyfunc
  @actionsubstfunc
  $blocksize
  $bufpos
  $bufsize
  @calendar
  %cfset2cfile
  $check_timeout
  %children
  $cleantime
  @conffilepat
  @conffiles
  %config_ltimes
  %config_mtimes
  %config_options
  %configuration
  %context_list
  %corr_list
  $debuglevel
  $debuglevelset
  $detach
  $dumpdata
  $dumpfile
  @events
  $evstoresize
  @execactionfunc
  $fromstart
  $help
  @inputfilepat
  @inputfiles
  %inputsrc
  @input_buffer
  @input_sources
  $input_timeout
  $intcontexts
  $intevents
  %int_contexts
  $lastcleanuptime
  $lastconfigload
  $logfile
  @maincfiles
  @matchfunc
  $openlog
  @pending_events
  $pidfile
  $poll_timeout
  $processedlines
  @processrulefunc
  $quoting
  $rcfile_status
  @readbuffer
  $refresh
  $reopen_timeout
  $SEC_COPYRIGHT
  $SEC_LICENSE
  $SEC_USAGE
  $SEC_VERSION
  $SYSLOGAVAIL
  $sec_options
  $softrefresh
  $startuptime
  $syslogf
  $tail
  $terminate
  $testonly
  $timeout_script
  %variables
  $version
  $WIN32
);


##### Load modules and set some global variables ##### 

use Getopt::Long;
use POSIX qw(:errno_h :sys_wait_h SEEK_SET SEEK_CUR SEEK_END setsid);
use Fcntl;
use IO::Handle;

# check if Sys::Syslog is available

$SYSLOGAVAIL = eval { require Sys::Syslog };

# check if the platform is win32

$WIN32 = ($^O =~ /win/i  &&  $^O !~ /cygwin/i  &&  $^O !~ /darwin/i);

# set version and usage variables

$SEC_VERSION = "SEC (Simple Event Correlator) 2.5.3";
$SEC_COPYRIGHT = "Copyright (C) 2000-2009 Risto Vaarandi";

$SEC_USAGE = qq!Usage: $0 [options] 

Options:
  -conf=<file pattern> ...
  -input=<file pattern>[=<context>] ...
  -input_timeout=<input timeout> 
  -timeout_script=<timeout script>
  -reopen_timeout=<reopen timeout>
  -check_timeout=<check timeout>
  -poll_timeout=<poll timeout>
  -blocksize=<io block size>
  -bufsize=<input buffer size>
  -evstoresize=<event store size>
  -cleantime=<clean time>
  -log=<logfile>
  -syslog=<facility>
  -debug=<debuglevel>
  -pid=<pidfile>
  -dump=<dumpfile>
  -quoting, -noquoting
  -tail, -notail
  -fromstart, -nofromstart
  -detach, -nodetach
  -intevents, -nointevents
  -intcontexts, -nointcontexts
  -testonly, -notestonly
  -help, -?
  -version
!;

$SEC_LICENSE = q!
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
!;


##### List of internal constants #####

use constant CONFIG_KEYWORDS => {
  type => 1,
  continue => 1,
  ptype => 1,
  pattern => 1,
  context => 1,
  desc => 1,
  action => 1,
  window => 1,
  thresh => 1,
  continue2 => 1,
  ptype2 => 1,
  pattern2 => 1,
  context2 => 1,
  desc2 => 1,
  action2 => 1,
  window2 => 1,
  thresh2 => 1,
  time => 1,
  script => 1,
  cfset => 1,
  constset => 1,
  joincfset => 1,
  procallin => 1,
  rem => 1,
  label => 1
};

use constant INVALIDVALUE 	=> -1;

use constant SINGLE 		=> 0;
use constant SINGLE_W_SUPPRESS	=> 1;
use constant SINGLE_W_SCRIPT	=> 2;
use constant PAIR		=> 3;
use constant PAIR_W_WINDOW	=> 4;
use constant SINGLE_W_THRESHOLD	=> 5;
use constant SINGLE_W_2_THRESHOLDS => 6;
use constant SUPPRESS		=> 7;
use constant CALENDAR		=> 8;
use constant JUMP		=> 9;

use constant SUBSTR		=> 0;
use constant REGEXP		=> 1;
use constant PERLFUNC		=> 2;
use constant NSUBSTR		=> 3;
use constant NREGEXP		=> 4;
use constant NPERLFUNC		=> 5;
use constant TVALUE		=> 6;

use constant DONTCONT		=> 0;
use constant TAKENEXT		=> 1;
use constant GOTO		=> 2;

use constant NONE		=> 0;
use constant LOGONLY		=> 1;
use constant WRITE		=> 2;
use constant SHELLCOMMAND	=> 3;
use constant SPAWN		=> 4;
use constant PIPE		=> 5;
use constant CREATECONTEXT	=> 6;
use constant DELETECONTEXT	=> 7;
use constant OBSOLETECONTEXT	=> 8;
use constant SETCONTEXT		=> 9;
use constant ALIAS		=> 10;
use constant UNALIAS		=> 11;
use constant ADD		=> 12;
use constant FILL		=> 13;
use constant REPORT		=> 14;
use constant COPYCONTEXT	=> 15;
use constant EMPTYCONTEXT	=> 16;
use constant EVENT		=> 17;
use constant TEVENT		=> 18;
use constant RESET		=> 19;
use constant ASSIGN		=> 20;
use constant EVAL		=> 21;
use constant CALL		=> 22;

use constant OPERAND		=> 0;
use constant NEGATION		=> 1;
use constant AND		=> 2;
use constant OR			=> 3;
use constant EXPRESSION		=> 4;
use constant ECODE		=> 5;
use constant CCODE		=> 6;

use constant EXPRSYMBOL		=> "\0";

use constant LOG_CRIT           => 1;
use constant LOG_ERR            => 2;
use constant LOG_WARN           => 3;
use constant LOG_NOTICE         => 4;
use constant LOG_INFO           => 5;
use constant LOG_DEBUG          => 6;

use constant SYSLOG_LEVELS => {
  1 => "crit",
  2 => "err",
  3 => "warning",
  4 => "notice",
  5 => "info",
  6 => "debug"
};

use constant SEPARATOR		=> " | ";

use constant TERMTIMEOUT	=> 3;


###############################################################
# ------------------------- FUNCTIONS -------------------------
###############################################################

##############################
# Functions related to logging
##############################


# Parameters: par1 - name of the logfile
# Action: logfile will be opened. Filehandle of the logfile will be
#         saved to the global filehandle LOGFILE.

sub open_logfile {

  my($logfile) = $_[0];

  if (open(LOGFILE, ">>$logfile")) { 

    select LOGFILE;
    $| = 1;
    select STDOUT;

  } else {

    if (-t STDERR  ||  -f STDERR) { 
      print STDERR "Can't open logfile $logfile ($!), exiting!\n";
    }
    child_cleanup();
    exit(1);

  }

}


# Parameters: par1 - syslog facility
# Action: open connection to the system logger with the facility par1.

sub open_syslog {

  my($facility) = $_[0];
  my($progname);

  if (!$SYSLOGAVAIL) {

    if (-t STDERR  ||  -f STDERR) {
      print STDERR "Can't connect to syslog (no Sys::Syslog), exiting!\n";
    }
    child_cleanup();
    exit(1);

  }

  $progname = $0;
  $progname =~ s/.*\///;

  eval { Sys::Syslog::openlog($progname, "pid", $facility) };

  if ($@) {

    if (-t STDERR  ||  -f STDERR) {
      print STDERR "Can't connect to syslog ($@), exiting!\n";
    }
    child_cleanup();
    exit(1);

  }

}


# Parameters: par1 - severity of the log message
#             par2, par3, ... - strings to be logged
# Action: if par1 is smaller or equal to the current logging level (i.e.,
#         the message must be logged), then strings par2, par3, ... 
#         will be equipped with timestamp and written to LOGFILE and/or 
#         forwarded to the system logger as a single line. If STDERR is 
#         connected to terminal, message will also be written there.

sub log_msg {

  my($level) = shift(@_);
  my($ltime, $msg);

  if ($debuglevel < $level)  { return; }

  if (!$logfile && !$syslogf && ! -t STDERR)  { return; }

  $msg = join(" ", @_);

  if (-t STDERR)  { print STDERR "$msg\n"; }

  if ($logfile) {
    $ltime = localtime(time());
    print LOGFILE "$ltime: $msg\n"; 
  }

  if ($syslogf) { 
    $msg =~ s/%/%%/g;
    eval { Sys::Syslog::syslog(SYSLOG_LEVELS->{$level}, $msg) }; 
  }

}


#######################################################
# Functions related to configuration file(s) processing
#######################################################


# Parameters: par1, par2, .. - strings
# Action: All 2-byte substrings in par1, par2, .. that denote special 
#         symbols ("\n", "\t", ..) will be replaced with corresponding
#         special symbols

sub subst_specchar {

  my(%specchar, $string);

  $specchar{"0"} = "";
  $specchar{"n"} = "\n";
  $specchar{"r"} = "\r";
  $specchar{"s"} = " ";
  $specchar{"t"} = "\t";
  $specchar{"\\"} = "\\";

  foreach $string (@_) {
    $string =~ s/\\(0|n|r|s|t|\\)/$specchar{$1}/g;
  }

}


# Parameters: par1 - expression
#             par2 - reference to an array
# Action: parentheses and their contents will be replaced with special 
#         symbols EXPRSYMBOL in par 1. The expressions inside parentheses 
#         will be returned in par2. Previous content of the array par2 
#         is erased. If par1 was parsed successfully, the modified par1
#         will be returned, otherwise undef is returned.

sub replace_subexpr {

  my($expression) = $_[0];
  my($expr_ref) = $_[1];
  my($i, $j, $l, $pos);
  my($char, $prev);

  @{$expr_ref} = ();

  $i = 0;
  $j = 0;
  $l = length($expression);
  $pos = undef;
  $prev = "";

  while ($i < $l) {

    # process expression par1 from the start and inspect every symbol, 
    # adding 1 to $j for every '(' and subtracting 1 for every ')';
    # if a parenthesis is masked with a backslash, it is ignored

    $char = substr($expression, $i, 1);

    if ($prev ne "\\") {
      if ($char eq "(")  { ++$j; }  elsif ($char eq ")")  { --$j; }
    }

    # After observing first '(' save its position to $pos;
    # after observing its counterpart ')' replace everything
    # from '(' to ')' with EXPRSYMBOL (including possible nested
    # expressions), and save the content of parentheses;
    # if at some point $j becomes negative, the parentheses must
    # be unbalanced

    if ($j == 1  &&  !defined($pos))  { $pos = $i; }

    elsif ($j == 0  &&  defined($pos)) {

      # take symbols starting from position $pos+1 (next symbol after
      # '(') up to position $i-1 (the symbol before ')'), and save
      # the symbols to array

      push @{$expr_ref}, substr($expression, $pos + 1, $i - $pos - 1);

      # replace both the parentheses and the symbols between them 
      # with EXPRSYMBOL

      substr($expression, $pos, $i - $pos + 1) = EXPRSYMBOL;

      # set the variables according to changes in expression

      $i = $pos;
      $l = length($expression);
      $pos = undef;
      $char = "";

    }

    elsif ($j < 0)  { return undef; }    # extra ')' was found

    $prev = $char;

    ++$i;

  }

  # if the parsing ended with non-zero $j, the parentheses were unbalanced

  if ($j == 0)  { return $expression; }  else { return undef; }

}


# Parameters: par1 - continue value (string)
#             par2 - the name of the configuration file
#             par3 - line number in configuration file
# Action: par1 will be analyzed and the integer continue value with
#         an optional jump label will be returned.
#         If errors are found when analyzing par1, error message 
#         about improper line par3 in configuration file will be logged.

sub analyze_continue {

  my($continue) = $_[0];
  my($conffile) = $_[1];
  my($lineno) = $_[2];

  if (uc($continue) eq "TAKENEXT")  { return (TAKENEXT, undef); }
  elsif (uc($continue) eq "DONTCONT")  { return (DONTCONT, undef); }
  elsif ($continue =~ /^goto\s+(.*\S)/i)  { return (GOTO, $1); }

  log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
          "Invalid continue value '$continue'");
  return INVALIDVALUE; 

}


# Parameters: par1 - pattern type (string)
#             par2 - pattern
#             par3 - the name of the configuration file
#             par4 - line number in configuration file
#             par5 - if we are dealing with the second pattern of Pair*
#                    rule, par5 contains the type of the first pattern
# Action: par1 and par2 will be analyzed and tuple of integers
#         (pattern type, line count, compiled pattern) will be returned 
#         (line count shows how many lines the pattern is designed to match).
#         If errors are found when analyzing par1 and par2, error message 
#         about improper line par4 in configuration file will be logged.

sub analyze_pattern {

  my($pattype) = $_[0];
  my($pat) = $_[1];
  my($conffile) = $_[2];
  my($lineno) = $_[3];
  my($negate, $lines);
  my($evalok, $retval);

  if ($pattype =~ /^(n?)regexp(\d*)$/i) {

    if (length($1))  { $negate = 1; }  else { $negate = 0; }
    if (length($2))  { $lines = $2; }  else { $lines = 1; }

    if ($lines > $bufsize  ||  $lines < 1) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid linecount $lines in '$pattype'");
      return (INVALIDVALUE, INVALIDVALUE, INVALIDVALUE);
    }

    eval { "" =~ /$pat/; };

    if ($@) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid regular expression '$pat'");
      return (INVALIDVALUE, INVALIDVALUE, INVALIDVALUE);
    }

    if (!defined($_[4]) || $_[4] == TVALUE
        || $_[4] == SUBSTR || $_[4] == NSUBSTR)  { $pat = qr/$pat/; } 

    if ($negate) { return (NREGEXP, $lines, $pat); } 
      else { return (REGEXP, $lines, $pat); }

  } elsif ($pattype =~ /^(n?)substr(\d*)$/i) {

    if (length($1))  { $negate = 1; }  else { $negate = 0; }
    if (length($2))  { $lines = $2; }  else { $lines = 1; }

    if ($lines > $bufsize  ||  $lines < 1) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:",
              "Invalid linecount $lines in '$pattype'");
      return (INVALIDVALUE, INVALIDVALUE, INVALIDVALUE);
    }

    subst_specchar($pat);

    if ($negate) { return (NSUBSTR, $lines, $pat); }
      else { return (SUBSTR, $lines, $pat); }

  } elsif ($pattype =~ /^(n?)perlfunc(\d*)$/i) {

    if (length($1))  { $negate = 1; }  else { $negate = 0; }
    if (length($2))  { $lines = $2; }  else { $lines = 1; }

    if ($lines > $bufsize  ||  $lines < 1) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid linecount $lines in '$pattype'");
      return (INVALIDVALUE, INVALIDVALUE, INVALIDVALUE);
    }

    ($evalok, $retval) = SEC::call_eval($pat, 0);

    if (!$evalok || !defined($retval) || ref($retval) ne "CODE") {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid function '$pat'", defined($retval)?"($retval)":"");
      return (INVALIDVALUE, INVALIDVALUE, INVALIDVALUE);
    }

    if ($negate) { return (NPERLFUNC, $lines, $retval); } 
      else { return (PERLFUNC, $lines, $retval); }

  } elsif ($pattype =~ /^tvalue$/i) { 

    if (uc($pat) ne "TRUE"  &&  uc($pat) ne "FALSE") {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid truth value '$pat'");
      return (INVALIDVALUE, INVALIDVALUE, INVALIDVALUE);
    }

    return (TVALUE, 1, uc($pat) eq "TRUE");

  }

  log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
          "Invalid pattern type '$pattype'");
  return (INVALIDVALUE, INVALIDVALUE, INVALIDVALUE);

}


# Parameters: par1 - action
#             par2 - the name of the configuration file
#             par3 - line number in configuration file
#             par4 - rule ID
# Action: par1 will be analyzed and pair of integers
#         (action type, action description) will be returned. If errors
#         are found when analyzing par1, error message about improper 
#         line par3 in configuration file will be logged.

sub analyze_action {

  my($action) = $_[0];
  my($conffile) = $_[1];
  my($lineno) = $_[2];
  my($ruleid) = $_[3];
  my($file, $cmdline, $progname);
  my($sign, $rule);
  my($actionlist, @action);
  my($createafter, $event);
  my($lifetime, $context, $alias);
  my($variable, $value, $code, $codeptr, $params);

  if ($action =~ /^none$/i)  { return NONE; }

  elsif ($action =~ /^logonly\b\s*(.*)/i) { 

    $event = $1;

    # strip outer parentheses if they exist
    if ($event =~ /^\s*\(\s*(.*)\)\s*$/)  { $event = $1; }

    # remove backslashes in front of the parentheses
    $event =~ s/\\([\(\)])/$1/g;

    if (!length($event))  { $event = "%s"; }

    return (LOGONLY, $event); 

  }

  elsif ($action =~ /^write\s+(\S+)\s*(.*)/i) {

    $file = $1;
    $event = $2;

    # strip outer parentheses if they exist
    if ($file =~ /^\s*\(\s*(.*)\)\s*$/)  { $file = $1; }
    if ($event =~ /^\s*\(\s*(.*)\)\s*$/)  { $event = $1; }

    # remove backslashes in front of the parentheses
    $file =~ s/\\([\(\)])/$1/g;
    $event =~ s/\\([\(\)])/$1/g;

    if (!length($event))  { $event = "%s"; }

    return (WRITE, $file, $event); 

  }

  elsif ($action =~ /^shellcmd\s+(.*\S)/i) { 

    $cmdline = $1;

    # strip outer parentheses if they exist
    if ($cmdline =~ /^\s*\(\s*(.*)\)\s*$/)  { $cmdline = $1; }

    # remove backslashes in front of the parentheses
    $cmdline =~ s/\\([\(\)])/$1/g;

    $progname = (split(' ', $cmdline))[0];

    if (! -f $progname) {
      log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
              "Warning - could not find '$progname'");
    } elsif (! -x $progname) {
      log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
              "Warning - '$progname' is not executable");
    }

    return (SHELLCOMMAND, $cmdline); 

  }

  elsif ($action =~ /^spawn\s+(.*\S)/i) { 

    if ($WIN32) {
      log_msg(LOG_ERR, "'spawn' action is not supported on Win32");
      return INVALIDVALUE;
    }

    $cmdline = $1;

    # strip outer parentheses if they exist
    if ($cmdline =~ /^\s*\(\s*(.*)\)\s*$/)  { $cmdline = $1; }

    # remove backslashes in front of the parentheses
    $cmdline =~ s/\\([\(\)])/$1/g;

    $progname = (split(' ', $cmdline))[0];

    if (! -f $progname) {
      log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
              "Warning - could not find '$progname'");
    } elsif (! -x $progname) {
      log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
              "Warning - '$progname' is not executable");
    }

    return (SPAWN, $cmdline); 

  }

  elsif ($action =~ /^pipe\s+'([^']*)'\s*(.*)/i) {

    $event = $1;
    $cmdline = $2;

    # strip outer parentheses if they exist
    if ($event =~ /^\s*\(\s*(.*)\)\s*$/)  { $event = $1; }
    if ($cmdline =~ /^\s*\(\s*(.*)\)\s*$/)  { $cmdline = $1; }

    # remove backslashes in front of the parentheses
    $event =~ s/\\([\(\)])/$1/g;
    $cmdline =~ s/\\([\(\)])/$1/g;

    if (!length($event))  { $event = "%s"; }

    if (length($cmdline)) {

      $progname = (split(' ', $cmdline))[0];

      if (! -f $progname) {
        log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
                "Warning - could not find '$progname'");
      } elsif (! -x $progname) {
        log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
                "Warning - '$progname' is not executable");
      }

    }

    return (PIPE, $event, $cmdline); 

  }

  elsif ($action =~ /^create\b\s*(\S*)\s*(\S*)\s*(.*)/i) { 

    $context = $1;
    $lifetime = $2;
    $actionlist = $3;

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }
    if ($lifetime =~ /^\s*\(\s*(.*)\)\s*$/)  { $lifetime = $1; }
    if ($actionlist =~ /^\s*\(\s*(.*)\)\s*$/)  { $actionlist = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;
    $lifetime =~ s/\\([\(\)])/$1/g;

    if (!length($context))  { $context = "%s"; }
    if (!length($lifetime))  { $lifetime = 0; }

    if (length($actionlist)) {

      if (!analyze_actionlist($actionlist, \@action,
          $conffile, $lineno, $ruleid))  { return INVALIDVALUE; }

      return (CREATECONTEXT, $context, $lifetime, [ @action ]);

    }

    return (CREATECONTEXT, $context, $lifetime, []);

  }

  elsif ($action =~ /^delete\b\s*(\S*)\s*$/i) { 

    $context = $1;

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;

    if (!length($context))  { $context = "%s"; }

    return (DELETECONTEXT, $context); 

  }

  elsif ($action =~ /^obsolete\b\s*(\S*)\s*$/i) { 

    $context = $1;

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;

    if (!length($context))  { $context = "%s"; }

    return (OBSOLETECONTEXT, $context); 

  }

  elsif ($action =~ /^set\s+(\S+)\s+(\S+)\s*(.*)/i) {

    $context = $1;
    $lifetime = $2;
    $actionlist = $3;

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }
    if ($lifetime =~ /^\s*\(\s*(.*)\)\s*$/)  { $lifetime = $1; }
    if ($actionlist =~ /^\s*\(\s*(.*)\)\s*$/)  { $actionlist = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;
    $lifetime =~ s/\\([\(\)])/$1/g;

    if (length($actionlist)) {

      if (!analyze_actionlist($actionlist, \@action,
          $conffile, $lineno, $ruleid))  { return INVALIDVALUE; }

      return (SETCONTEXT, $context, $lifetime, [ @action ]);

    }

    return (SETCONTEXT, $context, $lifetime, []);

  }

  elsif ($action =~ /^alias\s+(\S+)\s*(\S*)\s*$/i) {

    $context = $1;
    $alias = $2;

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }
    if ($alias =~ /^\s*\(\s*(.*)\)\s*$/)  { $alias = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;
    $alias =~ s/\\([\(\)])/$1/g;

    if (!length($alias))  { $alias = "%s"; }

    return (ALIAS, $context, $alias); 

  }

  elsif ($action =~ /^unalias\b\s*(\S*)\s*$/i) { 

    $alias = $1;

    # strip outer parentheses if they exist
    if ($alias =~ /^\s*\(\s*(.*)\)\s*$/)  { $alias = $1; }

    # remove backslashes in front of the parentheses
    $alias =~ s/\\([\(\)])/$1/g;

    if (!length($alias))  { $alias = "%s"; }

    return (UNALIAS, $alias); 

  }

  elsif ($action =~ /^add\s+(\S+)\s*(.*)/i) {

    $context = $1;
    $event = $2;

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }
    if ($event =~ /^\s*\(\s*(.*)\)\s*$/)  { $event = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;
    $event =~ s/\\([\(\)])/$1/g;

    if (!length($event))  { $event = "%s"; }

    return (ADD, $context, $event); 

  }

  elsif ($action =~ /^fill\s+(\S+)\s*(.*)/i) {

    $context = $1;
    $event = $2;

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }
    if ($event =~ /^\s*\(\s*(.*)\)\s*$/)  { $event = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;
    $event =~ s/\\([\(\)])/$1/g;

    if (!length($event))  { $event = "%s"; }

    return (FILL, $context, $event); 

  }

  elsif ($action =~ /^report\s+(\S+)\s*(.*)/i) {

    $context = $1;
    $cmdline = $2;

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }
    if ($cmdline =~ /^\s*\(\s*(.*)\)\s*$/)  { $cmdline = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;
    $cmdline =~ s/\\([\(\)])/$1/g;

    if (length($cmdline)) {

      $progname = (split(' ', $cmdline))[0];

      if (! -f $progname) {
        log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
                "Warning - could not find '$progname'");
      } elsif (! -x $progname) {
        log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
                "Warning - '$progname' is not executable");
      }

    }

    return (REPORT, $context, $cmdline); 

  }

  elsif ($action =~ /^copy\s+(\S+)\s+(\S+)\s*$/i) {

    $context = $1;
    $variable = $2;

    if ($variable !~ /^%[A-Za-z][A-Za-z0-9_]*$/) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                       "Variable $variable does not have the form",
                       "%<letter>[<letter>|<digit>|<underscore>]...");
      return INVALIDVALUE;
    }

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;

    return (COPYCONTEXT, $context, substr($variable, 1)); 

  }

  elsif ($action =~ /^empty\s+(\S+)\s*(\S*)\s*$/i) {

    $context = $1;
    $variable = $2;

    if (length($variable)  &&  $variable !~ /^%[A-Za-z][A-Za-z0-9_]*$/) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                       "Variable $variable does not have the form",
                       "%<letter>[<letter>|<digit>|<underscore>]...");
      return INVALIDVALUE;
    }

    # strip outer parentheses if they exist
    if ($context =~ /^\s*\(\s*(.*)\)\s*$/)  { $context = $1; }

    # remove backslashes in front of the parentheses
    $context =~ s/\\([\(\)])/$1/g;

    if (!length($variable))  { return (EMPTYCONTEXT, $context, ""); }

    return (EMPTYCONTEXT, $context, substr($variable, 1)); 

  }

  elsif ($action =~ /^event\b\s*(\d*)\b\s*(.*)/i) {

    $createafter = $1;
    $event = $2;

    # strip outer parentheses if they exist
    if ($event =~ /^\s*\(\s*(.*)\)\s*$/)  { $event = $1; }

    # remove backslashes in front of the parentheses
    $event =~ s/\\([\(\)])/$1/g;

    if (!length($createafter))  { $createafter = 0; }
    if (!length($event))  { $event = "%s"; }

    return (EVENT, $createafter, $event); 

  }

  elsif ($action =~ /^tevent\s+(\S+)\s*(.*)/i) {

    $createafter = $1;
    $event = $2;

    # strip outer parentheses if they exist
    if ($createafter =~ /^\s*\(\s*(.*)\)\s*$/)  { $createafter = $1; }
    if ($event =~ /^\s*\(\s*(.*)\)\s*$/)  { $event = $1; }

    # remove backslashes in front of the parentheses
    $createafter =~ s/\\([\(\)])/$1/g;
    $event =~ s/\\([\(\)])/$1/g;

    if (!length($event))  { $event = "%s"; }

    return (TEVENT, $createafter, $event); 

  }

  elsif ($action =~ /^reset\b\s*([\+-]?)(\d*)\b\s*(.*)/i) { 

    $sign = $1;
    $rule = $2;
    $event = $3;

    if (length($rule)) {

      if ($sign eq "+") { $rule = $ruleid + $rule; }
      elsif ($sign eq "-") { $rule = $ruleid - $rule; }
      elsif (!$rule) { $rule = $ruleid; } 
      else { --$rule; }

    } else { $rule = ""; }

    # strip outer parentheses if they exist
    if ($event =~ /^\s*\(\s*(.*)\)\s*$/)  { $event = $1; }

    # remove backslashes in front of the parentheses
    $event =~ s/\\([\(\)])/$1/g;

    if (!length($event))  { $event = "%s"; }

    return (RESET, $conffile, $rule, $event); 

  }

  elsif ($action =~ /^assign\s+(\S+)\s*(.*)/i) {

    $variable = $1;
    $value = $2;

    if ($variable !~ /^%[A-Za-z][A-Za-z0-9_]*$/) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                       "Variable $variable does not have the form",
                       "%<letter>[<letter>|<digit>|<underscore>]...");
      return INVALIDVALUE;
    }

    # strip outer parentheses if they exist
    if ($value =~ /^\s*\(\s*(.*)\)\s*$/)  { $value = $1; }

    # remove backslashes in front of the parentheses
    $value =~ s/\\([\(\)])/$1/g;

    if (!length($value))  { $value = "%s"; }

    return (ASSIGN, substr($variable, 1), $value); 

  }

  elsif ($action =~ /^eval\s+(\S+)\s+(.*\S)/i) {

    $variable = $1;
    $code = $2;

    if ($variable !~ /^%[A-Za-z][A-Za-z0-9_]*$/) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                       "Variable $variable does not have the form",
                       "%<letter>[<letter>|<digit>|<underscore>]...");
      return INVALIDVALUE;
    }

    # strip outer parentheses if they exist
    if ($code =~ /^\s*\(\s*(.*)\)\s*$/)  { $code = $1; }

    # remove backslashes in front of the parentheses
    $code =~ s/\\([\(\)])/$1/g;

    return (EVAL, substr($variable, 1), $code); 

  }

  elsif ($action =~ /^call\s+(\S+)\s+(\S+)\s*(.*)/i) {

    $variable = $1;
    $codeptr = $2;
    $params = $3;

    if ($variable !~ /^%[A-Za-z][A-Za-z0-9_]*$/) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                       "Variable $variable does not have the form",
                       "%<letter>[<letter>|<digit>|<underscore>]...");
      return INVALIDVALUE;
    }

    if ($codeptr !~ /^%[A-Za-z][A-Za-z0-9_]*$/) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                       "Variable $codeptr does not have the form",
                       "%<letter>[<letter>|<digit>|<underscore>]...");
      return INVALIDVALUE;
    }

    # strip outer parentheses if they exist
    if ($params =~ /^\s*\(\s*(.*)\)\s*$/)  { $params = $1; }

    # remove backslashes in front of the parentheses
    $params =~ s/\\([\(\)])/$1/g;

    return (CALL, substr($variable, 1), 
                  substr($codeptr, 1), [ split(' ', $params) ]); 

  }

  log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
          "Invalid action '$action'");
  return INVALIDVALUE;

}


# Parameters: par1 - action list separated by semicolons
#             par2 - reference to an array
#             par3 - the name of the configuration file
#             par4 - line number in configuration file
#             par5 - rule ID
# Action: par1 will be split to parts, each part is analyzed and saved
#         to array @{$par2}. Previous content of the array is erased.
#         Parameters par3..par5 will be passed to the analyze_action()
#         function for logging purposes. Return 0 if an invalid action
#         was detected in the list par1, otherwise return 1.

sub analyze_actionlist {

  my($actionlist) = $_[0];
  my($arrayref) = $_[1];
  my($conffile) = $_[2];
  my($lineno) = $_[3];
  my($ruleid) = $_[4];
  my(@parts, $part);
  my($actiontype, @action);
  my($newactionlist, @list, $expr);
  my($pos, $l);

  @{$arrayref} = ();

  # replace the actions that are in parentheses with special symbols
  # and save the actions to @list

  $newactionlist = replace_subexpr($actionlist, \@list);

  if (!defined($newactionlist))  { return 0; }

  @parts = split(/\s*;\s*/, $newactionlist);

  $l = length(EXPRSYMBOL);

  foreach $part (@parts) {

    # substitute special symbols with expressions 
    # that were removed previously

    for (;;) {

      $pos = index($part, EXPRSYMBOL);
      if ($pos == -1)  { last; }

      $expr = shift @list;
      substr($part, $pos, $l) = "(" . $expr . ")";

    }

    # analyze the action list part

    ($actiontype, @action) = 
        analyze_action($part, $conffile, $lineno, $ruleid);

    if ($actiontype == INVALIDVALUE)  { return 0; }

    push @{$arrayref}, $actiontype, @action;

  }

  return 1;

}


# Parameters: par1 - context expression
#             par2 - reference to an array
# Action: par1 will be analyzed and saved to array par2 in reverse
#         polish notation form (it is assumed that par1 does not contain
#         expressions in parentheses). Previous content of the array par2 
#         is erased. If errors are found when analyzing par1, 0 will be 
#         returned, otherwise 1 will be returned.

sub analyze_context_expr {

  my($context) = $_[0];
  my($result) = $_[1];
  my($pos, $op1, $op2);
  my(@side1, @side2);
  my($evalok, $retval);

  # if we are parsing '&&' and '||' operators that take 2 operands, 
  # process the context expression from the end with rindex(), in order 
  # to get "from left to right" processing for AND and OR at runtime

  $pos = rindex($context, "||");

  if ($pos != -1) {

    $op1 = substr($context, 0, $pos);
    $op2 = substr($context, $pos + 2);

    if (!analyze_context_expr($op1, \@side1))  { return 0; }
    if (!analyze_context_expr($op2, \@side2))  { return 0; }

    @{$result} = ( @side1, @side2, OR );
    return 1;

  }

  $pos = rindex($context, "&&");

  if ($pos != -1) {

    $op1 = substr($context, 0, $pos);
    $op2 = substr($context, $pos + 2);

    if (!analyze_context_expr($op1, \@side1))  { return 0; }
    if (!analyze_context_expr($op2, \@side2))  { return 0; }

    @{$result} = ( @side1, @side2, AND );
    return 1;

  }

  # check for possible typos for '!' operator (any preceding illegal symbols)

  $pos = index($context, "!");

  if ($pos != -1) {

    $op1 = substr($context, 0, $pos);
    $op2 = substr($context, $pos + 1);

    if ($op1 !~ /^\s*$/)  { return 0; }
    if (!analyze_context_expr($op2, \@side2))  { return 0; }

    @{$result} = ( @side2, NEGATION );
    return 1;

  }

  # since CCODE, ECODE and OPERAND are terminals, make sure that any 
  # leading and trailing whitespace is removed from their parameters 
  # (rest of the code relies on that); also, remove backslashes in front 
  # of the parentheses

  if ($context =~ /^\s*(.*?)\s*->\s*(.*\S)/) {

    $op1 = $1;
    $op2 = $2;

    if ($op1 ne EXPRSYMBOL) { 
      $op1 =~ s/\\([\(\)])/$1/g; 
      $op1 = [ split(' ', $op1) ];
    }

    if ($op2 ne EXPRSYMBOL) {

      $op2 =~ s/\\([\(\)])/$1/g;

      ($evalok, $retval) = SEC::call_eval($op2, 0);

      if (!$evalok || !defined($retval) || ref($retval) ne "CODE") {
        log_msg(LOG_ERR, "Eval '$op2' didn't return a code reference:", 
                         defined($retval)?$retval:"undef");
        return 0;
      }

      $op2 = $retval;

    }

    @{$result} = ( CCODE, $op1, $op2 );
    return 1;

  }

  if ($context =~ /^\s*=\s*(.*\S)/) {

    $op1 = $1;
    if ($op1 ne EXPRSYMBOL)  { $op1 =~ s/\\([\(\)])/$1/g; }

    @{$result} = ( ECODE, $op1 );
    return 1;

  }

  if ($context =~ /^\s*(.*\S)/) {

    $op1 = $1;

    if ($op1 ne EXPRSYMBOL) { 
      $op1 =~ s/\\([\(\)])/$1/g; 
      # if operand is a context name, verify it contains no whitespace
      if ($op1 !~ /^\S+$/)  { return 0; }
    }

    @{$result} = ( OPERAND, $op1 );
    return 1;

  }

  return 0;

}


# Parameters: par1 - context description
#             par2 - reference to an array
# Action: par1 will be analyzed and saved to array par2 in reverse polish
#         notation form. Previous content of the array par2 is erased. 
#         If errors are found when analyzing par1, 0 will be returned, 
#         otherwise 1 will be returned.

sub analyze_context {

  my($context) = $_[0];
  my($result) = $_[1];
  my($newcontext, $i, $j);
  my($params, $code, $evalok, $retval);
  my($subexpr, @expr);

  # replace upper level expressions in parentheses with special symbol
  # and save the expressions to @expr (i.e. !(a && (b || c )) || d 
  # becomes !specialsymbol || d, and "a && (b || c )" is saved to @expr);
  # if context was not parsed successfully, exit

  $newcontext = replace_subexpr($context, \@expr);

  if (!defined($newcontext))  { return 0; }

  # convert the context to reverse polish notation, and if there
  # were no parenthesized subexpressions found in the context during
  # previous step, exit

  if (!analyze_context_expr($newcontext, $result))  { return 0; }

  if ($newcontext eq $context)  { return 1; }

  # If the context contains parenthesized subexpressions, analyze and 
  # convert these expressions recursively, attaching the results to 
  # the current context. If a parenthesized expression is a Perl code,
  # it will not be analyzed recursively but rather treated as a terminal
  # (backslashes in front of the parentheses are removed)

  $i = 0;
  $j = scalar(@{$result});

  while ($i < $j) {
 
    if ($result->[$i] == OPERAND) {

      if ($result->[$i+1] eq EXPRSYMBOL) {

        $result->[$i] = EXPRESSION;
        $result->[$i+1] = [];
        $subexpr = shift @expr;
        if (!analyze_context($subexpr, $result->[$i+1]))  { return 0; }

      }

      $i += 2;
 
    }

    elsif ($result->[$i] == ECODE) {

      if ($result->[$i+1] eq EXPRSYMBOL) { 

        $code = shift @expr;
        $code =~ s/\\([\(\)])/$1/g;
        $result->[$i+1] = $code; 

      }
 
      $i += 2;
 
    }

    elsif ($result->[$i] == CCODE) {

      if ($result->[$i+1] eq EXPRSYMBOL) {

        $params = shift @expr;
        $params =~ s/\\([\(\)])/$1/g;
        $result->[$i+1] = [ split(' ', $params) ];

      }

      if ($result->[$i+2] eq EXPRSYMBOL) { 

        $code = shift @expr;
        $code =~ s/\\([\(\)])/$1/g;

        ($evalok, $retval) = SEC::call_eval($code, 0);

        if (!$evalok || !defined($retval) || ref($retval) ne "CODE") {
          log_msg(LOG_ERR, "Eval '$code' didn't return a code reference:", 
                           defined($retval)?$retval:"undef");
          return 0;
        }

        $result->[$i+2] = $retval;
 
      }

      $i += 3;
 
    }

    else { ++$i; }

  }

  return 1;

}


# Parameters: par1 - context description
# Action: if par1 is surrounded by [] brackets, the brackets will be
#         removed and 1 will be returned, otherwise 0 will be returned.

sub check_context_preeval {

  if ($_[0] =~ /^\s*\[(.*)\]\s*$/) { 
    $_[0] = $1; 
    return 1;
  } else {
    return 0;
  }

}


# Parameters: par1 - list of the time values
#             par2 - minimum possible value for time
#             par3 - maximum possible value for time
#             par4 - offset that must be added to every list value
#             par5 - reference to a hash where every list value is added
# Action: take the list definition and find the time values that belong
#         to the list (list definition is given in crontab-style).
#         After the values have been calculated, add an element to par5 with
#         the key that equals to the calculated value + offset. Leading zeros 
#         are removed from keys (rest of the code relies on that). E.g., if 
#         offset is 0, then "02,5-07" becomes 2,5,6,7; if offset is -1, min 
#         is 1, and max is 12, then "2,5-7,11-" becomes 1,4,5,6,10,11. Before 
#         adding elements to par5, its previous content is erased. If par1 is 
#         specified incorrectly, return value is 0, otherwise 1 is returned.

sub eval_timelist {

  my($spec) = $_[0];
  my($min) = $_[1];
  my($max) = $_[2];
  my($offset) = $_[3];
  my($ref) = $_[4];
  my(@parts, $part, $step);
  my($pos, $range1, $range2);
  my($i, $j);

  # split time specification into parts (by comma) and look what
  # ranges or individual numbers every part defines

  @parts = split(/,/, $spec);
  if (!scalar(@parts))  { return 0; }

  %{$ref} = ();

  foreach $part (@parts) {

    # if part is empty, skip it and take the next part

    if (!length($part))  { next; }

    # check if part has a valid step value (0 is illegal)
 
    if ($part =~ /^(.+)\/0*(\d+)$/) {
      $part = $1;
      $step = $2;
      if ($step == 0)  { return 0; }
    } else {
      $step = undef;
    }

    # if part equals to '*', assume that it defines the range min..max

    if ($part eq "*") {

      # add offset (this also forces numeric context, so "05" becomes "5")
      # and save values to the hash; if step was not defined, assume 1

      $i = $min + $offset;
      $j = $max + $offset;

      if (!defined($step))  { $step = 1; }

      while ($i <= $j) { 
        $ref->{$i} = 1; 
        $i += $step; 
      }

      next;

    }

    # if part is not empty and not '*', check if it contains '-'

    $pos = index($part, "-");

    if ($pos == -1) {

      # if part does not contain '-', assume it defines a single number

      if ($part =~ /^0*(\d+)$/)  { $part = $1; }  else { return 0; }
      if ($part < $min  ||  $part > $max)  { return 0; }

      # step value is illegal for a single number
      
      if (defined($step))  { return 0; }

      # add offset and save value to the hash

      $part += $offset;
      $ref->{$part} = 1;

    } else {

      # if part does contain '-', assume it defines a range

      $range1 = substr($part, 0, $pos);
      $range2 = substr($part, $pos + 1);

      # if left side of the range is missing, assume minimum for the value;
      # if right side of the range is missing, assume maximum for the value;
      # offset is then added to the left and right side of the range

      if (length($range1)) {

        if ($range1 =~ /^0*(\d+)$/)  { $range1 = $1; }  else { return 0; }
        if ($range1 < $min  ||  $range1 > $max)  { return 0; }

        $i = $range1 + $offset;

      } else { $i = $min + $offset; }

      if (length($range2)) {

        if ($range2 =~ /^0*(\d+)$/)  { $range2 = $1; }  else { return 0; }
        if ($range2 < $min  ||  $range2 > $max)  { return 0; }

        $j = $range2 + $offset;

      } else { $j = $max + $offset; }

      # save values to the hash; if step was not defined, assume 1

      if (!defined($step))  { $step = 1; }

      while ($i <= $j) { 
        $ref->{$i} = 1; 
        $i += $step; 
      }

    }

  }

  return 1;

}


# Parameters: par1 - time specification
#             par2..par6 - references to the hashes of minutes, hours, 
#                          days, months and weekdays
#             par7 - the name of the configuration file
#             par8 - line number in configuration file
# Action: par1 will be split to parts, every part is analyzed and 
#         results are saved into hashes par2..par6. 
#         Previous content of the hashes is erased. If errors
#         are found when analyzing par1, 0 is returned, otherwise 1
#         will be return value.

sub analyze_timespec {

  my($timespec) = $_[0];
  my($minref) = $_[1];
  my($hourref) = $_[2];
  my($dayref) = $_[3];
  my($monthref) = $_[4];
  my($wdayref) = $_[5];
  my($conffile) = $_[6];
  my($lineno) = $_[7];
  my(@parts);

  # split time specification into parts by whitespace (like with 
  # split(/\s+/, ...)), but leading whitespace will be ignored

  @parts = split(' ', $timespec);

  if (scalar(@parts) != 5) { 
    log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
            "Wrong number of elements in time specification"); 
    return 0; 
  }

  # evaluate minute specification (range 0..59, offset 0)

  if (!eval_timelist($parts[0], 0, 59, 0, $minref)) {
    log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
            "Invalid minute specification '$parts[0]'"); 
    return 0;
  }

  # evaluate hour specification (range 0..23, offset 0)

  if (!eval_timelist($parts[1], 0, 23, 0, $hourref)) {
    log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
            "Invalid hour specification '$parts[1]'"); 
    return 0;
  }

  # evaluate day specification (range 0..31, offset 0)
  # 0 denotes the last day of a month

  if (!eval_timelist($parts[2], 0, 31, 0, $dayref)) {
    log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
            "Invalid day specification '$parts[2]'");
    return 0;
  }

  # evaluate month specification (range 1..12, offset -1)

  if (!eval_timelist($parts[3], 1, 12, -1, $monthref)) {
    log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
            "Invalid month specification '$parts[3]'");
    return 0;
  }

  # evaluate weekday specification (range 0..7, offset 0)

  if (!eval_timelist($parts[4], 0, 7, 0, $wdayref)) {
    log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
            "Invalid weekday specification '$parts[4]'");
    return 0;
  }

  # if 7 was specified as a weekday, also define 0, 
  # since perl uses only 0 for Sunday

  if (exists($wdayref->{"7"}))  { $wdayref->{"0"} = 1; }

  return 1;

}


# Parameters: par1 - reference to a hash containing the rule
#             par2 - list of required keywords for the rule
#             par3 - the type of the rule
#             par4 - the name of the configuration file
#             par5 - line number in configuration file the rule begins at
# Action: check if all required keywords are present in the rule par1 and
#         return 0 if they are, otherwise return 1.

sub missing_keywords {

  my($ref) = $_[0];
  my($keylist) = $_[1];
  my($type) = $_[2];
  my($conffile) = $_[3];
  my($lineno) = $_[4];
  my($key, $error);
 
  $error = 0;

  foreach $key (@{$keylist}) {

    if (!exists($ref->{$key})) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Keyword '$key' missing (needed for the rule type $type)");
      $error = 1;
    }

  }

  return $error;

}


# Parameters: par1 - reference to a hash containing the rule
#             par2 - name of the configuration file
#             par3 - line number in configuration file the rule begins at
#             par4 - rule ID
# Action: check the rule par1 for correctness and save it to
#         global array $configuration{par2} if it is well-defined;
#         if the rule specified rule file options, save the options to
#         global array $config_options{par2} if the rule is well-defined.
#         For a correctly defined Options-rule return 2, for a correctly
#         defined regular rule return 1, for an invalid rule return 0

sub check_rule {

  my($ref) = $_[0];
  my($conffile) = $_[1];
  my($lineno) = $_[2];
  my($number) = $_[3];
  my($config, @keywords);
  my($type, $progname, $cfset);
  my($whatnext, $label, $pattype, $patlines, $pattern, $contpreeval);
  my($whatnext2, $label2, $pattype2, $patlines2, $pattern2, $contpreeval2);
  my(@context, @action, @context2, @action2);
  my(%minutes, %hours, %days, %months, %weekdays);

  $config = $configuration{$conffile};

  if (!exists($ref->{"type"})) { 
    log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
            "Keyword 'type' missing");
    return 0;
  }

  $type = uc($ref->{"type"});

  # ------------------------------------------------------------
  # SINGLE rule
  # ------------------------------------------------------------

  if ($type eq "SINGLE") {

    @keywords = ("ptype", "pattern", "desc", "action");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!exists($ref->{"continue"})) { 
      $whatnext = DONTCONT; 
      $label = undef;
    } else { 
      ($whatnext, $label) =
        analyze_continue($ref->{"continue"}, $conffile, $lineno); 
    }

    if ($whatnext == INVALIDVALUE)  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    if (!analyze_actionlist($ref->{"action"}, \@action, 
                            $conffile, $lineno, $number)) { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action"}, "'");
      return 0; 
    }

    if (exists($ref->{"context"})) {

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    $config->[$number] = { "ID" => $number, 
                           "Type" => SINGLE, 
                           "WhatNext" => $whatnext, 
                           "GotoRule" => $label, 
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines, 
                           "Context" => [ @context ],
                           "ContPreEval" => $contpreeval,
                           "Desc" => $ref->{"desc"}, 
                           "Action" => [ @action ],
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };
    return 1;

  }

  # ------------------------------------------------------------
  # SINGLE_W_SCRIPT rule
  # ------------------------------------------------------------

  elsif ($type eq "SINGLEWITHSCRIPT") {

    @keywords = ("ptype", "pattern", "script", "desc", "action");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!exists($ref->{"continue"})) { 
      $whatnext = DONTCONT; 
      $label = undef;
    } else { 
      ($whatnext, $label) =
        analyze_continue($ref->{"continue"}, $conffile, $lineno); 
    }

    if ($whatnext == INVALIDVALUE)  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    $progname = (split(' ', $ref->{"script"}))[0];

    if (! -f $progname) {
      log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
              "Warning - could not find '$progname'");
    } elsif (! -x $progname) {
      log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
              "Warning - '$progname' is not executable");
    }

    if (!analyze_actionlist($ref->{"action"}, \@action, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action"}, "'");
      return 0; 
    }

    if (exists($ref->{"action2"})) {

      if (!analyze_actionlist($ref->{"action2"}, \@action2, 
                              $conffile, $lineno, $number)) {
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid action list '", $ref->{"action2"}, "'");
        return 0; 
      }

    } else { @action2 = (); }

    if (exists($ref->{"context"})) { 

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    $config->[$number] = { "ID" => $number, 
                           "Type" => SINGLE_W_SCRIPT, 
                           "WhatNext" => $whatnext, 
                           "GotoRule" => $label, 
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines,
                           "Context" => [ @context ],
                           "ContPreEval" => $contpreeval,
                           "Script" => $ref->{"script"},
                           "Desc" => $ref->{"desc"}, 
                           "Action" => [ @action ],
                           "Action2" => [ @action2 ],
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };
    return 1;

  }

  # ------------------------------------------------------------
  # SINGLE_W_SUPPRESS rule
  # ------------------------------------------------------------

  elsif ($type eq "SINGLEWITHSUPPRESS") {

    @keywords = ("ptype", "pattern", "desc", "action", "window");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!exists($ref->{"continue"})) { 
      $whatnext = DONTCONT; 
      $label = undef;
    } else { 
      ($whatnext, $label) =
        analyze_continue($ref->{"continue"}, $conffile, $lineno); 
    }

    if ($whatnext == INVALIDVALUE)  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    if (!analyze_actionlist($ref->{"action"}, \@action, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action"}, "'");
      return 0; 
    }

    if ($ref->{"window"} !~ /^0*(\d+)$/  ||  $1 == 0) { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid time window '", $ref->{"window"}, "'");
      return 0;
    } else { $ref->{"window"} = $1; }

    if (exists($ref->{"context"})) { 

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    $config->[$number] = { "ID" => $number, 
                           "Type" => SINGLE_W_SUPPRESS, 
                           "WhatNext" => $whatnext, 
                           "GotoRule" => $label, 
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines,
                           "Context" => [ @context ], 
                           "ContPreEval" => $contpreeval,
                           "Desc" => $ref->{"desc"}, 
                           "Action" => [ @action ],
                           "Window" => $ref->{"window"},
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };
    return 1;

  }

  # ------------------------------------------------------------
  # PAIR rule
  # ------------------------------------------------------------

  elsif ($type eq "PAIR") {

    @keywords = ("ptype", "pattern", "desc", "action", 
                 "ptype2", "pattern2", "desc2", "action2");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!exists($ref->{"continue"})) { 
      $whatnext = DONTCONT; 
      $label = undef;
    } else { 
      ($whatnext, $label) =
        analyze_continue($ref->{"continue"}, $conffile, $lineno); 
    }

    if ($whatnext == INVALIDVALUE)  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    if (!analyze_actionlist($ref->{"action"}, \@action, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action"}, "'");
      return 0; 
    }

    if (!exists($ref->{"continue2"})) { 
      $whatnext2 = DONTCONT; 
      $label2 = undef;
    } else { 
      ($whatnext2, $label2) =
        analyze_continue($ref->{"continue2"}, $conffile, $lineno); 
    }

    if ($whatnext2 == INVALIDVALUE)  { return 0; }

    ($pattype2, $patlines2, $pattern2) = 
      analyze_pattern($ref->{"ptype2"}, $ref->{"pattern2"}, 
                      $conffile, $lineno, $pattype);

    if ($pattype2 == INVALIDVALUE)  { return 0; }

    if (!analyze_actionlist($ref->{"action2"}, \@action2, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action2"}, "'");
      return 0; 
    }

    if (!exists($ref->{"window"})) { $ref->{"window"} = 0; }
    elsif ($ref->{"window"} =~ /^0*(\d+)$/) { $ref->{"window"} = $1; }
    else { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid time window '", $ref->{"window"}, "'");
      return 0;
    }

    if (exists($ref->{"context"})) { 

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid 1st context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    if (exists($ref->{"context2"})) { 

      $contpreeval2 = check_context_preeval($ref->{"context2"});

      if (!analyze_context($ref->{"context2"}, \@context2)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid 2nd context specification '", $ref->{"context2"}, "'");
        return 0; 
      } 

    } else { @context2 = (); $contpreeval2 = 0; }

    $config->[$number] = { "ID" => $number, 
                           "Type" => PAIR, 
                           "WhatNext" => $whatnext, 
                           "GotoRule" => $label,
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines, 
                           "Context" => [ @context ],
                           "ContPreEval" => $contpreeval,
                           "Desc" => $ref->{"desc"}, 
                           "Action" => [ @action ],
                           "WhatNext2" => $whatnext2,
                           "GotoRule2" => $label2,
                           "PatType2" => $pattype2,
                           "Pattern2" => $pattern2,
                           "PatLines2" => $patlines2,
                           "Context2" => [ @context2 ],
                           "ContPreEval2" => $contpreeval2,
                           "Desc2" => $ref->{"desc2"},
                           "Action2" => [ @action2 ],
                           "Window" => $ref->{"window"},
                           "Operations" => {},
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };
    return 1;

  }

  # ------------------------------------------------------------
  # PAIR_W_WINDOW rule
  # ------------------------------------------------------------

  elsif ($type eq "PAIRWITHWINDOW") {

    @keywords = ("ptype", "pattern", "desc", "action", 
                 "ptype2", "pattern2", "desc2", "action2", "window");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!exists($ref->{"continue"})) { 
      $whatnext = DONTCONT; 
      $label = undef;
    } else { 
      ($whatnext, $label) =
        analyze_continue($ref->{"continue"}, $conffile, $lineno); 
    }

    if ($whatnext == INVALIDVALUE)  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    if (!analyze_actionlist($ref->{"action"}, \@action, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action"}, "'");
      return 0; 
    }

    if (!exists($ref->{"continue2"})) { 
      $whatnext2 = DONTCONT; 
      $label2 = undef;
    } else { 
      ($whatnext2, $label2) =
        analyze_continue($ref->{"continue2"}, $conffile, $lineno); 
    }

    if ($whatnext2 == INVALIDVALUE)  { return 0; }

    ($pattype2, $patlines2, $pattern2) = 
      analyze_pattern($ref->{"ptype2"}, $ref->{"pattern2"}, 
                      $conffile, $lineno, $pattype);

    if ($pattype2 == INVALIDVALUE)  { return 0; }

    if (!analyze_actionlist($ref->{"action2"}, \@action2, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action2"}, "'");
      return 0; 
    }

    if ($ref->{"window"} !~ /^0*(\d+)$/  ||  $1 == 0) { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid time window '", $ref->{"window"}, "'");
      return 0;
    } else { $ref->{"window"} = $1; }

    if (exists($ref->{"context"})) { 

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid 1st context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    if (exists($ref->{"context2"})) { 

      $contpreeval2 = check_context_preeval($ref->{"context2"});

      if (!analyze_context($ref->{"context2"}, \@context2)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid 2nd context specification '", $ref->{"context2"}, "'");
        return 0; 
      } 

    } else { @context2 = (); $contpreeval2 = 0; }

    $config->[$number] = { "ID" => $number, 
                           "Type" => PAIR_W_WINDOW, 
                           "WhatNext" => $whatnext, 
                           "GotoRule" => $label,
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines, 
                           "Context" => [ @context ],
                           "ContPreEval" => $contpreeval,
                           "Desc" => $ref->{"desc"}, 
                           "Action" => [ @action ],
                           "WhatNext2" => $whatnext2,
                           "GotoRule2" => $label2,
                           "PatType2" => $pattype2,
                           "Pattern2" => $pattern2,
                           "PatLines2" => $patlines2,
                           "Context2" => [ @context2 ],
                           "ContPreEval2" => $contpreeval2,
                           "Desc2" => $ref->{"desc2"},
                           "Action2" => [ @action2 ],
                           "Window" => $ref->{"window"},
                           "Operations" => {},
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };
    return 1;

  }

  # ------------------------------------------------------------
  # SINGLE_W_THRESHOLD rule
  # ------------------------------------------------------------

  elsif ($type eq "SINGLEWITHTHRESHOLD") {

    @keywords = ("ptype", "pattern", 
                 "desc", "action", "window", "thresh");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!exists($ref->{"continue"})) { 
      $whatnext = DONTCONT; 
      $label = undef;
    } else { 
      ($whatnext, $label) =
        analyze_continue($ref->{"continue"}, $conffile, $lineno); 
    }

    if ($whatnext == INVALIDVALUE)  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    if (!analyze_actionlist($ref->{"action"}, \@action, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action"}, "'");
      return 0; 
    }

    if (exists($ref->{"action2"})) {

      if (!analyze_actionlist($ref->{"action2"}, \@action2, 
                              $conffile, $lineno, $number)) {
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid action list '", $ref->{"action2"}, "'");
        return 0; 
      }

    } else { @action2 = (); }

    if ($ref->{"window"} !~ /^0*(\d+)$/  ||  $1 == 0) { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid time window '", $ref->{"window"}, "'");
      return 0;
    } else { $ref->{"window"} = $1; }

    if ($ref->{"thresh"} !~ /^0*(\d+)$/  ||  $1 == 0) { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid threshold '", $ref->{"thresh"}, "'");
      return 0;
    } else { $ref->{"thresh"} = $1; }

    if (exists($ref->{"context"})) { 

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    $config->[$number] = { "ID" => $number, 
                           "Type" => SINGLE_W_THRESHOLD, 
                           "WhatNext" => $whatnext, 
                           "GotoRule" => $label,
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines, 
                           "Context" => [ @context ],
                           "ContPreEval" => $contpreeval,
                           "Desc" => $ref->{"desc"}, 
                           "Action" => [ @action ],
                           "Action2" => [ @action2 ],
                           "Window" => $ref->{"window"},
                           "Threshold" => $ref->{"thresh"},
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };
    return 1;

  }

  # ------------------------------------------------------------
  # SINGLE_W_2_THRESHOLDS rule
  # ------------------------------------------------------------

  elsif ($type eq "SINGLEWITH2THRESHOLDS") {

    @keywords = ("ptype", "pattern", 
                 "desc", "action", "window", "thresh",
                 "desc2", "action2", "window2", "thresh2");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!exists($ref->{"continue"})) { 
      $whatnext = DONTCONT; 
      $label = undef;
    } else { 
      ($whatnext, $label) =
        analyze_continue($ref->{"continue"}, $conffile, $lineno); 
    }

    if ($whatnext == INVALIDVALUE)  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    if (!analyze_actionlist($ref->{"action"}, \@action, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action"}, "'");
      return 0; 
    }

    if ($ref->{"window"} !~ /^0*(\d+)$/  ||  $1 == 0) { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid 1st time window '", $ref->{"window"}, "'");
      return 0;
    } else { $ref->{"window"} = $1; }

    if ($ref->{"thresh"} !~ /^0*(\d+)$/  ||  $1 == 0) { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid 1st threshold '", $ref->{"thresh"}, "'");
      return 0;
    } else { $ref->{"thresh"} = $1; }

    if (!analyze_actionlist($ref->{"action2"}, \@action2, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action2"}, "'");
      return 0; 
    }

    if ($ref->{"window2"} !~ /^0*(\d+)$/  ||  $1 == 0) { 
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid 2nd time window '", $ref->{"window2"}, "'");
      return 0;
    } else { $ref->{"window2"} = $1; }

    if ($ref->{"thresh2"} =~ /^0*(\d+)$/) { $ref->{"thresh2"} = $1; }
    else {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid 2nd threshold '", $ref->{"thresh2"}, "'");
      return 0;
    }

    if (exists($ref->{"context"})) { 

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    $config->[$number] = { "ID" => $number, 
                           "Type" => SINGLE_W_2_THRESHOLDS, 
                           "WhatNext" => $whatnext, 
                           "GotoRule" => $label,
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines, 
                           "Context" => [ @context ],
                           "ContPreEval" => $contpreeval,
                           "Desc" => $ref->{"desc"}, 
                           "Action" => [ @action ],
                           "Window" => $ref->{"window"},
                           "Threshold" => $ref->{"thresh"},
                           "Desc2" => $ref->{"desc2"},
                           "Action2" => [ @action2 ],
                           "Window2" => $ref->{"window2"},
                           "Threshold2" => $ref->{"thresh2"},
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };
    return 1;

  }

  # ------------------------------------------------------------
  # SUPPRESS rule
  # ------------------------------------------------------------

  elsif ($type eq "SUPPRESS") {

    @keywords = ("ptype", "pattern");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    if (exists($ref->{"context"})) { 

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    if (!exists($ref->{"desc"})) {

      if ($pattype == REGEXP  ||  $pattype == SUBSTR
                              ||  $pattype == PERLFUNC) {
        $ref->{"desc"} = "Suppress rule with pattern: $pattern";
      } elsif ($pattype == NREGEXP  ||  $pattype == NSUBSTR
                                    ||  $pattype == NPERLFUNC) {
        $ref->{"desc"} = "Suppress rule with negative pattern: $pattern";
      } else {
        $ref->{"desc"} = 
        "Suppress rule with pattern: " . ($pattern?"TRUE":"FALSE");
      }

    }

    $config->[$number] = { "ID" => $number, 
                           "Type" => SUPPRESS, 
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines, 
                           "Context" => [ @context ],
                           "ContPreEval" => $contpreeval,
                           "Desc" => $ref->{"desc"},
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };
    return 1;

  }

  # ------------------------------------------------------------
  # CALENDAR rule
  # ------------------------------------------------------------

  elsif ($type eq "CALENDAR") {

    @keywords = ("time", "desc", "action");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!analyze_timespec($ref->{"time"}, \%minutes, \%hours, \%days, 
                 \%months, \%weekdays, $conffile, $lineno)) { return 0; }

    if (!analyze_actionlist($ref->{"action"}, \@action, 
                            $conffile, $lineno, $number)) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid action list '", $ref->{"action"}, "'");
      return 0; 
    }

    if (exists($ref->{"context"})) { 

      # since for Calendar rule []-operator has no meaning, 
      # just remove [] brackets if they exist

      check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); }

    $config->[$number] = { "ID" => $number, 
                           "Type" => CALENDAR,
                           "Minutes" => { %minutes },
                           "Hours" => { %hours },
                           "Days" => { %days },
                           "Months" => { %months },
                           "Weekdays" => { %weekdays },
                           "LastMinute" => 0,
                           "LastHour" => 0,
                           "LastDay" => 0, 
                           "LastMonth" => 0,
                           "LastWeekday" => 0,  
                           "Context" => [ @context ],
                           "Desc" => $ref->{"desc"},
                           "Action" => [ @action ], 
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };

    return 1;

  }

  # ------------------------------------------------------------
  # JUMP rule
  # ------------------------------------------------------------

  elsif ($type eq "JUMP") {

    @keywords = ("ptype", "pattern");

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    if (!exists($ref->{"continue"})) { 
      $whatnext = DONTCONT; 
      $label = undef;
    } else { 
      ($whatnext, $label) =
        analyze_continue($ref->{"continue"}, $conffile, $lineno); 
    }

    if ($whatnext == INVALIDVALUE)  { return 0; }

    ($pattype, $patlines, $pattern) = 
      analyze_pattern($ref->{"ptype"}, $ref->{"pattern"}, $conffile, $lineno);

    if ($pattype == INVALIDVALUE)  { return 0; }

    if (exists($ref->{"context"})) { 

      $contpreeval = check_context_preeval($ref->{"context"});

      if (!analyze_context($ref->{"context"}, \@context)) { 
        log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
                "Invalid context specification '", $ref->{"context"}, "'");
        return 0; 
      } 

    } else { @context = (); $contpreeval = 0; }

    if (!exists($ref->{"desc"})) {

      if ($pattype == REGEXP  ||  $pattype == SUBSTR
                              ||  $pattype == PERLFUNC) {
        $ref->{"desc"} = "Jump rule with pattern: $pattern";
      } elsif ($pattype == NREGEXP  ||  $pattype == NSUBSTR
                                    ||  $pattype == NPERLFUNC) {
        $ref->{"desc"} = "Jump rule with negative pattern: $pattern";
      } else {
        $ref->{"desc"} = 
        "Jump rule with pattern: " . ($pattern?"TRUE":"FALSE");
      }

    }

    if (exists($ref->{"constset"}) && $ref->{"constset"} !~ /^(YES|NO)$/i) {
      log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
              "Invalid constset value '", $ref->{"constset"}, "'");
      return 0; 
    } 

    $config->[$number] = { "ID" => $number, 
                           "Type" => JUMP, 
                           "WhatNext" => $whatnext, 
                           "GotoRule" => $label,
                           "PatType" => $pattype, 
                           "Pattern" => $pattern, 
                           "PatLines" => $patlines, 
                           "Context" => [ @context ],
                           "ContPreEval" => $contpreeval,
                           "Desc" => $ref->{"desc"},
                           "MatchCount" => 0, 
                           "LineNo" => $lineno };

    if (exists($ref->{"cfset"})) { 
      $config->[$number]->{"CFSet"} = [ split(' ', $ref->{"cfset"}) ]; 
    }

    if (!exists($ref->{"constset"}) || uc($ref->{"constset"}) eq "YES") { 
      $config->[$number]->{"ConstSet"} = 1; 
    }

    return 1;

  }

  # ------------------------------------------------------------
  # OPTIONS rule
  # ------------------------------------------------------------

  elsif ($type eq "OPTIONS") {

    @keywords = ();

    if (missing_keywords($ref, \@keywords, $type, 
                         $conffile, $lineno))  { return 0; }

    # discard any previous Options-rule

    $config_options{$conffile} = {};

    # parse and save the procallin value; assume default for invalid value

    if (exists($ref->{"procallin"})) { 
      if (uc($ref->{"procallin"}) eq "NO") {
        $config_options{$conffile}->{"JumpOnly"} = 1;
      } elsif (uc($ref->{"procallin"}) ne "YES") {
        log_msg(LOG_WARN, "Rule in $conffile at line $lineno:", 
                          "Invalid procallin value '", $ref->{"procallin"}, 
                          "', assuming procallin=Yes");
      }
    }

    # parse and save the list of set names

    if (exists($ref->{"joincfset"})) {
      $config_options{$conffile}->{"CFSet"} = {};
      foreach $cfset (split(' ', $ref->{"joincfset"})) {
        $config_options{$conffile}->{"CFSet"}->{$cfset} = 1;
      } 
    }

    return 2;

  }

  # ------------------------------------------------------------
  # end of rule processing
  # ------------------------------------------------------------

  log_msg(LOG_ERR, "Rule in $conffile at line $lineno:", 
          "Invalid rule type $type");
  return 0;

}


# Parameters: par1 - name of the configuration file
#             par2 - reference to the hash of label->rule conversion
# Action: process rules of configuration file par1, and resolve labels in
#         'continue=GoTo <label>' directives to rule numbers. The numbers
#         are stored into memory-based representation of rules. Note that
#         'continue=TakeNext' is treated as 'continue=GoTo <nextrule>'
#         (i.e., the number of the next rule is stored)

sub resolve_labels {

  my($conffile) = $_[0];
  my($label2rule) = $_[1];
  my($i, $n, $label, $id, $lineno);

  $n = scalar(@{$configuration{$conffile}});

  for ($i = 0; $i < $n; ++$i) {

    if (exists($configuration{$conffile}->[$i]->{"WhatNext"})) { 

      if ($configuration{$conffile}->[$i]->{"WhatNext"} == GOTO) {

        $label = $configuration{$conffile}->[$i]->{"GotoRule"};
        $lineno = $configuration{$conffile}->[$i]->{"LineNo"};

        if (exists($label2rule->{$label})) {

          $id = $label2rule->{$label};
          if ($id <= $i) {
            log_msg(LOG_WARN, "Rule in $conffile at line $lineno:",
            "can't go backwards to label $label, assuming continue=DontCont");
            $configuration{$conffile}->[$i]->{"WhatNext"} = DONTCONT;
          } else {
            $configuration{$conffile}->[$i]->{"GotoRule"} = $id;
          }

        } else {
          log_msg(LOG_WARN, "Rule in $conffile at line $lineno:",
            "label $label does not exist, assuming continue=DontCont");
          $configuration{$conffile}->[$i]->{"WhatNext"} = DONTCONT;
        }

      } elsif ($configuration{$conffile}->[$i]->{"WhatNext"} == TAKENEXT) {
        $configuration{$conffile}->[$i]->{"GotoRule"} = $i + 1;
      }
    }

    if (exists($configuration{$conffile}->[$i]->{"WhatNext2"})) { 

      if ($configuration{$conffile}->[$i]->{"WhatNext2"} == GOTO) {

        $label = $configuration{$conffile}->[$i]->{"GotoRule2"};
        $lineno = $configuration{$conffile}->[$i]->{"LineNo"};

        if (exists($label2rule->{$label})) {

          $id = $label2rule->{$label};
          if ($id <= $i) {
            log_msg(LOG_WARN, "Rule in $conffile at line $lineno:",
            "can't go backwards to label $label, assuming continue2=DontCont");
            $configuration{$conffile}->[$i]->{"WhatNext2"} = DONTCONT;
          } else {
            $configuration{$conffile}->[$i]->{"GotoRule2"} = $id;
          }

        } else {
          log_msg(LOG_WARN, "Rule in $conffile at line $lineno:",
            "label $label does not exist, assuming continue2=DontCont");
          $configuration{$conffile}->[$i]->{"WhatNext2"} = DONTCONT;
        }

      } elsif ($configuration{$conffile}->[$i]->{"WhatNext2"} == TAKENEXT) {
        $configuration{$conffile}->[$i]->{"GotoRule2"} = $i + 1;
      }
    }

  }
}


# Parameters: par1 - name of the configuration file
# Action: read in rules from configuration file par1, so that leading
#         and trailing whitespace is removed both from keywords and values
#         of rule definions, and then call check_rule() for every rule. 
#         if all rules in the file are correctly  defined, return 1, 
#         otherwise return 0

sub read_configfile {

  my($conffile) = $_[0];
  my($linebuf, $line, $i, $cont, $rulestart);
  my($keyword, $value, $ret, $file_status);
  my(%rule, %label2rule);

  $file_status = 1;   # start with the assumption that all rules 
                      # are correctly defined

  log_msg(LOG_NOTICE, "Reading configuration from $conffile");

  if (!open(CONFFILE, "$conffile")) {
    log_msg(LOG_ERR, "Can't open configuration file $conffile ($!)");
    return 0;
  }

  $i = 0;
  $cont = 0;
  %rule = ();
  $rulestart = 1;
  %label2rule = ();

  for (;;) {

    # read next line from file

    $linebuf = <CONFFILE>;

    # check if the line belongs to previous line; if it does, form a 
    # single line from them and start the loop again (i.e. we will
    # concatenate lines until we read a line that does not end with '\')

    if (defined($linebuf)) {
 
      chomp($linebuf);

      if ($cont)  { $line .= $linebuf; }  else { $line = $linebuf; }

      # remove whitespaces from line beginnings and ends;
      # if line is all-whitespace, set it to empty string

      if ($line =~ /^\s*(.*\S)/)  { $line = $1; }  else { $line = ""; }

      # check if line ends with '\'; if it does, remove '\', set $cont
      # to 1 and jump at the start of loop to read next line, otherwise 
      # set $cont to 0

      if (substr($line, length($line) - 1) eq '\\') { 
        chop($line);
        $cont = 1;
        next;
      } else { 
        $cont = 0; 
      } 

    }

    # if the line constructed during previous loop is empty, starting 
    # with #-symbol, or if we have reached EOF, consider that as the end 
    # of current rule. Check the rule and set $rulestart to the next line. 
    # If we have reached EOF, quit the loop, otherwise take the next line.

    if (!defined($linebuf) || !length($line) 
                           || index($line, '#') == 0) { 

      if (scalar(%rule)) { 
        $ret = check_rule(\%rule, $conffile, $rulestart, $i);
        if ($ret == 1) { ++$i; }
          elsif ($ret == 0) { $file_status = 0; }
        %rule = (); 
      }

      $rulestart = $. + 1;
 
      if (defined($linebuf))  { next; }  else { last; }

    }

    # split line into keyword and value

    if ($line =~ /^\s*([A-Za-z0-9]+)\s*=\s*(.*\S)/) {
      $keyword = $1;
      $value = $2;
    } else {
      log_msg(LOG_ERR, "$conffile line $. ($line):", 
              "Line not in keyword=value format or non-alphanumeric keyword");
      $file_status = 0;
      next;
    }

    # check if the keyword is valid

    if (!exists(CONFIG_KEYWORDS->{$keyword})) {
      log_msg(LOG_ERR, "$conffile line $.:", "Invalid keyword $keyword");
      $file_status = 0;
      next;
    }

    # if the keyword is "label", save the number of currently unfinished
    # or upcoming rule definition to the hash %label2rule;
    # otherwise save the keyword and value to the hash %rule

    if ($keyword eq "label") { $label2rule{$value} = $i; }
      else { $rule{$keyword} = $value; }

  }

  # if valid rules were loaded, resolve 'continue=GoTo' labels

  if ($i) {
    resolve_labels($conffile, \%label2rule);
    log_msg(LOG_DEBUG, "$i rules loaded from $conffile"); 
  } else {
    log_msg(LOG_WARN, "No valid rules found in configuration file $conffile");
  }

  close(CONFFILE);

  return $file_status;

}


# Parameters: -
# Action: evaluate the conffile patterns given in commandline, form the 
#         list of configuration files and save it to global array 
#         @conffiles, and read in rules from the configuration files;
#         also, create other global arrays for managing configuration

sub read_config {

  my($pattern, $conffile, $ret, $cfset);
  my(@stat, @rules, @files, %uniq);

  # Set the $lastconfigload variable to reflect the current time

  $lastconfigload = time();
  
  # Initialize global arrays %configuration, %config_ltimes, %config_mtimes,
  # %config_options, @calendar, @conffiles, %cfset2cfile, @maincfiles. 
  # The @conffiles array holds the names of _all_ configuration files; 
  # the members of @conffiles act as keys for the %configuration, 
  # %config_ltimes, %config_mtimes  and %config_options global hashes. 
  # The %cfset2cfile hash creates a mapping between config fileset names
  # and file names - for each set name there is a file name list.
  # The files with rules accepting all input are stored to @mainfiles.

  %configuration = ();
  %config_ltimes = ();
  %config_mtimes = ();
  %config_options = ();

  @calendar = ();
  @conffiles = ();

  %cfset2cfile = ();
  @maincfiles = ();

  # Form the list of configuration files and save it to @conffiles;
  # repeated occurrences of the same file are discarded from the list
 
  @files = ();
  foreach $pattern (@conffilepat)  { push @files, glob($pattern); }

  %uniq = ();
  @conffiles = grep(exists($uniq{$_})?0:($uniq{$_}=1), @files);

  # Read the configuration from rule files and store it to the global
  # array %configuration; also, store mtimes and options of rule files to 
  # the global arrays %config_mtimes and %config_options; save Calendar
  # rules to the global array Calendar and set the %cfset2cfile hash

  $ret = 1;

  foreach $conffile (@conffiles) {

    $configuration{$conffile} = [];
    $config_ltimes{$conffile} = $lastconfigload;

    @stat = stat($conffile);
    $config_mtimes{$conffile} = scalar(@stat)?$stat[9]:0;

    $config_options{$conffile} = {};
  
    if (!read_configfile($conffile))  { $ret = 0; }

    @rules = grep($_->{"Type"} == CALENDAR, @{$configuration{$conffile}}); 
    push @calendar, @rules;

    if (exists($config_options{$conffile}->{"CFSet"})) {
      while ($cfset = each (%{$config_options{$conffile}->{"CFSet"}})) {
        if (!exists($cfset2cfile{$cfset})) { $cfset2cfile{$cfset} = []; }
        push @{$cfset2cfile{$cfset}}, $conffile;
      }
    }

  }

  # Create the @maincfiles array - it holds the names of configuration
  # files that accept input from all sources, not from Jump rules only

  @maincfiles = grep(!exists($config_options{$_}->{"JumpOnly"}), @conffiles);

  return $ret;

}


# Parameters: par1 - reference to an array where the names of modified
#                    and removed configuration files will be stored
# Action: evaluate the conffile patterns given in commandline, form the 
#         list of configuration files and save it to global array 
#         @conffiles; read in rules from the configuration files that are
#         either new or have been modified since the last configuration 
#         load; also, create other global arrays for managing configuration.
#         As its output, the function stores to the array par1 the names 
#         of configuration files that have been modified or removed since
#         the last configuration load. 

sub soft_read_config {

  my($file_list) = $_[0];
  my($pattern, $conffile, $cfset);
  my(%old_config, %old_ltimes, %old_mtimes, %old_options);
  my(@old_conffiles, @stat, @rules, @files, %uniq);

  # Back up global arrays %configuration, %config_ltimes, %config_mtimes,
  # and @conffiles

  %old_config = %configuration;
  %old_ltimes = %config_ltimes;
  %old_mtimes = %config_mtimes;
  %old_options = %config_options;

  @old_conffiles = @conffiles;

  # Set the $lastconfigload variable to reflect the current time

  $lastconfigload = time();
  
  # Initialize global arrays %configuration, %config_ltimes, %config_mtimes,
  # %config_options, @calendar, @conffiles, %cfset2cfile, @maincfiles. 
  # The @conffiles array holds the names of _all_ configuration files; 
  # the members of @conffiles act as keys for the %configuration, 
  # %config_ltimes, %config_mtimes  and %config_options global hashes. 
  # The %cfset2cfile hash creates a mapping between config fileset names
  # and file names - for each set name there is a file name list.
  # The files with rules accepting all input are stored to @mainfiles.

  %configuration = ();
  %config_ltimes = ();
  %config_mtimes = ();
  %config_options = ();

  @calendar = ();
  @conffiles = ();

  %cfset2cfile = ();
  @maincfiles = ();

  # Form the list of configuration files and save it to @conffiles;
  # repeated occurrences of the same file are discarded from the list
 
  @files = ();
  foreach $pattern (@conffilepat)  { push @files, glob($pattern); }

  %uniq = ();
  @conffiles = grep(exists($uniq{$_})?0:($uniq{$_}=1), @files);

  # Read the configuration from rule files that are new or have been 
  # modified and store it to the global array %configuration; store mtimes
  # and options of rule files to the global arrays %config_mtimes and
  # %config_options; save Calendar rules to the global array Calendar and
  # set the %cfset2cfile hash.
  # Also, store the names of modified configuration files to the array par1

  @{$file_list} = ();

  foreach $conffile (@conffiles) {

    @stat = stat($conffile);
    $config_mtimes{$conffile} = scalar(@stat)?$stat[9]:0;

    if (!exists($old_config{$conffile})) { 

      $configuration{$conffile} = [];
      $config_options{$conffile} = {};
      read_configfile($conffile);
      $config_ltimes{$conffile} = $lastconfigload;

    } elsif ($old_mtimes{$conffile} != $config_mtimes{$conffile}) {

      $configuration{$conffile} = [];
      $config_options{$conffile} = {};
      read_configfile($conffile);
      $config_ltimes{$conffile} = $lastconfigload;

      push @{$file_list}, $conffile;

    } else { 

      $configuration{$conffile} = $old_config{$conffile}; 
      $config_options{$conffile} = $old_options{$conffile};
      $config_ltimes{$conffile} = $old_ltimes{$conffile};

    }

    @rules = grep($_->{"Type"} == CALENDAR, @{$configuration{$conffile}}); 
    push @calendar, @rules;

    if (exists($config_options{$conffile}->{"CFSet"})) {
      while ($cfset = each (%{$config_options{$conffile}->{"CFSet"}})) {
        if (!exists($cfset2cfile{$cfset})) { $cfset2cfile{$cfset} = []; }
        push @{$cfset2cfile{$cfset}}, $conffile;
      }
    }

  }

  # Create the @maincfiles array - it holds the names of configuration
  # files that accept input from all sources, not from Jump rules only

  @maincfiles = grep(!exists($config_options{$_}->{"JumpOnly"}), @conffiles);

  # Store the names of removed configuration files to the array par1

  push @{$file_list}, grep(!exists($configuration{$_}), @old_conffiles);

}


################################################
# Functions related to execution of action lists
################################################


# Parameters: par1 - string
#             par2 - string
# Action: all %-variables in string par1 will be replaced with their values

sub substitute_var {

  if (index($_[0], "%") == -1)  { return; }

  $variables{"u"} = time();
  $variables{"t"} = localtime($variables{"u"});
  $variables{"s"} = $_[1];
  $variables{"%"} = "%";

  # variable will not be substituted if it doesn't exist or its value is undef

  $_[0] =~ s/(\%\{([A-Za-z][A-Za-z0-9_]*)\}|
              \%([A-Za-z][A-Za-z0-9_]*|\%))/
              defined($variables{$+})?$variables{$+}:$1/egx;

}


# Parameters: par1 - shell command
#             par2 - 'collect output' flag
# Action: par1 will be executed as a shell command in a child
#         process. After process has been created, subroutine creates an
#         entry in the %children hash, and returns the pid of the child 
#         process. If process creation failed, undef is returned. After the 
#         command has completed, the child process terminates and returns 
#         command's exit code as its own exit value.
#         If par2 is defined and non-zero, command's standard output is
#         returned to the main process through a pipe.

sub shell_cmd {

  my($cmd) = $_[0];
  my($collect_output) = $_[1];
  my($pid);
  local *READ_FH;   # we need to use 'local *', since each time we enter
                    # this procedure a new filehandle must be created that
                    # will be returned from this procedure for external use

  # set up a pipe before calling fork()

  if ($collect_output && !pipe(READ_FH, WRITE_FH)) {
    log_msg(LOG_ERR, "Could not create pipe for command '$cmd' ($!)");
    return undef; 
  }

  # try to create a child process and return undef, if fork failed;
  # if fork was successful and we are in parent process, return the 
  # pid of the child process

  $pid = fork();

  if (!defined($pid)) { 

    if ($collect_output) { 
      close(READ_FH); 
      close(WRITE_FH); 
    }

    log_msg(LOG_ERR, "Could not fork command '$cmd' ($!)");
    return undef; 

  } elsif ($pid) { 

    $children{$pid} = { "cmd" => $cmd,
                        "fh" => undef,
                        "open" => 0,
                        "buffer" => "",
                        "Desc" => undef,
                        "Action" => undef,
                        "Action2" => undef };

    if ($collect_output) {
      close(WRITE_FH);
      $children{$pid}->{"fh"} = *READ_FH;
      $children{$pid}->{"open"} = 1;
    }

    log_msg(LOG_DEBUG, "Child $pid created for command '$cmd'");
    return $pid; 

  }

  # we are in the child process now...

  if ($collect_output) {

    # connect the standard output of the child process to the pipe
    # and make the standard output unbuffered

    close(READ_FH);

    if (!open(STDOUT, ">&WRITE_FH"))  { exit(1); }
    select(STDOUT); 
    $| = 1;

    close(WRITE_FH);

  }

  # if we have received SIGTERM, exit

  if ($terminate)  { exit(0); }

  # execute the command inside the child process; if exec() fails, exit

  exec("$cmd");
  exit(1);
  
}


# Parameters: par1 - shell command for reporting
#             par2 - reference to a hash or an array
# Action: par1 will be executed as a shell command in a child process, and
#         contents of array par2 (or keys of hash par2) are fed to its 
#         standard input. After process has been created, subroutine creates 
#         an entry in the %children hash, and returns the pid of the child 
#         process. If process creation failed, undef is returned. 
#         After the command has completed, the child process 
#         terminates and returns command's exit code as its own exit value.

sub pipe_cmd {

  my($cmd) = $_[0];
  my($ref) = $_[1];
  my($pid, $elem);

  # try to create a child process and return undef, if fork failed;
  # if fork was successful and we are in parent process, return the 
  # pid of the child process

  $pid = fork();

  if (!defined($pid)) { 

    log_msg(LOG_ERR, "Could not fork command '$cmd' ($!)");
    return undef; 

  } elsif ($pid) { 

    $children{$pid} = { "cmd" => $cmd,
                        "fh" => undef,
                        "open" => 0,
                        "buffer" => "",
                        "Desc" => undef,
                        "Action" => undef,
                        "Action2" => undef };

    log_msg(LOG_DEBUG, "Child $pid created for command '$cmd'");
    return $pid; 

  }

  # we are in the child process now...

  # if we have received SIGTERM, exit; otherwise fork the command

  if ($terminate)  { exit(0); }  else { $pid = open(CMDPIPE, "| $cmd"); }

  if (defined($pid)) {

    # if the main SEC process has sent us SIGTERM meanwhile, send SIGTERM 
    # to the command and exit; otherwise set the signal handler for SIGTERM

    if ($terminate) { 
      kill('TERM', $pid); 
      exit(0);
    } else { 
      $SIG{TERM} = sub { kill('TERM', $pid); exit(0); }; 
    }

    # ignore SIGPIPE if the command has died or has closed the pipe

    $SIG{PIPE} = 'IGNORE';

    # write data to pipe

    select CMDPIPE;
    $| = 1;

    if (ref($ref) eq "HASH") {
      while ($elem = each(%{$ref}))  { print CMDPIPE $elem, "\n"; }
    } else {
      foreach $elem (@{$ref})  { print CMDPIPE $elem, "\n"; }
    }

    # In some perl versions the close() function is buggy, and although
    # SIGPIPE is ignored, close() still sets $? variable to signal an 
    # error, if the forked command does not read its stdin. To overcome 
    # this problem, IO::Handle->flush() must be called before close(), 
    # since this forces the close() function to set $? correctly

    CMDPIPE->flush();

    # note that close() does not return until the command has completed

    close(CMDPIPE);

    exit($? >> 8);

  }

  exit(1); 

}


# Parameters: par1 - reference to a list of actions
#             par2 - event description text
#             par3 - pointer into the list of actions
# Action: execute an action from a given action list, and return
#         an offset for advancing the pointer par3

sub execute_none_action { return 1; }

sub execute_logonly_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($event);

  $event = $actionlist->[$i+1];
  substitute_var($event, $text);
  log_msg(LOG_NOTICE, $event); 

  return 2;
}

sub execute_write_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($file, $event, $nbytes);

  $file = $actionlist->[$i+1];
  $event = $actionlist->[$i+2];

  substitute_var($file, $text);
  substitute_var($event, $text);

  log_msg(LOG_DEBUG, "Writing event '$event' to file $file");

  if ($file eq "-") {

    select(STDOUT); 
    $| = 1;
    print STDOUT "$event\n";

  } elsif (-e $file  &&  ! -f $file  &&  ! -p $file) {

    log_msg(LOG_WARN, "Can't write event '$event' to file $file!", 
            "(not a regular file or pipe)");

  } elsif (-p $file) {

    if (sysopen(WRITEFILE, $file, O_WRONLY | O_NONBLOCK)) {

      $nbytes = syswrite(WRITEFILE, "$event\n");
      close(WRITEFILE);

      if (!defined($nbytes)  ||  $nbytes != length($event) + 1) {
        log_msg(LOG_WARN,
                "Error when writing event '$event' to pipe $file!");
      }

    } else {
      log_msg(LOG_WARN,
              "Can't open pipe $file for writing event '$event'!");
    }

  } else {

    if (open(WRITEFILE, ">>$file")) {
      print WRITEFILE "$event\n";
      close(WRITEFILE);
    } else {
      log_msg(LOG_WARN,
              "Can't open file $file for writing event '$event'!");
    }

  }

  return 3;
}

sub execute_shellcmd_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($cmdline, $text2);

  $cmdline = $actionlist->[$i+1];
  $text2 = $text;

  # if -quoting flag was specified, mask apostrophes in $text2 
  # and put $text2 inside apostrophes

  if ($quoting) { 
    $text2 =~ s/'/'\\''/g;
    $text2 = "'" . $text2 . "'"; 
  }

  substitute_var($cmdline, $text2);

  log_msg(LOG_INFO, "Executing shell command '$cmdline'");

  shell_cmd($cmdline);

  return 2;
}

sub execute_spawn_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($cmdline, $text2);

  $cmdline = $actionlist->[$i+1];
  $text2 = $text;

  # if -quoting flag was specified, mask apostrophes in $text2 
  # and put $text2 inside apostrophes

  if ($quoting) { 
    $text2 =~ s/'/'\\''/g;
    $text2 = "'" . $text2 . "'"; 
  }

  substitute_var($cmdline, $text2);

  log_msg(LOG_INFO, "Spawning shell command '$cmdline'");

  shell_cmd($cmdline, 1);

  return 2;
}

sub execute_pipe_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($event, $cmdline);

  $event = $actionlist->[$i+1];
  $cmdline = $actionlist->[$i+2];

  substitute_var($event, $text);
  substitute_var($cmdline, $text);

  log_msg(LOG_INFO, "Feeding event '$event' to shell command '$cmdline'");

  if (length($cmdline)) { 
    pipe_cmd($cmdline, [ $event ]); 
  } else {
    select(STDOUT); 
    $| = 1;
    print STDOUT "$event\n";
  }

  return 3;
}

sub execute_create_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, $lifetime, $list);

  $context = $actionlist->[$i+1];
  $lifetime = $actionlist->[$i+2];
  $list = $actionlist->[$i+3];

  substitute_var($context, $text);
  substitute_var($lifetime, $text);

  log_msg(LOG_DEBUG, "Creating context '$context'");

  if ($lifetime =~ /^\s*0*(\d+)\s*$/) {

    $lifetime = $1;

    if (exists($context_list{$context})) {

      $context_list{$context}->{"Time"} = time();
      $context_list{$context}->{"Window"} = $lifetime;
      $context_list{$context}->{"Buffer"} = [];
      $context_list{$context}->{"Action"} = $list;
      $context_list{$context}->{"Desc"} = $text;
        
    } else {

      $context_list{$context} = { "Time" => time(), 
                                  "Window" => $lifetime, 
                                  "Buffer" => [],
                                  "Action" => $list,
                                  "Desc" => $text,
                                  "Aliases" => [ $context ] };

    }

  } else {
    log_msg(LOG_WARN,
    "Invalid lifetime '$lifetime' for context '$context', can't create");
  }

  return 4;
}

sub execute_delete_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, @aliases, $alias);

  $context = $actionlist->[$i+1];
  substitute_var($context, $text);

  log_msg(LOG_DEBUG, "Deleting context '$context'");

  if (exists($context_list{$context})  &&
      !exists($context_list{$context}->{"DeleteInProgress"})) {

    @aliases = @{$context_list{$context}->{"Aliases"}};

    foreach $alias (@aliases) { 
      delete $context_list{$alias};
      log_msg(LOG_DEBUG, "Context '$alias' deleted"); 
    }

  } else {
    log_msg(LOG_WARN,
            "Context '$context' does not exist or is going through deletion, can't delete");
  }

  return 2;
}

sub execute_obsolete_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context);

  $context = $actionlist->[$i+1];
  substitute_var($context, $text);

  log_msg(LOG_DEBUG, "Obsoleting context '$context'");

  if (exists($context_list{$context})  &&
      !exists($context_list{$context}->{"DeleteInProgress"})) {

    $context_list{$context}->{"Window"} = -1;
    valid_context($context);

  } else {
    log_msg(LOG_WARN,
            "Context '$context' does not exist or is going through deletion, can't obsolete");
  }

  return 2;
}

sub execute_set_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, $lifetime, $list);

  $context = $actionlist->[$i+1];
  $lifetime = $actionlist->[$i+2];
  $list = $actionlist->[$i+3];

  substitute_var($context, $text);
  substitute_var($lifetime, $text);

  log_msg(LOG_DEBUG, "Changing settings for context '$context'");

  if ($lifetime =~ /^\s*0*(\d+)\s*$/) {

    $lifetime = $1;

    if (exists($context_list{$context})) {

      $context_list{$context}->{"Time"} = time();
      $context_list{$context}->{"Window"} = $lifetime;

      if (scalar(@{$list})) {
        $context_list{$context}->{"Action"} = $list;
        $context_list{$context}->{"Desc"} = $text;
      }

    } else {
      log_msg(LOG_WARN,
              "Context '$context' does not exist, can't change settings");
    }

  } else {
    log_msg(LOG_WARN,
    "Invalid lifetime '$lifetime' for context '$context', can't change settings");
  }

  return 4;
}

sub execute_alias_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, $alias);

  $context = $actionlist->[$i+1];
  $alias = $actionlist->[$i+2];

  substitute_var($context, $text);
  substitute_var($alias, $text);

  log_msg(LOG_DEBUG, "Creating alias '$alias' for context '$context'");

  if (!exists($context_list{$context})) { 
    log_msg(LOG_WARN, 
            "Context '$context' does not exist, can't create alias");
  } elsif (exists($context_list{$alias})) {
    log_msg(LOG_WARN, "Alias '$alias' already exists");
  } else {
    push @{$context_list{$context}->{"Aliases"}}, $alias;
    $context_list{$alias} = $context_list{$context};
  }

  return 3;
}

sub execute_unalias_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($alias, @aliases);

  $alias = $actionlist->[$i+1];
  substitute_var($alias, $text);

  log_msg(LOG_DEBUG, "Removing alias '$alias'");

  if (exists($context_list{$alias})  &&
      !exists($context_list{$alias}->{"DeleteInProgress"})) {

    @aliases = grep($_ ne $alias, @{$context_list{$alias}->{"Aliases"}});

    if (scalar(@aliases)) {
      $context_list{$alias}->{"Aliases"} = [ @aliases ];
    } else {
      log_msg(LOG_DEBUG,
              "Alias '$alias' was the last reference to a context");
    }

    delete $context_list{$alias};

  } else {
    log_msg(LOG_WARN,
            "Alias '$alias' does not exist or its context is going through deletion, can't remove");
  }

  return 2;
}

sub execute_add_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, $event, @event);

  $context = $actionlist->[$i+1];
  $event = $actionlist->[$i+2];

  substitute_var($context, $text);
  substitute_var($event, $text);

  log_msg(LOG_DEBUG, "Adding event '$event' to context '$context'");

  if (!exists($context_list{$context})) { 

    $context_list{$context} = { "Time" => time(), 
                                "Window" => 0, 
                                "Buffer" => [],
                                "Action" => [],
                                "Desc" => "",
                                "Aliases" => [ $context ] };
  }

  @event = split(/\n/, $event);

  if (!$evstoresize  ||  scalar(@{$context_list{$context}->{"Buffer"}}) 
                       + scalar(@event) <= $evstoresize) {
    push @{$context_list{$context}->{"Buffer"}}, @event;
  } else {
    log_msg(LOG_WARN,
            "Can't add event '$event' to context '$context', store full");
  }

  return 3;
}

sub execute_fill_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, $event, @event);

  $context = $actionlist->[$i+1];
  $event = $actionlist->[$i+2];

  substitute_var($context, $text);
  substitute_var($event, $text);

  log_msg(LOG_DEBUG, "Filling context '$context' with event '$event'");

  if (!exists($context_list{$context})) { 

    $context_list{$context} = { "Time" => time(), 
                                "Window" => 0, 
                                "Buffer" => [],
                                "Action" => [],
                                "Desc" => "",
                                "Aliases" => [ $context ] };
  }

  @event = split(/\n/, $event);

  if (!$evstoresize  ||  scalar(@event) <= $evstoresize) {
    $context_list{$context}->{"Buffer"} = [ @event ];
  } else {
    log_msg(LOG_WARN,
            "Can't fill context '$context' with event '$event', store full");
  }

  return 3;
}

sub execute_report_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, $cmdline, $event);

  $context = $actionlist->[$i+1];
  $cmdline = $actionlist->[$i+2];

  substitute_var($context, $text);
  substitute_var($cmdline, $text);

  log_msg(LOG_INFO,
          "Reporting the event store of context '$context' through shell command '$cmdline'");

  if (!exists($context_list{$context})) {
    log_msg(LOG_WARN, "Context '$context' does not exist, can't report");
  } elsif (!scalar(@{$context_list{$context}->{"Buffer"}})) {
    log_msg(LOG_WARN,
            "Event store of context '$context' is empty, can't report");
  } else {

    if (length($cmdline)) {
      pipe_cmd($cmdline, $context_list{$context}->{"Buffer"});
    } else {
      select(STDOUT); 
      $| = 1;
      foreach $event (@{$context_list{$context}->{"Buffer"}}) {
        print STDOUT "$event\n"; 
      }
    }

  }

  return 3;
}

sub execute_copy_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, $variable, $value);

  $context = $actionlist->[$i+1];
  $variable = $actionlist->[$i+2];

  substitute_var($context, $text);

  log_msg(LOG_DEBUG,
          "Copying context '$context' to variable '%$variable'");

  if (exists($context_list{$context})) { 

    $value = join("\n", @{$context_list{$context}->{"Buffer"}});
    $variables{$variable} = $value;
    log_msg(LOG_DEBUG, "Variable '%$variable' set to '$value'");

  } else {
    log_msg(LOG_WARN, "Context '$context' does not exist, can't copy");
  }

  return 3;
}

sub execute_empty_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($context, $variable, $value);

  $context = $actionlist->[$i+1];
  $variable = $actionlist->[$i+2];

  substitute_var($context, $text);

  log_msg(LOG_DEBUG, "Emptying the event store of context '$context'");

  if (exists($context_list{$context})) { 

    if (length($variable)) {
      $value = join("\n", @{$context_list{$context}->{"Buffer"}});
      $variables{$variable} = $value;
      log_msg(LOG_DEBUG, "Variable '%$variable' set to '$value'");
    }

    $context_list{$context}->{"Buffer"} = [];

  } else {
    log_msg(LOG_WARN, "Context '$context' does not exist, can't empty");
  }

  return 3;
}

sub execute_event_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($createafter, $event, @event);

  $createafter = $actionlist->[$i+1];
  $event = $actionlist->[$i+2];

  substitute_var($event, $text);

  @event = split(/\n/, $event);

  if ($createafter) {
    foreach $event (@event) {
      push @pending_events, [ time() + $createafter, $event ]; 
    }
  } else {
    log_msg(LOG_DEBUG, "Creating event '$event'");
    push @events, @event;
  }

  return 3;
}

sub execute_tevent_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($createafter, $event, @event);

  $createafter = $actionlist->[$i+1];
  $event = $actionlist->[$i+2];

  substitute_var($createafter, $text);
  substitute_var($event, $text);

  @event = split(/\n/, $event);

  if ($createafter =~ /^\s*0*(\d+)\s*$/) {

    $createafter = $1;

    if ($createafter) {
      foreach $event (@event) {
        push @pending_events, [ time() + $createafter, $event ]; 
      }
    } else {
      log_msg(LOG_DEBUG, "Creating event '$event'");
      push @events, @event;
    }

  } else {
    log_msg(LOG_WARN,
    "Can't create event '$event' after '$createafter' seconds");
  }

  return 3;
}

sub execute_reset_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($conffile, $ruleid, $event);
  my($key, $ref);

  $conffile = $actionlist->[$i+1];
  $ruleid = $actionlist->[$i+2];
  $event = $actionlist->[$i+3];

  substitute_var($event, $text);

  if (length($ruleid)) {

    $key = gen_key($conffile, $ruleid, $event);
 
    log_msg(LOG_DEBUG,
            "Cancelling event correlation operation with key '$key'");

    $ref = $configuration{$conffile}->[$ruleid];

    if (exists($ref->{"Operations"})) { 
      delete $ref->{"Operations"}->{$key}; 
    }
    delete $corr_list{$key};

  } else {

    log_msg(LOG_DEBUG,
            "Cancelling all event correlation operations started from",
            $conffile, "for detecting composite event '$event'");

    foreach $ref (@{$configuration{$conffile}}) {

      $key = gen_key($conffile, $ref->{"ID"}, $event);

      if (exists($ref->{"Operations"})) { 
        delete $ref->{"Operations"}->{$key}; 
      }
      delete $corr_list{$key};

    }
  }

  return 4;
}

sub execute_assign_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($variable, $value);

  $variable = $actionlist->[$i+1];
  $value = $actionlist->[$i+2];

  substitute_var($value, $text);

  log_msg(LOG_DEBUG, "Assigning '$value' to variable '%$variable'");

  $variables{$variable} = $value;

  return 3;
}

sub execute_eval_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($variable, $code);
  my(@retval, $evalok, $value);

  $variable = $actionlist->[$i+1];
  $code = $actionlist->[$i+2];

  substitute_var($code, $text);

  log_msg(LOG_DEBUG,
          "Evaluating code '$code' and setting variable '%$variable'");

  @retval = SEC::call_eval($code, 1);
  $evalok = shift @retval;
  foreach $value (@retval)  { if (!defined($value)) { $value = ""; } }

  if ($evalok) {

    if (scalar(@retval) > 1) { 
      $value = join("\n", @retval);
      $variables{$variable} = $value;
      log_msg(LOG_DEBUG, "Variable '%$variable' set to '$value'");
    } elsif (scalar(@retval) == 1) {
      # this check is needed for cases when 'eval' returns a code reference,
      # because join() converts it to a string and 'call' actions will fail
      $variables{$variable} = $retval[0];
      log_msg(LOG_DEBUG, "Variable '%$variable' set to '$retval[0]'");
    } else {
      log_msg(LOG_DEBUG, "No value received for variable '%$variable'");
    }

  } else {
    log_msg(LOG_ERR, "Error evaluating code '$code':", $retval[0]);
  }

  return 3;
}

sub execute_call_action {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i) = $_[2];
  my($variable, $code, @params);
  my($value, @retval);

  $variable = $actionlist->[$i+1];
  $code = $actionlist->[$i+2];
  @params = @{$actionlist->[$i+3]};

  log_msg(LOG_DEBUG,
          "Calling code '%$code->()' and setting variable '%$variable'");

  if (ref($variables{$code}) eq "CODE") {

    foreach $value (@params)  { substitute_var($value, $text); }
    @retval = eval { $variables{$code}->(@params) };
    foreach $value (@retval)  { if (!defined($value)) { $value = ""; } }

    if ($@) {
      log_msg(LOG_ERR, "Code '%$code->()' runtime error:", $@);
    } else {
        
      if (scalar(@retval)) { 
        $value = join("\n", @retval);
        $variables{$variable} = $value;
        log_msg(LOG_DEBUG, "Variable '%$variable' set to '$value'");
      } else {
        log_msg(LOG_DEBUG, "No value received for variable '%$variable'");
      }

    }
        
  } else {
    log_msg(LOG_WARN, "Variable '%$code' is not a code reference");
  }

  return 4;
}


# Parameters: par1 - reference to a list of actions
#             par2 - event description text
# Action: execute actions in a given action list

sub execute_actionlist {

  my($actionlist) = $_[0];
  my($text) = $_[1];
  my($i, $j);

  $i = 0;
  $j = scalar(@{$actionlist});

  while ($i < $j) {
    $i += $execactionfunc[$actionlist->[$i]]->($actionlist, $text, $i);
  } 

}


#####################################################
# Functions related to processing of lists at runtime
#####################################################


# Parameters: par1 - context
# Action: check if context "par1" is valid at the moment and return 1
#         if it is, otherwise return 0. If context "par1" is found to
#         be stale but is still present in the context list, it will be
#         removed from there, and if it has an action list, the action
#         list will be executed.

sub valid_context {

  my($context) = $_[0];
  my($ref, $alias, @aliases);

  if (exists($context_list{$context})) {

    # if the context has infinite lifetime or if its lifetime is not
    # exceeded, it is valid (TRUE) and return 1

    if (!$context_list{$context}->{"Window"})  { return 1; }

    if (time() - $context_list{$context}->{"Time"}
          <= $context_list{$context}->{"Window"})  { return 1; }

    # if the valid_context was called recursively and action-list-on-expire
    # is currently executing, the context is considered stale and return 0

    if (exists($context_list{$context}->{"DeleteInProgress"}))  { return 0; }

    log_msg(LOG_DEBUG, "Deleting stale context '$context'");

    # if the context is stale and its action-list-on-expire has not been
    # executed yet, execute it now

    if (scalar(@{$context_list{$context}->{"Action"}})) {

      # DeleteInProgress flag indicates that the action list execution is
      # in progress. The flag is used for two purposes:
      # 1) if this function is called recursively for the context, the flag 
      #    prevents the action-list-on-expire from being executed again,
      # 2) the flag will temporarily disable all actions that remove either
      #    the context or any of its names (delete, obsolete, unalias) until 
      #    the action-list-on-expire has completed

      $context_list{$context}->{"DeleteInProgress"} = 1;

      # if context name _THIS exists, the action list execution was triggered
      # by the action-list-on-expire of another context that is currently 
      # referred by _THIS, therefore save the current value of _THIS
      
      if (exists($context_list{"_THIS"})) { $ref = $context_list{"_THIS"}; }
        else { $ref = undef; }

      # set _THIS to refer to the current context

      $context_list{"_THIS"} = $context_list{$context};

      # execute the action-list-on-expire

      execute_actionlist($context_list{$context}->{"Action"},
                         $context_list{$context}->{"Desc"});

      # if context name _THIS was referring to another context previously, 
      # restore the previous value, otherwise delete _THIS

      if (defined($ref)) { $context_list{"_THIS"} = $ref; }
        else { delete $context_list{"_THIS"}; }

    }

    # remove all names of the context from the list of contexts

    @aliases = @{$context_list{$context}->{"Aliases"}};

    foreach $alias (@aliases) { 
      delete $context_list{$alias};
      log_msg(LOG_DEBUG, "Stale context '$alias' deleted");
    }

  }

  return 0;

}


# Parameters: par1 - reference to a context expression
# Action: calculate the truth value of the context expression par1;
#         return 1 if it is TRUE, and return 0 if it is FALSE.

sub tval_context_expr {

  my($ref) = $_[0];
  my($i, $j, $left, @right);
  my($evalresult, $evalok, $retval);
  my($code, $func, $args);

  $i = 0;
  $j = scalar(@{$ref});
  $left = undef;
  @right = ();

  while ($i < $j) {

    if ($ref->[$i] == OPERAND) {

      if (defined($left)) {
        push @right, OPERAND;
        push @right, $ref->[$i+1];
      } else { 
        $left = valid_context($ref->[$i+1]); 
      }

      $i += 2;

    }

    elsif ($ref->[$i] == NEGATION) {

      # if the second operand is present, negation belongs to it,
      # otherwise negate the value of the first operand

      if (scalar(@right)) {
        push @right, NEGATION;
      } else {
        $left = $left?0:1;
      }

      ++$i;

    }

    elsif ($ref->[$i] == AND) {

      # the && operator has the short-circuiting capability and returns 
      # the value of the last evaluated operand which is either 0 or 1

      $left = $left && tval_context_expr(\@right);
      @right = ();

      ++$i;

    }

    elsif ($ref->[$i] == OR) {

      # the || operator has the short-circuiting capability and returns 
      # the value of the last evaluated operand which is either 0 or 1

      $left = $left || tval_context_expr(\@right);
      @right = ();

      ++$i;

    }

    elsif ($ref->[$i] == EXPRESSION) {

      if (defined($left)) {
        push @right, EXPRESSION;
        push @right, $ref->[$i+1];
      } else { 
        $left = tval_context_expr($ref->[$i+1]); 
      }

      $i += 2;

    }

    elsif ($ref->[$i] == ECODE) {

      if (defined($left)) {

        push @right, ECODE;
        push @right, $ref->[$i+1];

      } else {

        # if eval() for $code failed or returned false in boolean context
        # (undef, "", or 0), set $left to 0, otherwise set $left to 1

        $code = $ref->[$i+1];
        ($evalok, $evalresult) = SEC::call_eval($code, 0);

        if (!$evalok) {
          log_msg(LOG_ERR, "Error evaluating code '$code': $evalresult");
          $left = 0;
        } else { 
          $left = $evalresult?1:0; 
        }

      }

      $i += 2;

    }

    elsif ($ref->[$i] == CCODE) {

      if (defined($left)) {

        push @right, CCODE;
        push @right, $ref->[$i+1];
        push @right, $ref->[$i+2];

      } else {

        $args = $ref->[$i+1];
        $func = $ref->[$i+2];

        # don't call $func->($args), since the tval_context_expr() function
        # could be called for the original context expression definition
        # (e.g., if the rule type is Calendar or if the context expression
        # is in []-brackets), and passing $args to the end user would allow 
        # the user to modify the original context definition

        $retval = eval { $func->( ( @{$args} ) ) };
      
        # if function call failed or returned false in boolean context
        # (undef, "", or 0), set $left to 0, otherwise set $left to 1

        if ($@) {
          log_msg(LOG_ERR, "Context expression runtime error:", $@);
          $left = 0;
        } else { 
          $left = $retval?1:0; 
        }
      
      }

      $i += 3;

    }

  }

  return $left;

}


# Parameters: par1 - number of lines that pattern was designed to match (1)
#             par2 - pattern (truth value)
#             par3 - backreference array (will be emptied)
# Action: return par2 and set par3 to an empty array

sub match_tvalue {

  my($tvalue) = $_[1];
  my($subst_ref) = $_[2];

  @{$subst_ref} = ();
  return $tvalue;

}


# Parameters: par1 - number of lines that pattern was designed to match
#             par2 - pattern (string type)
#             par3 - backreference array (will be emptied)
# Action: take par1 last lines from input buffer and concatenate them to 
#         form a single string. Check if par2 is a substring in the formed
#         string (both par1 and par2 can contain newlines), and return 1 
#         if it is, otherwise return 0.

sub match_substr {

  my($linecount) = $_[0];
  my($substr) = $_[1];
  my($subst_ref) = $_[2];
  my($line);

  @{$subst_ref} = ();
  $line = join("\n", @input_buffer[$bufpos - $linecount + 1 .. $bufpos]);
  return (index($line, $substr) != -1);

}


# Parameters: par1 - number of lines that pattern was designed to match
#             par2 - pattern (regular expression type)
#             par3 - reference to an array, where backreference values 
#                    $1, $2, .. will be saved. First element of an array will 
#                    be $0 that equals to line(s) that were found matching
# Action: take par1 last lines from input buffer and concatenate them to 
#         form a single string. Match the formed string with regular 
#         expression par2, and if par2 contains bracketing constructs,
#         save backreference values $1, $2, .. to array par3. If formed 
#         string matched regular expression, return 1, otherwise return 0

sub match_regexp {

  my($linecount) = $_[0];
  my($regexp) = $_[1];
  my($subst_ref) = $_[2];
  my($line);

  $line = join("\n", @input_buffer[$bufpos - $linecount + 1 .. $bufpos]);

  if (@{$subst_ref} = ($line =~ /$regexp/)) { 
    unshift @{$subst_ref}, $line;   # create $0 that equals to $line
    return 1; 
  } else { 
    @{$subst_ref} = ( $line );   # create $0 that equals to $line
    return 0; 
  }

}


# Parameters: par1 - number of lines that pattern was designed to match
#             par2 - pattern (perl function type)
#             par3 - reference to an array, where return values 
#                    $1, $2, .. will be saved. First element of an array will 
#                    be $0 that equals to line(s) that were found matching
# Action: take par1 last lines from input buffer with corresponding source
#         names, and pass them to the perl function par2->().
#         If the function returned value(s), save them as values $1, $2, ..
#         to array par3. If function returned an empty list or returned
#         a single value FALSE, return 0, otherwise return 1

sub match_perlfunc {

  my($linecount) = $_[0];
  my($codeptr) = $_[1];
  my($subst_ref) = $_[2];
  my($line, @lines, @sources);
  my($size, $match);

  $line = join("\n", @input_buffer[$bufpos - $linecount + 1 .. $bufpos]);
  @lines = @input_buffer[$bufpos - $linecount + 1 .. $bufpos];
  @sources = @input_sources[$bufpos - $linecount + 1 .. $bufpos];

  @{$subst_ref} = eval { $codeptr->(@lines, @sources) };

  if ($@) {
    log_msg(LOG_ERR, "(N)PerlFunc pattern runtime error:", $@);
    @{$subst_ref} = ();
  }
                               
  $size = scalar(@{$subst_ref});
  $match = $size > 1  ||  ($size == 1  &&  $subst_ref->[0]);

  unshift @{$subst_ref}, $line;   # create $0 that equals to $line
  return $match; 

}


# Parameters: par1 - reference to a source action list
#             par2 - reference to a destination action list
#             par3 - pointer into the source and destination list
# Action: action from list par1 will be copied to par2; the function
#         will return an offset for advancing the pointer par3

sub copy_one_elem_action {

  my($src_ref) = $_[0];
  my($dest_ref) = $_[1];
  my($i) = $_[2];

  push @{$dest_ref}, $src_ref->[$i];
  return 1; 
}

sub copy_two_elem_action {

  my($src_ref) = $_[0];
  my($dest_ref) = $_[1];
  my($i) = $_[2];

  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i];
  return 2; 
}

sub copy_three_elem_action {

  my($src_ref) = $_[0];
  my($dest_ref) = $_[1];
  my($i) = $_[2];

  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i];
  return 3; 
}

sub copy_four_elem_action {

  my($src_ref) = $_[0];
  my($dest_ref) = $_[1];
  my($i) = $_[2];

  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i];
  return 4; 
}

sub copy_create_set_action {

  my($src_ref) = $_[0];
  my($dest_ref) = $_[1];
  my($i) = $_[2];

  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, [];
  copy_actionlist($src_ref->[$i], $dest_ref->[$i]);
  return 4;
}

sub copy_call_action {

  my($src_ref) = $_[0];
  my($dest_ref) = $_[1];
  my($i) = $_[2];

  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, $src_ref->[$i++];
  push @{$dest_ref}, [ @{$src_ref->[$i]} ];
  return 4; 
}


# Parameters: par1 - reference to a source action list
#             par2 - reference to a destination action list
# Action: action list par1 will be copied to par2

sub copy_actionlist {

  my($src_ref) = $_[0];
  my($dest_ref) = $_[1];
  my($i, $j);

  @{$dest_ref} = ();
  $i = 0;
  $j = scalar(@{$src_ref});

  while ($i < $j) {
    $i += $actioncopyfunc[$src_ref->[$i]]->($src_ref, $dest_ref, $i);
  }

}


# Parameters: par1 - reference to a source context
#             par2 - reference to a destination context
# Action: context par1 will be copied to par2

sub copy_context {

  my($src_ref) = $_[0];
  my($dest_ref) = $_[1];
  my($i, $j);

  @{$dest_ref} = ();
  $i = 0;
  $j = scalar(@{$src_ref});

  while ($i < $j) {

    if ($src_ref->[$i] == OPERAND) {
      push @{$dest_ref}, OPERAND;
      push @{$dest_ref}, $src_ref->[$i+1];
      $i += 2;
    } 

    elsif ($src_ref->[$i] == EXPRESSION) {
      push @{$dest_ref}, EXPRESSION;
      push @{$dest_ref}, [];
      copy_context($src_ref->[$i+1], $dest_ref->[$i+1]);
      $i += 2;
    }

    elsif ($src_ref->[$i] == ECODE) {
      push @{$dest_ref}, ECODE;
      push @{$dest_ref}, $src_ref->[$i+1];
      $i += 2;
    } 

    elsif ($src_ref->[$i] == CCODE) {
      push @{$dest_ref}, CCODE;
      push @{$dest_ref}, [ @{$src_ref->[$i+1]} ];
      push @{$dest_ref}, $src_ref->[$i+2];
      $i += 3;
    } 

    else { 
      push @{$dest_ref}, $src_ref->[$i];
      ++$i; 
    }

  }

}


# Parameters: par1 - reference to the array of replacements
#             par2, par3, .. - strings that will go through replacement
#             procedure
#             par n - token that special variables start with
# Action: Strings par2, par3, .. will be searched for special variables
#         (like $0, $1, $2, ..) that will be replaced with 1st, 2nd, .. 
#         element from array par1. If the token symbol is followed by
#         another token symbol, they will be replaced by a single token 
#         (e.g., $$ -> $).

sub subst_string {

  my($subst_ref) = shift @_;
  my($token) = pop @_;
  my($token2, $msg);

  # variable will not be substituted if it doesn't exist or its value is undef

  $token2 = quotemeta($token);

  foreach $msg (@_) {
    if (index($msg, $token) == -1)  { next; }
    $msg =~ s/$token2(\d+|$token2)/
              ($1 eq $token)?$token:
              (defined($subst_ref->[$1])?$subst_ref->[$1]:"$token$1")/egx;
  }

}


# Parameters: par1 - reference to the array of replacements
#             par2, par3, .. - regular expressions that will go through 
#             replacement procedure
#             par n - token that special variables start with
# Action: Regular expressions par2, par3, .. will be searched for special 
#         variables (like $1, $2, ..) that will be replaced with 1st, 
#         2nd, .. element from array par1 

sub subst_regexp {

  my($subst_ref) = shift @_;
  my($token) = pop @_;
  my($subst, @subst_modified);

  @subst_modified = @{$subst_ref};

  foreach $subst (@subst_modified) { 
    if (defined($subst))  { $subst = quotemeta($subst); }
  }

  subst_string(\@subst_modified, @_, $token);

}


# Parameters: par1 - reference to the array of replacements
#             par2 - reference to a context formula
#             par3 - token that special variables start with
# Action: Context formula par2 will be searched for special variables
#         (like $1, $2, ..) that will be replaced with 1st, 2nd, .. element
#         from array par1 

sub subst_context {

  my($subst_ref) = $_[0];
  my($ref) = $_[1];
  my($token) = $_[2];
  my($i, $j);

  $i = 0;
  $j = scalar(@{$ref});

  while ($i < $j) {

    if ($ref->[$i] == OPERAND) {
      subst_string($subst_ref, $ref->[$i+1], $token);
      $i += 2;
    } 

    elsif ($ref->[$i] == EXPRESSION) {
      subst_context($subst_ref, $ref->[$i+1], $token);
      $i += 2;
    }

    elsif ($ref->[$i] == ECODE) { 
      subst_string($subst_ref, $ref->[$i+1], $token);
      $i += 2; 
    }

    elsif ($ref->[$i] == CCODE) { 
      subst_string($subst_ref, @{$ref->[$i+1]}, $token);
      $i += 3; 
    }

    else { ++$i; }

  }

}


# Parameters: par1 - reference to the array of replacements
#             par2 - reference to the array of replacements (originals)
#             par3 - reference to action list
#             par4 - token that special variables start with
#             par5 - pointer into the action list
# Action: action from list par3 will be searched for special variables
#         (like $1, $2, ..) that will be replaced with 1st, 2nd, .. 
#         element from array par1 or par2; the function will return an offset
#         for advancing the pointer par5 

sub subst_none_action { return 1; }

sub subst_two_elem_action {

  my($subst_ref) = $_[0];
  my($actionlist) = $_[2];
  my($token) = $_[3];
  my($i) = $_[4];

  subst_string($subst_ref, $actionlist->[$i+1], $token);
  return 2;
}

sub subst_three_elem_action {

  my($subst_ref) = $_[0];
  my($actionlist) = $_[2];
  my($token) = $_[3];
  my($i) = $_[4];

  subst_string($subst_ref, $actionlist->[$i+1], $token);
  subst_string($subst_ref, $actionlist->[$i+2], $token);
  return 3;
}

sub subst_create_set_action {

  my($subst_ref) = $_[0];
  my($subst_orig_ref) = $_[1];
  my($actionlist) = $_[2];
  my($token) = $_[3];
  my($i) = $_[4];

  subst_string($subst_ref, $actionlist->[$i+1], $token);
  subst_string($subst_ref, $actionlist->[$i+2], $token);
  subst_actionlist($subst_orig_ref, $actionlist->[$i+3], $token);
  return 4;
}

sub subst_copy_empty_action {

  my($subst_ref) = $_[0];
  my($actionlist) = $_[2];
  my($token) = $_[3];
  my($i) = $_[4];

  subst_string($subst_ref, $actionlist->[$i+1], $token);
  return 3;
}

sub subst_event_assign_eval_action {

  my($subst_ref) = $_[0];
  my($actionlist) = $_[2];
  my($token) = $_[3];
  my($i) = $_[4];

  subst_string($subst_ref, $actionlist->[$i+2], $token);
  return 3;
}

sub subst_reset_action {

  my($subst_ref) = $_[0];
  my($actionlist) = $_[2];
  my($token) = $_[3];
  my($i) = $_[4];

  subst_string($subst_ref, $actionlist->[$i+3], $token);
  return 4;
}

sub subst_call_action {

  my($subst_ref) = $_[0];
  my($actionlist) = $_[2];
  my($token) = $_[3];
  my($i) = $_[4];

  subst_string($subst_ref, @{$actionlist->[$i+3]}, $token);
  return 4;
}


# Parameters: par1 - reference to the array of replacements
#             par2 - reference to action list
#             par3 - token that special variables start with
# Action: action list par2 will be searched for special variables
#         (like $1, $2, ..) that will be replaced with 1st, 2nd, .. 
#         element from array par1 

sub subst_actionlist {

  my($subst_ref) = $_[0];
  my($actionlist) = $_[1];
  my($token) = $_[2];
  my($subst, @subst_modified);
  my($i, $j);

  # mask %-signs in substitutions, in order to prevent incorrect
  # %<alnum>-variable interpretations

  @subst_modified = @{$subst_ref};

  foreach $subst (@subst_modified) { 
    if (defined($subst))  { $subst =~ s/%/%%/g; }
  }

  # process the action list

  $i = 0;
  $j = scalar(@{$actionlist});

  while ($i < $j) {
    $i += $actionsubstfunc[$actionlist->[$i]]->(\@subst_modified,
                                                $subst_ref,
                                                $actionlist,
                                                $token, $i);
  }

}


# Parameters: par1 - reference to an element from list %corr_list
#             par2 - time
# Action: search event-time list that is associated with element par1,
#         and remove those elements that are obsolete by time par2

sub update_times {

  my($ref) = $_[0];
  my($time) = $_[1];

  while (scalar(@{$ref->{"Times"}})) {
    if ($time - $ref->{"Times"}->[0] <= $ref->{"Window"})  { last; }
    shift @{$ref->{"Times"}};
  }

  if (scalar(@{$ref->{"Times"}})) {
    $ref->{"Time"} = $ref->{"Times"}->[0];
  } else { 
    $ref->{"Time"} = 0; 
  }

}


# Parameters: par1, par2, .. - strings
# Action: calculate unique key for strings par1, par2, .. that will be
#         used in correlation lists to distinguish between differents events

sub gen_key {
  return join(SEPARATOR, @_);
}


# Parameters: par1 - reference to a rule definition
#             par2 - reference to a list of backreference values
# Action: process the Single rule after a match has been found

sub process_single_rule {

  my($ref) = $_[0];
  my($subst) = $_[1];
  my($desc, $action);

  $desc = $ref->{"Desc"};

  if (scalar(@{$subst})) { 

    $action = [];
    copy_actionlist($ref->{"Action"}, $action);
    subst_actionlist($subst, $action, '$');
    subst_string($subst, $desc, '$');

  } else { $action = $ref->{"Action"}; } 

  execute_actionlist($action, $desc);

}


# Parameters: par1 - reference to a rule definition
#             par2 - reference to a list of backreference values
# Action: process the SingleWithScript rule after a match has been found

sub process_singlewithscript_rule {

  my($ref) = $_[0];
  my($subst) = $_[1];
  my($desc, $script, $pid);
  my($action, $action2);

  $desc = $ref->{"Desc"};
  $script = $ref->{"Script"};

  if (scalar(@{$subst})) { 

    $action = [];
    $action2 = [];
    copy_actionlist($ref->{"Action"}, $action);
    copy_actionlist($ref->{"Action2"}, $action2);
    subst_actionlist($subst, $action, '$');
    subst_actionlist($subst, $action2, '$');
    subst_string($subst, $desc, $script, '$'); 

  } else {

    $action = $ref->{"Action"};
    $action2 = $ref->{"Action2"};

  }

  $pid = pipe_cmd($script, \%context_list);

  if (defined($pid)) {

    $children{$pid}->{"Desc"} = $desc;
    $children{$pid}->{"Action"} = $action; 
    $children{$pid}->{"Action2"} = $action2;

  }

}


# Parameters: par1 - reference to a rule definition
#             par2 - reference to a list of backreference values
#             par3 - name of the configuration file
#             par4 - rule context expression with variables substituted
# Action: process the SingleWithSuppress rule after a match has been found

sub process_singlewithsuppress_rule {

  my($ref) = $_[0];
  my($subst) = $_[1];
  my($conffile) = $_[2];
  my($context) = $_[3];
  my($desc, $key, $time, $action);

  $desc = $ref->{"Desc"};
  if (scalar(@{$subst}))  { subst_string($subst, $desc, '$'); }

  $key = gen_key($conffile, $ref->{"ID"}, $desc);
  $time = time();

  # if there is no event correlation operation for the key, or 
  # the operation with the key has expired, start the new operation 

  if (!exists($corr_list{$key})  ||
      $time - $corr_list{$key}->{"Time"} > $ref->{"Window"}) {

    if (scalar(@{$subst})) { 
   
      $action = [];
      copy_actionlist($ref->{"Action"}, $action); 
      subst_actionlist($subst, $action, '$'); 
            
    } else { $action = $ref->{"Action"}; }

    $corr_list{$key} = { "Time" => $time, 
                         "Type" => $ref->{"Type"}, 
                         "File" => $conffile,
                         "ID" => $ref->{"ID"},
                         "Window" => $ref->{"Window"},
                         "Context" => $context,
                         "Desc" => $desc,
                         "Action" => $action };

    execute_actionlist($action, $desc);

  }

}


# Parameters: par1 - reference to a rule definition
#             par2 - reference to a list of backreference values
#             par3 - name of the configuration file
#             par4 - rule context expression with variables substituted
# Action: process the Pair rule after a match has been found

sub process_pair_rule {

  my($ref) = $_[0];
  my($subst) = $_[1];
  my($conffile) = $_[2];
  my($context) = $_[3];
  my($desc, $key, $time, $pattern2, $desc2);
  my($action, $action2, $context2, $sub);

  $desc = $ref->{"Desc"};
  if (scalar(@{$subst}))  { subst_string($subst, $desc, '$'); }

  $key = gen_key($conffile, $ref->{"ID"}, $desc);
  $time = time();

  # if there is no event correlation operation for the key, or 
  # the operation with the key has expired, start the new operation 

  if ( !exists($corr_list{$key})  ||  ($ref->{"Window"}  &&
       $time - $corr_list{$key}->{"Time"} > $ref->{"Window"}) ) {

    $pattern2 = $ref->{"Pattern2"};
    $desc2 = $ref->{"Desc2"};

    if (scalar(@{$subst})) {

      $action = [];
      copy_actionlist($ref->{"Action"}, $action);
      subst_actionlist($subst, $action, '$');

      $action2 = [];
      copy_actionlist($ref->{"Action2"}, $action2);
      
      $context2 = [];
      copy_context($ref->{"Context2"}, $context2);
      
      if ($ref->{"PatType2"} == REGEXP  ||
          $ref->{"PatType2"} == NREGEXP) { 

        subst_regexp($subst, $pattern2, '$'); 
        $pattern2 = qr/$pattern2/;

        # mask all $-symbols in substitutions, in order to prevent
        # false interpretations when the second pattern matches

        foreach $sub (@{$subst}) { 
          if (defined($sub))  { $sub =~ s/\$/\$\$/g; }
        }

        subst_string($subst, $desc2, '%');
        subst_actionlist($subst, $action2, '%');
        subst_context($subst, $context2, '%');

      } elsif ($ref->{"PatType2"} == PERLFUNC  ||
               $ref->{"PatType2"} == NPERLFUNC) { 

        # mask all $-symbols in substitutions, in order to prevent
        # false interpretations when the second pattern matches

        foreach $sub (@{$subst}) { 
          if (defined($sub))  { $sub =~ s/\$/\$\$/g; }
        }

        subst_string($subst, $desc2, '%');
        subst_actionlist($subst, $action2, '%');
        subst_context($subst, $context2, '%');

      } elsif ($ref->{"PatType2"} == SUBSTR  ||
               $ref->{"PatType2"} == NSUBSTR) { 
            
        subst_string($subst, $pattern2, $desc2, '$');
        subst_actionlist($subst, $action2, '$');
        subst_context($subst, $context2, '$');
              
      } else {

        subst_string($subst, $desc2, '$');
        subst_actionlist($subst, $action2, '$');
        subst_context($subst, $context2, '$');

      }

    } else {

      $action = $ref->{"Action"};
      $action2 = $ref->{"Action2"};
      $context2 = $ref->{"Context2"};

    }
          
    $corr_list{$key} = { "Time" => $time,
                         "Type" => $ref->{"Type"},
                         "File" => $conffile,
                         "ID" => $ref->{"ID"},
                         "Window" => $ref->{"Window"},
                         "Context" => $context,
                         "Desc" => $desc,
                         "Action" => $action,
                         "Pattern2" => $pattern2, 
                         "Context2" => $context2,
                         "Desc2" => $desc2,
                         "Action2" => $action2 };

    $ref->{"Operations"}->{$key} = $corr_list{$key};

    execute_actionlist($action, $desc);

  }

}


# Parameters: par1 - reference to a rule definition
#             par2 - reference to a list of backreference values
#             par3 - name of the configuration file
#             par4 - rule context expression with variables substituted
# Action: process the PairWithWindow rule after a match has been found

sub process_pairwithwindow_rule {

  my($ref) = $_[0];
  my($subst) = $_[1];
  my($conffile) = $_[2];
  my($context) = $_[3];
  my($desc, $key, $time, $pattern2, $desc2);
  my($action, $action2, $context2, $sub);

  $desc = $ref->{"Desc"};
  if (scalar(@{$subst}))  { subst_string($subst, $desc, '$'); }

  $key = gen_key($conffile, $ref->{"ID"}, $desc);
  $time = time();

  # if there is an event correlation operation for the key and 
  # the operation has expired, execute the first action list and 
  # terminate the operation

  if (exists($corr_list{$key})  &&
      $time - $corr_list{$key}->{"Time"} > $ref->{"Window"}) {

    execute_actionlist($corr_list{$key}->{"Action"}, $desc);
    delete $corr_list{$key};
    delete $ref->{"Operations"}->{$key};

  }

  # if there is no event correlation operation for the key,
  # start the new operation 

  if (!exists($corr_list{$key})) {

    $pattern2 = $ref->{"Pattern2"};
    $desc2 = $ref->{"Desc2"};

    if (scalar(@{$subst})) {

      $action = [];
      copy_actionlist($ref->{"Action"}, $action);
      subst_actionlist($subst, $action, '$');

      $action2 = [];
      copy_actionlist($ref->{"Action2"}, $action2);
                        
      $context2 = [];
      copy_context($ref->{"Context2"}, $context2);
                                                
      if ($ref->{"PatType2"} == REGEXP  ||
          $ref->{"PatType2"} == NREGEXP) { 

        subst_regexp($subst, $pattern2, '$'); 
        $pattern2 = qr/$pattern2/;

        # mask all $-symbols in substitutions, in order to prevent
        # false interpretations when the second pattern matches

        foreach $sub (@{$subst}) { 
          if (defined($sub))  { $sub =~ s/\$/\$\$/g; }
        }

        subst_string($subst, $desc2, '%');
        subst_actionlist($subst, $action2, '%');
        subst_context($subst, $context2, '%');

      } elsif ($ref->{"PatType2"} == PERLFUNC  ||
               $ref->{"PatType2"} == NPERLFUNC) { 

        # mask all $-symbols in substitutions, in order to prevent
        # false interpretations when the second pattern matches

        foreach $sub (@{$subst}) { 
          if (defined($sub))  { $sub =~ s/\$/\$\$/g; }
        }

        subst_string($subst, $desc2, '%');
        subst_actionlist($subst, $action2, '%');
        subst_context($subst, $context2, '%');

      } elsif ($ref->{"PatType2"} == SUBSTR  ||
               $ref->{"PatType2"} == NSUBSTR) { 
            
        subst_string($subst, $pattern2, $desc2, '$');
        subst_actionlist($subst, $action2, '$');
        subst_context($subst, $context2, '$');
              
      } else { 

        subst_string($subst, $desc2, '$'); 
        subst_actionlist($subst, $action2, '$');
        subst_context($subst, $context2, '$');

      }

    } else {

      $action = $ref->{"Action"};
      $action2 = $ref->{"Action2"};
      $context2 = $ref->{"Context2"};
          
    }

    $corr_list{$key} = { "Time" => $time, 
                         "Type" => $ref->{"Type"},
                         "File" => $conffile,
                         "ID" => $ref->{"ID"},
                         "Window" => $ref->{"Window"}, 
                         "Context" => $context,
                         "Desc" => $desc,
                         "Action" => $action, 
                         "Pattern2" => $pattern2, 
                         "Context2" => $context2,
                         "Desc2" => $desc2,
                         "Action2" => $action2 };

    $ref->{"Operations"}->{$key} = $corr_list{$key};

  }

}


# Parameters: par1 - reference to a rule definition
#             par2 - reference to a list of backreference values
#             par3 - name of the configuration file
#             par4 - rule context expression with variables substituted
# Action: process the SingleWithThreshold rule after a match has been found

sub process_singlewiththreshold_rule {

  my($ref) = $_[0];
  my($subst) = $_[1];
  my($conffile) = $_[2];
  my($context) = $_[3];
  my($desc, $key, $time, $action, $action2);
  my($ref2, $inside_window, $below_threshold);

  $desc = $ref->{"Desc"};
  if (scalar(@{$subst}))  { subst_string($subst, $desc, '$'); }

  $key = gen_key($conffile, $ref->{"ID"}, $desc);
  $time = time();

  # if there is no event correlation operation for the key,
  # start the new operation 

  if (!exists($corr_list{$key})) {

    if (scalar(@{$subst})) { 
         
      $action = [];
      $action2 = [];
      copy_actionlist($ref->{"Action"}, $action); 
      copy_actionlist($ref->{"Action2"}, $action2); 
      subst_actionlist($subst, $action, '$'); 
      subst_actionlist($subst, $action2, '$'); 
            
    } else { 

      $action = $ref->{"Action"}; 
      $action2 = $ref->{"Action2"}; 

    }

    $corr_list{$key} = { "Time" => $time, 
                         "Type" => $ref->{"Type"},
                         "File" => $conffile,
                         "ID" => $ref->{"ID"},
                         "Times" => [], 
                         "Window" => $ref->{"Window"},
                         "Context" => $context,
                         "Desc" => $desc,
                         "Action" => $action,
                         "Action2" => $action2,
                         "Threshold" => $ref->{"Threshold"} };

  } 

  $ref2 = $corr_list{$key};

  # inside_window - TRUE if we are still in time window
  # below_threshold - TRUE if we were below threshold before this event

  $inside_window = ($time - $ref2->{"Time"} <= $ref->{"Window"});
  $below_threshold = (scalar(@{$ref2->{"Times"}}) < $ref->{"Threshold"});

  if ($inside_window && $below_threshold) {

    # if we are inside time window and below threshold, increase 
    # the counter, and if new value of the counter equals to threshold, 
    # execute the action list

    push @{$ref2->{"Times"}}, $time;

    if (scalar(@{$ref2->{"Times"}}) == $ref->{"Threshold"}) {
      execute_actionlist($ref2->{"Action"}, $desc);
    }

  } 

  elsif ($below_threshold) {

    # if we are already outside time window but still below
    # threshold, slide the window forward

    push @{$ref2->{"Times"}}, $time;
    update_times($ref2, $time);

  }

  elsif (!$inside_window) {

    # if we are both outside time window and above threshold, then 
    # the 1st action list was executed in the past and this event 
    # correlation operation has been suppressing post-action events;
    # since the operation has expired, execute its 2nd action list 
    # and start the new operation, because the event we have received 
    # matches the rule.

    execute_actionlist($ref2->{"Action2"}, $desc);

    if (scalar(@{$subst})) { 
    
      $action = [];
      $action2 = [];
      copy_actionlist($ref->{"Action"}, $action);
      copy_actionlist($ref->{"Action2"}, $action2);
      subst_actionlist($subst, $action, '$');
      subst_actionlist($subst, $action2, '$');
            
    } else { 

      $action = $ref->{"Action"}; 
      $action2 = $ref->{"Action2"}; 

    }

    $corr_list{$key} = { "Time" => $time, 
                         "Type" => $ref->{"Type"},
                         "File" => $conffile,
                         "ID" => $ref->{"ID"},
                         "Times" => [ $time ], 
                         "Window" => $ref->{"Window"},
                         "Context" => $context,
                         "Desc" => $desc,
                         "Action" => $action,
                         "Action2" => $action2,
                         "Threshold" => $ref->{"Threshold"} };

    if ($ref->{"Threshold"} == 1) {
      execute_actionlist($action, $desc); 
    }

  } 

}


# Parameters: par1 - reference to a rule definition
#             par2 - reference to a list of backreference values
#             par3 - name of the configuration file
#             par4 - rule context expression with variables substituted
# Action: process the SingleWith2Thresholds rule after a match has been found

sub process_singlewith2thresholds_rule {

  my($ref) = $_[0];
  my($subst) = $_[1];
  my($conffile) = $_[2];
  my($context) = $_[3];
  my($desc, $key, $time, $desc2, $action, $action2);
  my($ref2, $inside_window, $below_threshold);

  $desc = $ref->{"Desc"};
  if (scalar(@{$subst}))  { subst_string($subst, $desc, '$'); }

  $key = gen_key($conffile, $ref->{"ID"}, $desc);
  $time = time();

  # if there is no event correlation operation for the key,
  # start the new operation 

  if (!exists($corr_list{$key})) {

    $desc2 = $ref->{"Desc2"};

    if (scalar(@{$subst})) { 

      $action = [];
      $action2 = [];
      copy_actionlist($ref->{"Action"}, $action);
      copy_actionlist($ref->{"Action2"}, $action2);
      subst_actionlist($subst, $action, '$');
      subst_actionlist($subst, $action2, '$');
      subst_string($subst, $desc2, '$');

    } else {
          
      $action = $ref->{"Action"};
      $action2 = $ref->{"Action2"};
            
    }

    $corr_list{$key} = { "Time" => $time, 
                         "Type" => $ref->{"Type"},
                         "File" => $conffile,
                         "ID" => $ref->{"ID"},
                         "Times" => [], 
                         "Window" => $ref->{"Window"}, 
                         "Context" => $context,
                         "Desc" => $desc,
                         "Action" => $action,
                         "Threshold" => $ref->{"Threshold"}, 
                         "2ndPass" => 0,
                         "Window2" => $ref->{"Window2"}, 
                         "Threshold2" => $ref->{"Threshold2"}, 
                         "Desc2" => $desc2,
                         "Action2" => $action2 };

  } 

  $ref2 = $corr_list{$key};

  # the 1st round of counting with a rising threshold

  if (!$ref2->{"2ndPass"}) {

    # inside_window - TRUE if we are still in time window
    # below_threshold - TRUE if we were below threshold before this event

    $inside_window = ($time - $ref2->{"Time"} <= $ref->{"Window"});
    $below_threshold = (scalar(@{$ref2->{"Times"}}) < $ref->{"Threshold"});

    if ($inside_window) {

      # if we are inside time window, increase the counter, and
      # if new value of the counter equals to threshold, execute
      # the action list and start to check 2nd threshold

      push @{$ref2->{"Times"}}, $time;

      if (scalar(@{$ref2->{"Times"}}) == $ref->{"Threshold"}) {

        $ref2->{"Time"} = $time;
        $ref2->{"2ndPass"} = 1;
        $ref2->{"Times"} = [];
        execute_actionlist($ref2->{"Action"}, $desc);

      }

    } 

    elsif ($below_threshold) {

      # if we are already outside time window but still below
      # threshold, slide the window forward

      push @{$ref2->{"Times"}}, $time;
      update_times($ref2, $time);

    }

  # the 2nd round of counting with a falling threshold

  } else {

    # inside_window - TRUE if we are still in time window
    # below_threshold - TRUE if we were below threshold before this event

    $inside_window = ($time - $ref2->{"Time"} <= $ref->{"Window2"});
    $below_threshold = (scalar(@{$ref2->{"Times"}}) < $ref->{"Threshold2"});

    if ($inside_window && $below_threshold) {

      # if we are both inside time window and below threshold,
      # we can increase the counter (this threshold is considered
      # as crossed if counter > threshold, counter == threshold
      # is still permitted).

      push @{$ref2->{"Times"}}, $time;

    }

    elsif ($inside_window) {

      # if we are inside the time window and below_threshold == FALSE
      # then together with current event we have crossed the threshold
      # (counter > threshold). So we have to slide the window.

      if ($ref->{"Threshold2"}) {

        shift @{$ref2->{"Times"}};
        push @{$ref2->{"Times"}}, $time;
        $ref2->{"Time"} = $ref2->{"Times"}->[0];

      } else { $ref2->{"Time"} = $time; }

    } 

    else {

      # if we have reached here, we must be outside time window
      # and also below threshold, since threshold crossing would
      # have already been detected by previous code block.
      # So we can execute the action list.

      execute_actionlist($ref2->{"Action2"}, $ref2->{"Desc2"});

      # since action was just executed we can terminate this event
      # correlation operation and start the new one, because the event
      # we have received matches the rule.
            
      $desc2 = $ref->{"Desc2"};

      if (scalar(@{$subst})) { 

        $action = [];
        $action2 = [];
        copy_actionlist($ref->{"Action"}, $action);
        copy_actionlist($ref->{"Action2"}, $action2);
        subst_actionlist($subst, $action, '$');
        subst_actionlist($subst, $action2, '$');
        subst_string($subst, $desc2, '$');

      } else {

        $action = $ref->{"Action"};
        $action2 = $ref->{"Action2"};

      }

      $corr_list{$key} = { "Time" => $time, 
                           "Type" => $ref->{"Type"},
                           "File" => $conffile,
                           "ID" => $ref->{"ID"},
                           "Times" => [ $time ], 
                           "Window" => $ref->{"Window"}, 
                           "Context" => $context,
                           "Desc" => $desc,
                           "Action" => $action,
                           "Threshold" => $ref->{"Threshold"}, 
                           "2ndPass" => 0,
                           "Window2" => $ref->{"Window2"}, 
                           "Threshold2" => $ref->{"Threshold2"}, 
                           "Desc2" => $desc2,
                           "Action2" => $action2 };

      if ($ref->{"Threshold"} == 1) {

        $corr_list{$key}->{"2ndPass"} = 1;
        $corr_list{$key}->{"Times"} = [];
        execute_actionlist($action, $desc);

      }

    }

  }

}


# Parameters: par1 - reference to a rule definition
#             par2 - reference to a list of backreference values
#             par3 - name of the configuration file
#             par5 - trace hash for detecting loops during recursive calls
# Action: process the Jump rule after a match has been found

sub process_jump_rule {

  my($ref) = $_[0];
  my($subst) = $_[1];
  my($conffile) = $_[2];
  my($trace) = $_[4];
  my($cfsetlist, $cfset, $cf);

  if (!exists($ref->{"CFSet"})) { return; }

  if (!defined($trace))  { $trace = {}; }

  if (!exists($ref->{"ConstSet"}) && scalar(@{$subst})) {
    $cfsetlist = [ @{$ref->{"CFSet"}} ];
    subst_string($subst, @{$cfsetlist}, '$');
  } else { 
    $cfsetlist = $ref->{"CFSet"}; 
  }

  foreach $cfset (@{$cfsetlist}) {

    if (exists($trace->{$cfset})) { 
      log_msg(LOG_WARN, 
        "Can't jump to fileset '$cfset' from $conffile, loop detected");
      next; 
    }

    if (!exists($cfset2cfile{$cfset})) { 
      log_msg(LOG_WARN, 
        "Can't jump to fileset '$cfset' from $conffile, set does not exist");
      next; 
    }

    # process the files in the set by calling process_rules() recursively; 
    # the set name is recorded to %trace, in order to detect loops

    $trace->{$cfset} = 1;

    foreach $cf (@{$cfset2cfile{$cfset}}) { process_rules($cf, $trace); }

    delete $trace->{$cfset};

  }

}


# Parameters: par1 - name of the configuration file
#             par2 - trace hash for detecting loops during recursive calls
# Action: search the rules from configuration file par1 and check, if 
#         there is a matching rule for the current content of input buffer.
#         If matching rule is found, new element (that corresponds to
#         an event correlation operation) will be added to the list 
#         %corr_list. Key for new element is calculated by calling gen_key 
#         function:
#         gen_key(file name, rule number, textual description of event)

sub process_rules {

  my($conffile) = $_[0];
  my($trace) = $_[1];
  my($i, $n, $ref, $match_found, @subst, $context);

  $i = 0;
  $n = scalar(@{$configuration{$conffile}});

  while ($i < $n) { 

    $ref = $configuration{$conffile}->[$i];

    # skip the CALENDAR rule

    if ($ref->{"Type"} == CALENDAR)  { ++$i; next; }

    # check if the rule context expression must be evaluated before 
    # comparing input line(s) with the pattern

    if ($ref->{"ContPreEval"}) {

      # if the value of the context expression is FALSE and the rule is 
      # of type Pair*, look also for all active correlation operations 
      # associated with the current rule and check if 2nd pattern matches

      if (!tval_context_expr($ref->{"Context"})) {
        if ( ($ref->{"Type"} == PAIR  ||  $ref->{"Type"} == PAIR_W_WINDOW)  
             &&  scalar(%{$ref->{"Operations"}}) ) {
          if (process_rules2($ref)) { 
            if ($ref->{"WhatNext2"} == DONTCONT)  { return 1; }
            $i = $ref->{"GotoRule2"};
            next;
          }
        }
        ++$i;
        next;
      }

      $context = $ref->{"Context"};

    }

    # Check if last N lines of input buffer match the pattern
    # specified by rule (value of N is also specified by rule)
    # If match was found, set $match_found to 1
    # If the pattern returned any values, assign them to @subst, 
    # otherwise leave @subst empty

    $match_found = $matchfunc[$ref->{"PatType"}]->($ref->{"PatLines"}, 
                                                   $ref->{"Pattern"}, 
                                                   \@subst);

    # If match was found, process the event

    if ($match_found) {

      # Evaluate the context expression of the rule

      if (!scalar(@{$ref->{"Context"}}))  { $context = []; }

      elsif (!$ref->{"ContPreEval"}) {

        if (scalar(@subst)) { 

          $context = [];        
          copy_context($ref->{"Context"}, $context); 
          subst_context(\@subst, $context, '$'); 

        } else { $context = $ref->{"Context"}; } 

        # if the value of the context expression is FALSE and the rule is 
        # of type Pair*, look also for all active correlation operations 
        # associated with the current rule and check if 2nd pattern matches

        if (!tval_context_expr($context)) {
          if ( ($ref->{"Type"} == PAIR  ||  $ref->{"Type"} == PAIR_W_WINDOW)  
               &&  scalar(%{$ref->{"Operations"}}) ) {
            if (process_rules2($ref)) { 
              if ($ref->{"WhatNext2"} == DONTCONT)  { return 1; }
              $i = $ref->{"GotoRule2"};
              next;
            }
          }
          ++$i;
          next;
        }

      }

      # increment the counter that reflects the rule usage
      # (just for statistical purposes)

      ++$ref->{"MatchCount"};

      # if rule is of type SUPPRESS, return 1

      if ($ref->{"Type"} == SUPPRESS)  { return 1; }

      # for other rule types, process the rule
 
      $processrulefunc[$ref->{"Type"}]->($ref, \@subst, $conffile, 
                                         $context, $trace);

      # if the rule's continue parameter is set to DontCont, return 1,
      # otherwise go to the rule specified with continue

      if ($ref->{"WhatNext"} == DONTCONT)  { return 1; }
      $i = $ref->{"GotoRule"};
      next;

    } else {

      # if match was not found and rule is of type Pair*, look also for 
      # all active correlation operations associated with the current 
      # rule and check if 2nd pattern matches

      if ( ($ref->{"Type"} == PAIR  ||  $ref->{"Type"} == PAIR_W_WINDOW)  
           &&  scalar(%{$ref->{"Operations"}}) ) {
        if (process_rules2($ref)) { 
          if ($ref->{"WhatNext2"} == DONTCONT)  { return 1; }
          $i = $ref->{"GotoRule2"};
          next;
        }
      }
      ++$i;
      next;
    }

  }

  # if the end of the ruleset was reached, return 0
  return 0;

}


# Parameters: par1 - reference to a rule
# Action: search the event correlation operations associated with Pair*
#         rules and check, if there is a matching event for the current 
#         content of input buffer. If there were 1 or more matches found, 
#         return 1, otherwise return 0

sub process_rules2 {

  my($elem) = $_[0];
  my($key, $ref, $ret);
  my($match_found, @subst);
  my($type, $window);
  my($pattype2, $patlines2, $desc2);
  my($context2, $action2);

  $ret = 0;   # shows if matches were found
  $type = $elem->{"Type"};
  $pattype2 = $elem->{"PatType2"};
  $patlines2 = $elem->{"PatLines2"};
  $window = $elem->{"Window"};

  foreach $key (keys %{$elem->{"Operations"}}) {

    if (!exists($elem->{"Operations"}->{$key}))  { next; }

    $ref = $elem->{"Operations"}->{$key};

    # check if the rule context expression must be evaluated before
    # comparing input line(s) with the pattern

    if ($elem->{"ContPreEval2"}) {
      if (!tval_context_expr($ref->{"Context2"}))  { next; }  
    }

    # Check if last N lines of input buffer match the pattern
    # If match was found, set $match_found to 1
    # If the pattern returned any values, assign them to @subst,
    # otherwise leave @subst empty

    $match_found = $matchfunc[$pattype2]->($patlines2, 
                                           $ref->{"Pattern2"}, 
                                           \@subst);

    # If match was found, process the event

    if ($match_found) {

      # Evaluate the context expression of the rule

      if (scalar(@{$ref->{"Context2"}})  &&  !$elem->{"ContPreEval2"}) {

        if (scalar(@subst)) { 
       
          $context2 = [];
          copy_context($ref->{"Context2"}, $context2); 
          subst_context(\@subst, $context2, '$'); 
          
        } else { $context2 = $ref->{"Context2"}; }

        if (!tval_context_expr($context2))  { next; }  

      }

      # processing for PAIR rule

      if ($type == PAIR) {

        # if we are inside time window, execute 2nd action list

        if (!$window  ||  time() - $ref->{"Time"} <= $window) {

          $ret = 1;
          ++$elem->{"MatchCount"};
          $desc2 = $ref->{"Desc2"};

          if (scalar(@subst)) { 

            $action2 = [];
            copy_actionlist($ref->{"Action2"}, $action2);
            subst_actionlist(\@subst, $action2, '$');
            subst_string(\@subst, $desc2, '$'); 

          } else { $action2 = $ref->{"Action2"}; }

          execute_actionlist($action2, $desc2);

        }

        # now we can terminate this event correlation operation,
        # since we have seen the event that matches the second pattern

        delete $corr_list{$key};
        delete $elem->{"Operations"}->{$key};

      }

      # processing for PAIR_W_WINDOW rule

      elsif ($type == PAIR_W_WINDOW) {

        # we can terminate this event correlation operation,
        # since we have seen the event that matches the second pattern
        # (in order to achieve good event ordering, execute 2nd action
        # list without checking the window)

        $ret = 1;
        ++$elem->{"MatchCount"};
        $desc2 = $ref->{"Desc2"};

        if (scalar(@subst)) { 

          $action2 = [];
          copy_actionlist($ref->{"Action2"}, $action2);
          subst_actionlist(\@subst, $action2, '$');
          subst_string(\@subst, $desc2, '$'); 

        } else { $action2 = $ref->{"Action2"}; }

        execute_actionlist($action2, $desc2);
        delete $corr_list{$key};
        delete $elem->{"Operations"}->{$key};

      }

    }
    
  }

  # if there were 1 or more matches found, return 1, otherwise return 0

  return $ret;

}


# Parameters: -
# Action: search lists %corr_list, %context_list, @calendar and 
#         @pending_events, performing timed tasks that are associated 
#         with elements and removing obsolete elements

sub process_lists {

  my($key, $ref, $config);
  my($time, $diff, $lastdayofmonth);
  my(@time, $event, @buffer);
  my($minute, $hour, $day, $month, $weekday);

  # remove obsolete elements from %context_list

  foreach $key (keys %context_list)  { valid_context($key); }

  # move pending events that have become relevant from 
  # @pending_events list to @events list

  if (scalar(@pending_events)) {

    @buffer = ();

    foreach $ref (@pending_events) {

      if (time() >= $ref->[0]) {

        $event = $ref->[1];
        log_msg(LOG_DEBUG, "Creating event '$event'");
        push @events, $event;

      } else { push @buffer, $ref; } 

    }  

    @pending_events = @buffer;

  }

  # process CALENDAR rules

  @time = localtime(time());
  $minute = $time[1];
  $hour = $time[2];
  $day = $time[3];
  $month = $time[4];
  $weekday = $time[6];

  $lastdayofmonth = ((localtime(time()+86400))[3] == 1);

  foreach $ref (@calendar) {

    # if we have already performed this task in current minute, skip

    if ($minute == $ref->{"LastMinute"} && 
        $hour == $ref->{"LastHour"} &&
        $day == $ref->{"LastDay"} && 
        $month == $ref->{"LastMonth"} &&
        $weekday == $ref->{"LastWeekday"})  { next; }

    # if one of the time conditions does not hold, skip

    if (!exists($ref->{"Minutes"}->{$minute}))  { next; }
    if (!exists($ref->{"Hours"}->{$hour}))  { next; }
 
    if (!exists($ref->{"Days"}->{$day}) &&
        !($lastdayofmonth && exists($ref->{"Days"}->{"0"})))  { next; }

    if (!exists($ref->{"Months"}->{$month}))  { next; }
    if (!exists($ref->{"Weekdays"}->{$weekday}))  { next; }

    # check the context expression of the rule
    
    if (scalar(@{$ref->{"Context"}})) {
      if (!tval_context_expr($ref->{"Context"}))  { next; }  
    }

    # execute the action list of the calendar event 
    # and save current time

    execute_actionlist($ref->{"Action"}, $ref->{"Desc"});

    $ref->{"LastMinute"} = $minute;
    $ref->{"LastHour"} = $hour;
    $ref->{"LastDay"} = $day;
    $ref->{"LastMonth"} = $month;
    $ref->{"LastWeekday"} = $weekday;

    ++$ref->{"MatchCount"};

  }

  # perform timed tasks that are associated with elements of
  # %corr_list and remove obsolete elements

  foreach $key (keys %corr_list) {

    if (!exists($corr_list{$key}))  { next; }

    $ref = $corr_list{$key};

    $time = time();
    $diff = $time - $ref->{"Time"};
    $config = $configuration{$ref->{"File"}}->[$ref->{"ID"}];

    # ------------------------------------------------------------ 
    # SINGLE_W_SUPPRESS rule
    # ------------------------------------------------------------ 

    if ($ref->{"Type"} == SINGLE_W_SUPPRESS) {

      # if we are outside time window, list element is obsolete
      # and can be removed 

      if ($diff > $ref->{"Window"})  { delete $corr_list{$key}; }

    }

    # ------------------------------------------------------------ 
    # PAIR rule
    # ------------------------------------------------------------ 

    elsif ($ref->{"Type"} == PAIR) {

      # if we are outside time window, list elements are obsolete
      # and can be removed 

      if ($ref->{"Window"}  &&  $diff > $ref->{"Window"}) {
        delete $corr_list{$key};
        delete $config->{"Operations"}->{$key};
      }

    }

    # ------------------------------------------------------------ 
    # PAIR_W_WINDOW rule
    # ------------------------------------------------------------ 

    elsif ($ref->{"Type"} == PAIR_W_WINDOW) {

      # if we are outside time window, 1st action must be executed;
      # after that the list elements are obsolete and can be removed 

      if ($diff > $ref->{"Window"}) {
        execute_actionlist($ref->{"Action"}, $ref->{"Desc"});
        delete $corr_list{$key};
        delete $config->{"Operations"}->{$key};
      }

    }

    # ------------------------------------------------------------ 
    # SINGLE_W_THRESHOLD rule
    # ------------------------------------------------------------ 

    elsif ($ref->{"Type"} == SINGLE_W_THRESHOLD) {

      if ($diff > $ref->{"Window"}) {

        if (scalar(@{$ref->{"Times"}}) < $ref->{"Threshold"}) {

          # If we are outside time window and threshold is not exceeded, 
          # try to slide the window. If all events are gone after sliding,
          # remove the list element as obsolete.

          update_times($ref, $time);
          if (!scalar(@{$ref->{"Times"}}))  { delete $corr_list{$key}; }

        } else {

          # If we are outside time window and threshold is exceeded, 
          # execute the 2nd action and remove the list element as obsolete.

          execute_actionlist($ref->{"Action2"}, $ref->{"Desc"});
          delete $corr_list{$key};

        }

      }

    }

    # ------------------------------------------------------------ 
    # SINGLE_W_2_THRESHOLDS rule
    # ------------------------------------------------------------ 

    elsif ($ref->{"Type"} == SINGLE_W_2_THRESHOLDS) {

      if (!$ref->{"2ndPass"}) {

        # If we are outside 1st time window, try to slide the window.
        # If all events are gone after sliding, remove the list element 
        # as obsolete

        if ($diff > $ref->{"Window"}) {
          update_times($ref, $time);
          if (!scalar(@{$ref->{"Times"}}))  { delete $corr_list{$key}; }
        }

      } else {

        # If we are outside 2nd time window and list element
        # has not been removed, we can conclude that 2nd threshold was
        # not exceeded, and so 2nd action can be executed.
        # After that the list element can be removed as obsolete.

        if ($diff > $ref->{"Window2"}) {
          execute_actionlist($ref->{"Action2"}, $ref->{"Desc2"});
          delete $corr_list{$key};
        }

      }

    }

  }

}


#################################################
# Functions related to reporting and data dumping
#################################################


# Parameters: par1 - reference to a action list
# Action: convert action list to a string representation

sub actionlist2str {

  my($actionlist) = $_[0];
  my($i, $j);
  my($result);

  $i = 0;
  $j = scalar(@{$actionlist});
  $result = "";

  while ($i < $j) {

    if ($actionlist->[$i] == NONE) { 
      $result .= "none"; 
      ++$i;
    }

    elsif ($actionlist->[$i] == LOGONLY) { 
      $result .= "logonly " . $actionlist->[$i+1];
      $i += 2;
    } 

    elsif ($actionlist->[$i] == WRITE) {
      $result .= "write " . $actionlist->[$i+1] . " " . $actionlist->[$i+2];
      $i += 3;
    }

    elsif ($actionlist->[$i] == SHELLCOMMAND) { 
      $result .= "shellcmd " . $actionlist->[$i+1]; 
      $i += 2;
    } 

    elsif ($actionlist->[$i] == SPAWN) { 
      $result .= "spawn " . $actionlist->[$i+1]; 
      $i += 2;
    } 

    elsif ($actionlist->[$i] == PIPE) {
      $result .= "pipe " . $actionlist->[$i+1] . " " . $actionlist->[$i+2];
      $i += 3;
    }

    elsif ($actionlist->[$i] == CREATECONTEXT) { 
      $result .= "create " . $actionlist->[$i+1] . " " . $actionlist->[$i+2];
      if (scalar(@{$actionlist->[$i+3]})) {
        $result .= " (" . actionlist2str($actionlist->[$i+3]) . ")";
      }
      $i += 4; 
    } 

    elsif ($actionlist->[$i] == DELETECONTEXT) { 
      $result .= "delete " . $actionlist->[$i+1]; 
      $i += 2;
    } 

    elsif ($actionlist->[$i] == OBSOLETECONTEXT) { 
      $result .= "obsolete " . $actionlist->[$i+1]; 
      $i += 2;
    } 

    elsif ($actionlist->[$i] == SETCONTEXT) {
      $result .= "set " . $actionlist->[$i+1] . " " . $actionlist->[$i+2];
      if (scalar(@{$actionlist->[$i+3]})) {
        $result .= " (" . actionlist2str($actionlist->[$i+3]) . ")";
      }
      $i += 4;
    }

    elsif ($actionlist->[$i] == ALIAS) { 
      $result .= "alias " . $actionlist->[$i+1] . " " . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == UNALIAS) { 
      $result .= "unalias " . $actionlist->[$i+1]; 
      $i += 2;
    }

    elsif ($actionlist->[$i] == ADD) { 
      $result .= "add " . $actionlist->[$i+1] . " " . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == FILL) { 
      $result .= "fill " . $actionlist->[$i+1] . " " . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == REPORT) { 
      $result .= "report " . $actionlist->[$i+1] . " " . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == COPYCONTEXT) { 
      $result .= "copy " . $actionlist->[$i+1] . " %" . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == EMPTYCONTEXT) { 
      if (length($actionlist->[$i+2])) {
        $result .= "empty " . $actionlist->[$i+1] . " %" . $actionlist->[$i+2];
      } else {
        $result .= "empty " . $actionlist->[$i+1];
      }
      $i += 3;
    }

    elsif ($actionlist->[$i] == EVENT) { 
      $result .= "event " . $actionlist->[$i+1] . " " . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == TEVENT) { 
      $result .= "tevent " . $actionlist->[$i+1] . " " . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == RESET) { 
      $result .= "reset " . $actionlist->[$i+2] . " " . $actionlist->[$i+3]; 
      $i += 4;
    }

    elsif ($actionlist->[$i] == ASSIGN) { 
      $result .= "assign %" . $actionlist->[$i+1] . " " . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == EVAL) { 
      $result .= "eval %" . $actionlist->[$i+1] . " " . $actionlist->[$i+2]; 
      $i += 3;
    }

    elsif ($actionlist->[$i] == CALL) { 
      $result .= "call %" . $actionlist->[$i+1] . " %" . $actionlist->[$i+2]
                 . " " . join(" ", @{$actionlist->[$i+3]}); 
      $i += 4;
    }

    else { return "Unknown action type in the action list"; }

    $result .= "; ";

  }

  return $result;

}


# Parameters: par1 - pattern type
#             par2 - pattern lines
#             par3 - pattern
# Action: convert pattern to a printable representation

sub pattern2str {

  my($type) = $_[0];
  my($lines) = $_[1];
  my($pattern) = $_[2];

  if ($type == SUBSTR) { 
    return "substring for $lines line(s): $pattern"; 
  } 

  elsif ($type == REGEXP) {
    return "regexp for $lines line(s): $pattern";
  } 

  elsif ($type == PERLFUNC) {
    return "perlfunc for $lines line(s): $pattern";
  } 

  elsif ($type == NSUBSTR) { 
    return "negative substring for $lines line(s): $pattern"; 
  } 

  elsif ($type == NREGEXP) {
    return "negative regexp for $lines line(s): $pattern";
  } 

  elsif ($type == NPERLFUNC) {
    return "negative perlfunc for $lines line(s): $pattern";
  } 

  elsif ($type == TVALUE) {
    return "truth value: " . ($pattern?"TRUE":"FALSE");
  } 

  else { return "Unknown pattern type"; }

}


# Parameters: par1 - continue value
#             par2 - rule number
# Action: convert continue parameters to a printable representation

sub continue2str {

  my($whatnext) = $_[0];
  my($gotorule) = $_[1];

  if ($whatnext == DONTCONT) { return "don't continue"; }
  elsif ($whatnext == TAKENEXT) { return "take next"; }
  elsif ($whatnext == GOTO) { return "goto rule " . ($gotorule + 1); }
  else { return "Unknown continue value"; }

}


# Parameters: par1 - reference to a context formula
# Action: convert given context to a printable representation

sub context2str {

  my($ref) = $_[0];
  my($i, $j, $op1, $op2);
  my(@stack, $result);

  $i = 0;
  $j = scalar(@{$ref});
  @stack = ();

  while ($i < $j) {

    if ($ref->[$i] == EXPRESSION) {
      $op1 = $ref->[$i+1];
      push @stack, "(" . context2str($op1) . ")";
      $i += 2;
    }

    elsif ($ref->[$i] == ECODE) {
      $op1 = $ref->[$i+1];
      push @stack, "=( " . $op1 . " )";
      $i += 2;
    }

    elsif ($ref->[$i] == CCODE) {
      $op1 = $ref->[$i+1];
      $op2 = $ref->[$i+2];
      push @stack, join(" ", @{$op1}) . " -> " . $op2;
      $i += 3;
    }

    elsif ($ref->[$i] == OPERAND) {
      $op1 = $ref->[$i+1];
      push @stack, $op1;
      $i += 2;
    }

    elsif ($ref->[$i] == NEGATION) {
      $op1 = pop @stack;
      push @stack, "!" . $op1;
      ++$i;
    }

    elsif ($ref->[$i] == AND) {
      $op2 = pop @stack;
      $op1 = pop @stack;
      push @stack, $op1 . " && " . $op2;
      ++$i;
    }

    elsif ($ref->[$i] == OR) {
      $op2 = pop @stack;
      $op1 = pop @stack;
      push @stack, $op1 . " || " . $op2;
      ++$i;
    }

    else { return "Unknown operator in the context expression"; }

  }

  $result = pop @stack;

  if (!defined($result))  { $result = ""; }

  return $result;

}


# Parameters: par1 - filehandle
#             par2 - list element key
#             par3 - reference to list element
# Action: print given list element to the filehandle

sub print_element {

  my($handle) = $_[0];
  my($key) = $_[1];
  my($ref) = $_[2];
  my($config, $conffile, $id, $time);

  print $handle "Key:\t\t\t\t", $key, "\n";
  print $handle "Start of correlation operation:\t", 
                scalar(localtime($ref->{"Time"})), "\n";

  $conffile = $ref->{"File"};
  $id = $ref->{"ID"};
  $config = $configuration{$conffile}->[$id];

  print $handle "Configuration file:\t\t", $conffile, "\n";
  print $handle "Rule number:\t\t\t", $id+1, "\n";
  print $handle "Rule internal ID:\t\t", $id, "\n";

  if ($ref->{"Type"} == SINGLE_W_SUPPRESS) {

    print $handle "Type:\t\t\t\t";
    print $handle "SingleWithSuppress\n";

    print $handle "Behavior after match:\t\t";
    print $handle continue2str($config->{"WhatNext"}, $config->{"GotoRule"});
    print $handle "\n";
    
    print $handle "Pattern:\t\t\t";
    print $handle pattern2str($config->{"PatType"},
                  $config->{"PatLines"}, $config->{"Pattern"});
    print $handle "\n";

    print $handle "Context:\t\t\t";
    print $handle context2str($ref->{"Context"});
    print $handle "\n";

    print $handle "Event:\t\t\t\t", $ref->{"Desc"}, "\n";

    print $handle "Action:\t\t\t\t";
    print $handle actionlist2str($ref->{"Action"});
    print $handle "\n";

    print $handle "Window:\t\t\t\t", $ref->{"Window"}, " seconds\n";

    print $handle "\n";

  }

  elsif ($ref->{"Type"} == PAIR) {

    print $handle "Type:\t\t\t\t";
    print $handle "Pair\n";

    print $handle "Behavior after 1st match:\t";
    print $handle continue2str($config->{"WhatNext"}, $config->{"GotoRule"});
    print $handle "\n";
    
    print $handle "1st Pattern:\t\t\t";
    print $handle pattern2str($config->{"PatType"},
                  $config->{"PatLines"}, $config->{"Pattern"});
    print $handle "\n";

    print $handle "1st Context:\t\t\t";
    print $handle context2str($ref->{"Context"});
    print $handle "\n";

    print $handle "1st Event:\t\t\t", $ref->{"Desc"}, "\n";

    print $handle "1st Action:\t\t\t";
    print $handle actionlist2str($ref->{"Action"});
    print $handle "\n";

    print $handle "Behavior after 2nd match:\t";
    print $handle continue2str($config->{"WhatNext2"}, $config->{"GotoRule2"});
    print $handle "\n";
    
    print $handle "2nd Pattern:\t\t\t";
    print $handle pattern2str($config->{"PatType2"},
                  $config->{"PatLines2"}, $ref->{"Pattern2"});
    print $handle "\n";

    print $handle "2nd Context:\t\t\t";
    print $handle context2str($ref->{"Context2"});
    print $handle "\n";

    print $handle "2nd Event:\t\t\t", $ref->{"Desc2"}, "\n";

    print $handle "2nd Action:\t\t\t";
    print $handle actionlist2str($ref->{"Action2"});
    print $handle "\n";

    if ($ref->{"Window"}) {
      print $handle "Window:\t\t\t\t", $ref->{"Window"}, " seconds\n";
    } else {
      print $handle "Window:\t\t\t\t", "infinite\n";
    }

    print $handle "\n";

  }

  elsif ($ref->{"Type"} == PAIR_W_WINDOW) {

    print $handle "Type:\t\t\t\t";
    print $handle "PairWithWindow\n";

    print $handle "Behavior after 1st match:\t";
    print $handle continue2str($config->{"WhatNext"}, $config->{"GotoRule"});
    print $handle "\n";
    
    print $handle "1st Pattern:\t\t\t";
    print $handle pattern2str($config->{"PatType"},
                  $config->{"PatLines"}, $config->{"Pattern"});
    print $handle "\n";

    print $handle "Context:\t\t\t";
    print $handle context2str($ref->{"Context"});
    print $handle "\n";

    print $handle "1st Event:\t\t\t", $ref->{"Desc"}, "\n";

    print $handle "1st Action:\t\t\t";
    print $handle actionlist2str($ref->{"Action"});
    print $handle "\n";

    print $handle "Behavior after 2nd match:\t";
    print $handle continue2str($config->{"WhatNext2"}, $config->{"GotoRule2"});
    print $handle "\n";
    
    print $handle "2nd Pattern:\t\t\t";
    print $handle pattern2str($config->{"PatType2"},
                  $config->{"PatLines2"}, $ref->{"Pattern2"});
    print $handle "\n";

    print $handle "2nd Context:\t\t\t";
    print $handle context2str($ref->{"Context2"});
    print $handle "\n";

    print $handle "2nd Event:\t\t\t", $ref->{"Desc2"}, "\n";

    print $handle "2nd Action:\t\t\t";
    print $handle actionlist2str($ref->{"Action2"});
    print $handle "\n";

    print $handle "Window:\t\t\t\t", $ref->{"Window"}, " seconds\n";

    print $handle "\n";

  }

  elsif ($ref->{"Type"} == SINGLE_W_THRESHOLD) {

    print $handle "Type:\t\t\t\t";
    print $handle "SingleWithThreshold\n";

    print $handle "Behavior after match:\t\t";
    print $handle continue2str($config->{"WhatNext"}, $config->{"GotoRule"});
    print $handle "\n";
    
    print $handle "Pattern:\t\t\t";
    print $handle pattern2str($config->{"PatType"},
                  $config->{"PatLines"}, $config->{"Pattern"});
    print $handle "\n";

    print $handle "Context:\t\t\t";
    print $handle context2str($ref->{"Context"});
    print $handle "\n";

    print $handle "Event:\t\t\t\t", $ref->{"Desc"}, "\n";

    print $handle "1st Action:\t\t\t";
    print $handle actionlist2str($ref->{"Action"});
    print $handle "\n";

    print $handle "2nd Action:\t\t\t";
    print $handle actionlist2str($ref->{"Action2"});
    print $handle "\n";

    print $handle "Window:\t\t\t\t", $ref->{"Window"}, " seconds\n";

    print $handle "Threshold:\t\t\t", $ref->{"Threshold"}, "\n";

    print $handle scalar(@{$ref->{"Times"}}), " events observed at:\n";

    foreach $time (@{$ref->{"Times"}}) 
        { print $handle scalar(localtime($time)), "\n"; }

    print $handle "\n";

  }

  elsif ($ref->{"Type"} == SINGLE_W_2_THRESHOLDS) {

    print $handle "Type:\t\t\t\t";
    print $handle "SingleWith2Thresholds\n";

    print $handle "Behavior after match:\t\t";
    print $handle continue2str($config->{"WhatNext"}, $config->{"GotoRule"});
    print $handle "\n";
    
    print $handle "Pattern:\t\t\t";
    print $handle pattern2str($config->{"PatType"},
                  $config->{"PatLines"}, $config->{"Pattern"});
    print $handle "\n";

    print $handle "Context:\t\t\t";
    print $handle context2str($ref->{"Context"});
    print $handle "\n";

    print $handle "1st Event:\t\t\t", $ref->{"Desc"}, "\n";

    print $handle "1st Action:\t\t\t";
    print $handle actionlist2str($ref->{"Action"});
    print $handle "\n";

    print $handle "1st Window:\t\t\t", $ref->{"Window"}, " seconds\n";

    print $handle "1st Threshold:\t\t\t", $ref->{"Threshold"}, "\n";

    print $handle "2nd Event:\t\t\t", $ref->{"Desc2"}, "\n";

    print $handle "2nd Action:\t\t\t";
    print $handle actionlist2str($ref->{"Action2"});
    print $handle "\n";

    print $handle "2nd Window:\t\t\t", $ref->{"Window2"}, " seconds\n";

    print $handle "2nd Threshold:\t\t\t", $ref->{"Threshold2"}, "\n";

    print $handle scalar(@{$ref->{"Times"}}), " events observed at ";

    if ($ref->{"2ndPass"}) { 
      print $handle "(checking 2nd threshold):\n"; 
    } else { 
      print $handle "(checking 1st threshold):\n"; 
    }

    foreach $time (@{$ref->{"Times"}})
        { print $handle scalar(localtime($time)), "\n"; }

    print $handle "\n";

  }

  else { print $handle "Unknown operation type in the list\n\n"; }

}


# Parameters: -
# Action: save some information about the current state of the program
#         to dump file.

sub dump_data {

  my($i, $line, $key, $ref, $file, $event);
  my($time, $user, $system, $cuser, $csystem);
  my($name, %reported_names);

  # verify that dumpfile does not exist and open it

  if (-e $dumpfile) {
    log_msg(LOG_ERR, "Can't write to dumpfile: $dumpfile exists");
    return;
  }

  if (!open(DUMPFILE, ">$dumpfile")) {
    log_msg(LOG_ERR, "Can't open dumpfile $dumpfile ($!)");
    return;
  }

  $time = time();

  # print program info

  print DUMPFILE "Program information:\n";
  print DUMPFILE '=' x 60, "\n";

  print DUMPFILE "Program version: ", $SEC_VERSION, "\n";
  print DUMPFILE "Time of the start: ", 
                 scalar(localtime($startuptime)), "\n";
  print DUMPFILE "Time of the last configuration load: ", 
                 scalar(localtime($lastconfigload)), "\n";
  print DUMPFILE "Time of the dump: ", scalar(localtime($time)), "\n";
  print DUMPFILE "Program resource file: ", $rcfile_status, "\n";
  print DUMPFILE "Program options: ", $sec_options, "\n";

  print DUMPFILE "\n";

  # print environment info

  print DUMPFILE "Environment:\n";
  print DUMPFILE '=' x 60, "\n";

  foreach $key (sort(keys %ENV)) { 
    print DUMPFILE "$key=", $ENV{$key}, "\n"; 
  }

  print DUMPFILE "\n";

  # print performance statistics

  print DUMPFILE "Performance statistics:\n";
  print DUMPFILE '=' x 60, "\n";

  ($user, $system, $cuser, $csystem) = times();

  print DUMPFILE "Run time: ", $time - $startuptime, " seconds\n";
  print DUMPFILE "User time: $user seconds\n";
  print DUMPFILE "System time: $system seconds\n";
  print DUMPFILE "Child user time: $cuser seconds\n";
  print DUMPFILE "Child system time: $csystem seconds\n";
  print DUMPFILE "Processed input lines: $processedlines\n";

  print DUMPFILE "\n";

  # print rule usage statistics

  print DUMPFILE "Rule usage statistics:\n";
  print DUMPFILE '=' x 60, "\n";

  foreach $file (@conffiles) {

    $i = 1;
    print DUMPFILE "\nStatistics for the rules from $file\n";
    print DUMPFILE "(loaded at ", 
                    scalar(localtime($config_ltimes{$file})), ")\n";
    print DUMPFILE '-' x 60, "\n";

    foreach $ref (@{$configuration{$file}}) {
      print DUMPFILE "Rule $i at line ", $ref->{"LineNo"}, 
        " (", $ref->{"Desc"}, ") has matched ", 
          $ref->{"MatchCount"}, " events\n";
      ++$i;
    }

  }

  print DUMPFILE "\n";

  # print input sources

  print DUMPFILE "Input sources:\n";
  print DUMPFILE '=' x 60, "\n";

  foreach $file (@inputfiles) {

    print DUMPFILE $file, " ";

    if ($inputsrc{$file}->{"open"}) { 
      print DUMPFILE "(status: Open, "; 
    } else { 
      print DUMPFILE "(status: Closed, "; 
    }

    print DUMPFILE "received data: ", 
      $inputsrc{$file}->{"lines"}, " lines, ";

    if ($intcontexts) {
      print DUMPFILE "context: ", $inputsrc{$file}->{"context"};
    } else {
      print DUMPFILE "no context set";
    }

    print DUMPFILE ")\n";

  }

  print DUMPFILE "\n";

  # print content of input buffer

  print DUMPFILE "Content of input buffer (last $bufsize input lines):\n";
  print DUMPFILE '-' x 60, "\n";

  for ($i = $bufpos - $bufsize + 1; $i <= $bufpos; ++$i) {
    print DUMPFILE $input_buffer[$i], "\n";
  }

  print DUMPFILE '-' x 60, "\n";
  print DUMPFILE "\n";

  # print last $bufsize input sources

  print DUMPFILE "Last $bufsize input sources:\n";
  print DUMPFILE '-' x 60, "\n";

  for ($i = $bufpos - $bufsize + 1; $i <= $bufpos; ++$i) {
    if (defined($input_sources[$i])) {
      print DUMPFILE $input_sources[$i], "\n";
    } else {
      print DUMPFILE "SEC 'event' action\n";
    }
  }

  print DUMPFILE '-' x 60, "\n";
  print DUMPFILE "\n";

  # print content of pending event buffer

  $i = 0;
  print DUMPFILE "Pending events:\n";
  print DUMPFILE '=' x 60, "\n";

  foreach $ref (@pending_events) { 
    print DUMPFILE "Event: ", $ref->[1], "\n";
    print DUMPFILE "Will be created at: ", 
                   scalar(localtime($ref->[0])), "\n";
    print DUMPFILE "\n";
    ++$i;
  }

  print DUMPFILE "Total: $i elements\n\n";

  # print the list of active event correlation operations

  $i = 0;
  print DUMPFILE "List of event correlation operations:\n";
  print DUMPFILE '=' x 60, "\n";

  while (($key, $ref) = each(%corr_list)) { 
    print_element(*DUMPFILE, $key, $ref);
    print DUMPFILE '-' x 60, "\n";
    ++$i; 
  }

  print DUMPFILE "Total: $i elements\n\n";

  # print the list of active contexts

  $i = 0;
  %reported_names = ();
  print DUMPFILE "List of contexts:\n";
  print DUMPFILE '=' x 60, "\n";

  while (($key, $ref) = each(%context_list)) { 

    if (exists($reported_names{$key}))  { next; }

    foreach $name (@{$ref->{"Aliases"}}) {
      print DUMPFILE "Context Name: ", $name, "\n";
      $reported_names{$name} = 1;
    }

    print DUMPFILE "Creation Time: ", 
                   scalar(localtime($ref->{"Time"})), "\n";

    if ($ref->{"Window"}) {
      print DUMPFILE "Lifetime: ", $ref->{"Window"}, " seconds\n";
    } else {
      print DUMPFILE "Lifetime: infinite\n";
    }

    if (scalar(@{$ref->{"Action"}})) {
      print DUMPFILE "Action on delete: ", 
                     actionlist2str($ref->{"Action"});
      print DUMPFILE " (%s = ", $ref->{"Desc"}, ")\n";
    }

    if (scalar(@{$ref->{"Buffer"}})) {
      print DUMPFILE scalar(@{$ref->{"Buffer"}}), 
                     " events associated with context:\n";
      foreach $event (@{$ref->{"Buffer"}}) 
              { print DUMPFILE $event, "\n"; }
    }

    print DUMPFILE '-' x 60, "\n";
    ++$i;

  }
    
  print DUMPFILE "Total: $i elements\n\n";

  # print the list of running children

  $i = 0;
  print DUMPFILE "Child processes:\n";
  print DUMPFILE '=' x 60, "\n";

  while (($key, $ref) = each(%children)) { 
    print DUMPFILE "Child PID: ", $key, "\n";
    print DUMPFILE "Commandline started by child: ", $ref->{"cmd"}, "\n"; 
    print DUMPFILE '-' x 60, "\n";
    ++$i;
  }
    
  print DUMPFILE "Total: $i elements\n\n";

  # print the values of user-defined variables

  $i = 0;
  print DUMPFILE "User-defined variables:\n";
  print DUMPFILE '=' x 60, "\n";

  foreach $key (sort(keys %variables)) {
    if (defined($variables{$key})) {
      print DUMPFILE "%$key = '", $variables{$key}, "'\n";
    } else {
      print DUMPFILE "%$key = undef\n";
    }
    ++$i;
  }
    
  print DUMPFILE "Total: $i elements\n\n";

  close(DUMPFILE);

}


#################################################################
# Functions related to input handling and input buffer management
#################################################################


# Parameters: -
# Action: if the current size of the input buffer is different from 
#         $bufsize, change the size of the input buffer to $bufsize  
#         and set the global variable $bufpos accordingly

sub resize_input_buffer {

  my($cursize) = scalar(@input_buffer);
  my(@buf, $i, $diff);

  if ($cursize > $bufsize) {

    @input_buffer = @input_buffer[$bufpos - $bufsize + 1 .. $bufpos];
    @input_sources = @input_sources[$bufpos - $bufsize + 1 .. $bufpos];

    $bufpos = $bufsize - 1;

  } elsif ($cursize < $bufsize) {

    $diff = $bufsize - $cursize;
    for ($i = 0; $i < $diff; ++$i)  { $buf[$i] = ""; }

    @input_buffer = (@buf, @input_buffer[$bufpos - $cursize + 1 .. $bufpos]);
    @input_sources = (@buf, @input_sources[$bufpos - $cursize + 1 .. $bufpos]);

    $bufpos = $bufsize - 1;

  }

}


# Parameters: par1 - text of the SEC internal event
# Action: insert the SEC internal event par1 into the event buffer
#         and match it against the rulebase.

sub internal_event {

  my($text) = $_[0];
  my($context, $conffile);

  $context = "SEC_INTERNAL_EVENT";

  log_msg(LOG_INFO, "Creating SEC internal context '$context'");

  $context_list{$context} = { "Time" => time(), 
                              "Window" => 0, 
                              "Buffer" => [],
                              "Action" => [],
                              "Desc" => "SEC internal",
                              "Aliases" => [ $context ] };

  log_msg(LOG_INFO, "Creating SEC internal event '$text'");

  $bufpos = ($bufpos + 1) % $bufsize;
  $input_buffer[$bufpos] = $text;
  $input_sources[$bufpos] = undef;

  foreach $conffile (@maincfiles)  { process_rules($conffile); }

  ++$processedlines;

  log_msg(LOG_INFO, "Deleting SEC internal context '$context'");

  delete $context_list{$context};

}


# Parameters: par1 - process ID
# Action: read available data from process par1 and create events.

sub consume_pipe {

  my($pid) = $_[0];
  my($rin, $ret, $pos, $nbytes, $event);

  for (;;) {

    # poll the pipe with select()

    $rin = '';
    vec($rin, fileno($children{$pid}->{"fh"}), 1) = 1;
    $ret = select($rin, undef, undef, 0);

    # if select() failed because of the caught signal, try again,
    # otherwise close the pipe and quit the read-loop;
    # if select() returned 0, no data is available, so quit the read-loop

    if (!defined($ret)  ||  $ret < 0) {

      if ($! == EINTR)  { next; }

      log_msg(LOG_ERR, 
              "Process $pid pipe select error ($!), closing the pipe"); 
      close($children{$pid}->{"fh"});
      $children{$pid}->{"open"} = 0;
      last; 

    } elsif ($ret == 0)  { last; }

    # try to read from the pipe

    $nbytes = sysread($children{$pid}->{"fh"}, 
                      $children{$pid}->{"buffer"},
                      $blocksize, length($children{$pid}->{"buffer"}));

    # if sysread() failed and the reason was other than a caught signal,
    # close the pipe and quit the read-loop;
    # if sysread() failed because of a caught signal, continue (posix
    # allows read(2) to be interrupted by a signal and return -1, with
    # some bytes already been read into read buffer);
    # if sysread() returned 0, the other end has closed the pipe, so close
    # our end of the pipe and quit the read-loop

    if (!defined($nbytes)) { 

      if ($! != EINTR) { 

        log_msg(LOG_ERR, "Process $pid pipe IO error ($!), closing the pipe"); 
        close($children{$pid}->{"fh"});
        $children{$pid}->{"open"} = 0;
        last;

      }

    } elsif ($nbytes == 0) { 

      close($children{$pid}->{"fh"});
      $children{$pid}->{"open"} = 0;
      last; 

    }

    # create all lines of pipe buffer as events, except the last one
    # which could be a partial line with its 2nd part still not written

    for (;;) {

      $pos = index($children{$pid}->{"buffer"}, "\n");
      if ($pos == -1)  { last; }

      $event = substr($children{$pid}->{"buffer"}, 0, $pos);
      substr($children{$pid}->{"buffer"}, 0, $pos + 1) = "";

      log_msg(LOG_DEBUG, 
              "Creating event '$event' (received from child $pid)");
      push @events, $event;

    }

  }

  # if the child pipe has been closed but the pipe buffer still contains
  # data (bytes with no terminating newline), create an event from this data

  if (!$children{$pid}->{"open"}  &&  length($children{$pid}->{"buffer"})) {

    $event = $children{$pid}->{"buffer"};
    log_msg(LOG_DEBUG, "Creating event '$event' (received from child $pid)");
    push @events, $event;

  }

}


# Parameters: -
# Action: check the status of SEC child processes and process their output

sub check_children {

  my($pid, $exitcode);

  # if the child was started by 'spawn' action, gather the child
  # standard output and create events (if child has more than PIPE_BUF
  # bytes to write, we must start reading from pipe before child 
  # termination, otherwise child would block)

  while ($pid = each(%children)) { 
    if ($children{$pid}->{"open"})  { consume_pipe($pid); }
  }

  # get the exit status of every terminated child process.

  for (;;) {

    # get the exit status of next terminated child process and
    # quit the loop if there are no more deceased children
    # waitpid will return -1 if there are no deceased children (or no
    # children at all) at the moment; on some platforms, 0 means that 
    # there are children, but none of them is deceased at the moment.
    # Process ID can be a positive (UNIX) or negative (windows) integer.

    $pid = waitpid(-1, &WNOHANG);
    if ($pid == -1 || $pid == 0) { last; }

    # check if the child process has really exited (and not just stopped).
    # This check will be skipped on Windows which does not have a valid
    # implementation of WIFEXITED macro.

    if ($WIN32 || WIFEXITED($?) || WIFSIGNALED($?)) {

      # find the child exit code

      $exitcode = $? >> 8;

      # if the terminated child was started as a part of 'spawn'
      # action and its pipe has not been emptied yet, do it now

      if ($children{$pid}->{"open"})  { consume_pipe($pid); }

      # if the child exit code is zero and the child was started as 
      # a part of SINGLE_W_SCRIPT rule, execute action list 'Action'

      if (!$exitcode  &&  defined($children{$pid}->{"Desc"})) {

        log_msg(LOG_DEBUG, "Child $pid terminated with exitcode 0");

        execute_actionlist($children{$pid}->{"Action"},
                           $children{$pid}->{"Desc"});

      # if the child exit code is non-zero and the child was started as 
      # a part of SINGLE_W_SCRIPT rule, execute action list 'Action2'

      } elsif ($exitcode  &&  defined($children{$pid}->{"Desc"})) {

        log_msg(LOG_DEBUG,
                "Child $pid terminated with non-zero exitcode $exitcode");

        execute_actionlist($children{$pid}->{"Action2"},
                           $children{$pid}->{"Desc"});

      # if the child exit code is non-zero, log a message

      } elsif ($exitcode) {
        log_msg(LOG_WARN,
                "Child $pid terminated with non-zero exitcode $exitcode (",
                $children{$pid}->{"cmd"}, ")");
      }

      delete $children{$pid};

    }

  }

}


# Parameters: par1 - name of the input file
#             par2 - file position
# Action: Input file will be opened and file position will be moved to 
#         position par2 (-1 means "seek EOF" and 0 means "don't seek at all").
#         Return the filehandle of the input file, or 'undef' if open failed.

sub open_input_file {

  my($file) = $_[0];
  my($fpos) = $_[1];
  my($flags);
  local *INPUT;   # we need to use 'local *', since each time we enter
                  # this procedure a new filehandle must be created, that
                  # will be returned from this procedure for external use

  # if input is stdin, duplicate it

  if ($file eq "-") {

    if ($WIN32) {
      log_msg(LOG_ERR, "Stdin is not supported as input on Win32");
      return undef;
    }

    while (!open(INPUT, "<&STDIN")) {
      if ($! == EINTR)  { next; }
      log_msg(LOG_ERR, "Can't dup stdin ($!)"); 
      return undef;
    }

  }

  # if input file is a regular file, open it for reading

  elsif (-f $file) {

    while (!sysopen(INPUT, $file, O_RDONLY)) {
      if ($! == EINTR)  { next; }
      log_msg(LOG_ERR, "Can't open input file $file ($!)"); 
      return undef;
    }

  }

  # if input file is a named pipe, open it both for reading and writing
  # (the open would block if there are no writers at the moment, so the
  # process pretends to be a writer)

  elsif (-p $file) {

    if ($WIN32) {
      log_msg(LOG_ERR, "Named pipe is not supported as input on Win32");
      return undef;
    }

    while (!sysopen(INPUT, $file, O_RDWR)) {
      if ($! == EINTR)  { next; }
      log_msg(LOG_ERR, "Can't open input file $file ($!)"); 
      return undef;
    }

  }

  # if input file does not exist, log a debug message if -reopen_timeout
  # option was given, otherwise log an error message

  elsif (! -e $file) {

    if ($reopen_timeout) {
      log_msg(LOG_DEBUG, "Input file $file has not been created yet");
    } else {
      log_msg(LOG_ERR, "Input file $file does not exist!");
    }

    return undef;

  }

  # input file is of unsupported type

  else {
    log_msg(LOG_ERR, "Input file $file is of unsupported type!");
    return undef;
  }

  # if INPUT filehandle is connected to a regular file
  # and $fpos == -1 or $fpos > 0, seek the given position in the file

  if (-f INPUT) {

    if ($fpos == -1) {

      while (!sysseek(INPUT, 0, SEEK_END)) {
        if ($! == EINTR)  { next; }
        log_msg(LOG_ERR, "Can't seek EOF in input file $file ($!)");
        close(INPUT);
        return undef;
      }

    } elsif ($fpos > 0) {

      while (!sysseek(INPUT, $fpos, SEEK_SET)) {
        if ($! == EINTR)  { next; }
        log_msg(LOG_ERR, "Can't seek position $fpos in input file $file ($!)");
        close(INPUT);
        return undef;
      }

    }

  }

  return *INPUT;

}


# Parameters: par1 - file position
# Action: evaluate the inputfile patterns given in commandline, form the 
#         list of inputfiles and save it to global array @inputfiles. Each
#         input file will then be opened and file position will be moved to
#         position par1 (-1 means "seek EOF" and 0 means "don't seek at all").
#         If -intcontexts option is active, also set up internal contexts.

sub open_input {

  my($fpos) = $_[0];
  my($filepat, $pattern, $cmdline_context, $context);
  my($inputfile, @files, $time, $fh);

  # Initialize (or clean) global arrays %inputsrc and @inputfiles
  # (the keys for %inputsrc are members of global array @inputfiles)
 
  %inputsrc = ();
  @inputfiles = ();

  # Initialize (or clean) the read buffer

  @readbuffer = ();

  # Form the list of configuration files, save it to global array
  # @inputfiles, and open the files

  $time = time();

  foreach $filepat (@inputfilepat) { 

    # check if the input file pattern has a context associated with it,
    # and if it does, force the -intcontexts option

    if ($filepat =~ /^(.+)=(\S+)$/) {
      $pattern = $1;
      $cmdline_context = $2;
      $intcontexts = 1;
    } else { 
      $pattern = $filepat;
      $cmdline_context = undef; 
    }

    # interpret the pattern, and open the files that correspond to a pattern

    @files = glob($pattern);

    foreach $inputfile (@files) {

      $fh = open_input_file($inputfile, $fpos);

      if (defined($cmdline_context)) { 
        $context = $cmdline_context;
      } else  { 
        $context = "_FILE_EVENT_$inputfile"; 
      }

      $inputsrc{$inputfile} = { "fh" => $fh,
                                "open" => defined($fh),
                                "buffer" => "",
                                "scriptexec" => 0,
                                "checktime" => 0,
                                "lastopen" => $time,
                                "lastread" => $time,
                                "lines" => 0,
                                "context" => $context };

      if (!defined($fh)  &&  $inputfile ne "-"  &&  ! -e $inputfile) {
        $inputsrc{$inputfile}->{"read_from_start"} = 1;
      }

    }

    push @inputfiles, @files;

  }

  # if -intcontexts option is active, set up internal contexts

  if ($intcontexts) {

    %int_contexts = ();

    foreach $inputfile (@inputfiles) {

      $context = $inputsrc{$inputfile}->{"context"};

      if (exists($int_contexts{$context}))  { next; }

      $int_contexts{$context} = { "Time" => $time,
                                  "Window" => 0,
                                  "Buffer" => [],
                                  "Action" => [],
                                  "Desc" => "SEC internal",
                                  "Aliases" => [ $context ] };

    }

    $context = "_INTERNAL_EVENT";

    $int_contexts{$context} = { "Time" => $time,
                                "Window" => 0,
                                "Buffer" => [],
                                "Action" => [],
                                "Desc" => "SEC internal",
                                "Aliases" => [ $context ] };

  }

}


# Parameters: par1 - name of the input file
# Action: check if input file has been removed, recreated or truncated.
#         Return 1 if input file has changed and should be reopened; 
#         return 0 if the file has not changed or should not be
#         reopened right now. If system calls of this procedure
#         are interrupted by a signal, return 0 also. If system call
#         on the input file fails, close the file and return undef.

sub input_shuffled {

  my($file) = $_[0];
  my(@oldstat, @newstat, $fpos);

  # standard input is always intact (it can't be recreated or truncated)

  if ($file eq "-")  { return 0; }

  # stat the input filehandle and exit if stat fails

  @oldstat = stat($inputsrc{$file}->{"fh"});

  if (!scalar(@oldstat)) { 

    if ($! == EINTR)  { return 0; }

    log_msg(LOG_ERR, 
      "Can't stat filehandle of input file $file ($!), closing the file");

    close($inputsrc{$file}->{"fh"});
    $inputsrc{$file}->{"open"} = 0;

    return undef;

  }

  # stat the input file and return 0 if stat fails (e.g., input file has 
  # been removed and not recreated yet, so we can't reopen it now)

  @newstat = stat($file);

  if (!scalar(@newstat))  { return 0; }

  # check if i-node numbers of filehandle and input file are different
  # (this check will be skipped on Windows).

  if (!$WIN32 && 
      ($oldstat[0] != $newstat[0] || $oldstat[1] != $newstat[1])) { 
    log_msg(LOG_NOTICE, "Input file $file has been recreated");
    return 1; 
  }

  # Check if file size has decreased

  if (-f $inputsrc{$file}->{"fh"}) {

    $fpos = sysseek($inputsrc{$file}->{"fh"}, 0, SEEK_CUR);

    if (!defined($fpos)) {

      if ($! == EINTR)  { return 0; }

      log_msg(LOG_ERR, 
        "Can't seek filehandle of input file $file ($!), closing the file");

      close($inputsrc{$file}->{"fh"});
      $inputsrc{$file}->{"open"} = 0;

      return undef;

    }

    if ($fpos > $newstat[7]) { 
      log_msg(LOG_NOTICE, "Input file $file has been truncated");
      return 1; 
    }

  }

  return 0;

}


# Parameters: par1 - name of the input file
# Action: read next line from the input file and return it (without '\n' at 
#         the end of the line). If the file has no complete line available, 
#         undef is returned. If read system call fails, or returns EOF and 
#         -notail mode is active, the file is closed and undef is returned.

sub read_line_from_file {

  my($file) = $_[0];
  my($pos, $line, $rin, $ret, $nbytes);

  # if there is a complete line in the read buffer of the file (i.e., the 
  # read buffer contains at least one newline symbol), read line from there

  $pos = index($inputsrc{$file}->{"buffer"}, "\n");

  if ($pos != -1) {
    $line = substr($inputsrc{$file}->{"buffer"}, 0, $pos);
    substr($inputsrc{$file}->{"buffer"}, 0, $pos + 1) = "";
    return $line;
  }

  if (-f $inputsrc{$file}->{"fh"}) {

    # try to read data from a regular file

    $nbytes = sysread($inputsrc{$file}->{"fh"}, 
                      $inputsrc{$file}->{"buffer"},
                      $blocksize, length($inputsrc{$file}->{"buffer"}));

    # check the exit value from sysread() that was saved to $nbytes:
    # if $nbytes == undef, sysread() failed;
    # if $nbytes == 0, we have reached EOF (no more data available);
    # otherwise ($nbytes > 0) sysread() succeeded

    if (!defined($nbytes)) { 

      # check if sysread() failed because of the caught signal (posix
      # allows read(2) to be interrupted by a signal and return -1, with
      # some bytes already been read into read buffer); if sysread() failed
      # because of some other reason, close the file and return undef

      if ($! != EINTR) { 

        log_msg(LOG_ERR, "Input file $file IO error ($!), closing the file");

        close($inputsrc{$file}->{"fh"});
        $inputsrc{$file}->{"open"} = 0;

        return undef;

      } 

    } elsif ($nbytes == 0) { 

      # if we have reached EOF and -tail mode is set, return undef; if 
      # -notail mode is active, close the file, and if the file buffer is not 
      # empty, return its content (bytes between the last newline in the file 
      # and EOF), otherwise return undef

      if ($tail)  { return undef; }

      close($inputsrc{$file}->{"fh"});
      $inputsrc{$file}->{"open"} = 0;

      $line = $inputsrc{$file}->{"buffer"};
      $inputsrc{$file}->{"buffer"} = "";

      if (length($line))  { return $line; }  else { return undef; }
      
    }

  } else {

    # poll the input pipe for new data with select()

    $rin = '';
    vec($rin, fileno($inputsrc{$file}->{"fh"}), 1) = 1;
    $ret = select($rin, undef, undef, 0);

    if (!defined($ret)  ||  $ret < 0) {

      # if select() failed because of the caught signal, return undef,
      # otherwise close the file and return undef

      if ($! == EINTR)  { return undef; }

      log_msg(LOG_ERR, 
              "Input file $file select error ($!), closing the file");

      close($inputsrc{$file}->{"fh"});
      $inputsrc{$file}->{"open"} = 0;

      return undef;

    } elsif ($ret == 0) {

      # if we have reached EOF and -tail mode is set, return undef; if 
      # -notail mode is active, close the file, and if the file buffer is not 
      # empty, return its content (bytes between the last newline in the file 
      # and EOF), otherwise return undef

      if ($tail)  { return undef; }

      close($inputsrc{$file}->{"fh"});
      $inputsrc{$file}->{"open"} = 0;

      $line = $inputsrc{$file}->{"buffer"};
      $inputsrc{$file}->{"buffer"} = "";

      if (length($line))  { return $line; }  else { return undef; }

    }

    # try to read from the pipe

    $nbytes = sysread($inputsrc{$file}->{"fh"}, 
                      $inputsrc{$file}->{"buffer"}, 
                      $blocksize, length($inputsrc{$file}->{"buffer"}));

    # check the exit value from sysread() that was saved to $nbytes:
    # if $nbytes == undef, sysread() failed;
    # if $nbytes == 0, we have reached EOF (no more data available);
    # otherwise ($nbytes > 0) sysread() succeeded

    if (!defined($nbytes)) { 

      # check if sysread() failed because of the caught signal (posix
      # allows read(2) to be interrupted by a signal and return -1, with
      # some bytes already been read into read buffer); if sysread() failed
      # because of some other reason, log an error message and return undef

      if ($! != EINTR) { 

        log_msg(LOG_ERR, "Input file $file IO error ($!), closing the file");

        close($inputsrc{$file}->{"fh"});
        $inputsrc{$file}->{"open"} = 0;

        return undef;

      } 

    } elsif ($nbytes == 0) { 

      # if sysread() returns 0, that signals that there are no writers
      # on the pipe anymore, and from now on select() always claims that 
      # there is some data (EOF) to be read (with named pipe we should 
      # never reach that condition, since we have opened it in RW-mode)

      log_msg(LOG_ERR, 
        "Input file $file IO error (unknown pipe error), closing the file"); 

      close($inputsrc{$file}->{"fh"});
      $inputsrc{$file}->{"open"} = 0;

      return undef;

    }

  }

  # if the read buffer contains a newline, cut the first line from the 
  # read buffer and return it, otherwise return undef (even if there are 
  # some bytes in the buffer)

  $pos = index($inputsrc{$file}->{"buffer"}, "\n");

  if ($pos != -1) {
    $line = substr($inputsrc{$file}->{"buffer"}, 0, $pos);
    substr($inputsrc{$file}->{"buffer"}, 0, $pos + 1) = "";
    return $line;
  }

  return undef;

}


# Parameters: par1 - variable where the input line is saved
#             par2 - variable where the input file name is saved
# Action: attempt to read next line from each input file, and store the
#         received lines with corresponding input file names to the read 
#         buffer. Return the first line from the read buffer, with par1 set 
#         to line and par2 set to file name. If there were no new lines in 
#         input files, par1 is set to undef but par2 reflects the status of 
#         input files: value 1 means that at least one of the input files has 
#         new data available (although no complete line), value 0 means that 
#         no data were added to any of the input files since the last poll.

sub read_line {

  my($line, $file); 
  my($time, $len, $newdata);

  # check all input files and store new data to the read buffer

  $newdata = 0;
  $time = time();

  foreach $file (@inputfiles) {

    # if the check timer for the file has not expired yet, skip the file

    if ($check_timeout && $time < $inputsrc{$file}->{"checktime"}) { next; }

    # before reading, memorize the number of bytes in the read cache

    $len = length($inputsrc{$file}->{"buffer"});

    # if the input file is open, read a line from it; if the input file
    # is closed, treat it as an open file with no new data available

    if ($inputsrc{$file}->{"open"}) { 
      $line = read_line_from_file($file);
    } else { 
      $line = undef;
    }

    if (defined($line)) {

      # if we received a new line, write the line to the read buffer; also 
      # update time-related variables and call external script, if necessary

      push @readbuffer, $line;
      push @readbuffer, $file;

      if ($input_timeout)  { $inputsrc{$file}->{"lastread"} = $time; }

      if ($inputsrc{$file}->{"scriptexec"}) {

        log_msg(LOG_INFO,
                "Input received, executing script $timeout_script 0 $file");

        shell_cmd("$timeout_script 0 $file");
        $inputsrc{$file}->{"scriptexec"} = 0;

      }

    } 

    else {

      # if we were unable to obtain a complete line from the file but
      # new bytes were stored to the read cache, don't set the check
      # timer and skip shuffle and timeout checks

      if ($len < length($inputsrc{$file}->{"buffer"})) { 
        $newdata = 1; next; 
      }

      # if there were no new bytes in the file and -notail mode is active, 
      # don't set the check timer and skip shuffle and timeout checks (i.e., 
      # -input_timeout, -timeout_script, -reopen_timeout, and -check_timeout 
      # options are ignored when -notail is set)

      if (!$tail)  { next; }

      # if -check_timeout is set, poll the file after $check_timeout seconds

      if ($check_timeout) {
        $inputsrc{$file}->{"checktime"} = $time + $check_timeout;
      }

      # if there were no new bytes in the file and it has been shuffled,
      # reopen the file and start to process it from the beginning

      if ($inputsrc{$file}->{"open"}  &&  input_shuffled($file)) {

        log_msg(LOG_NOTICE,
                "Shuffled $file, reopening and processing from the start");

        close($inputsrc{$file}->{"fh"});

        $inputsrc{$file}->{"fh"} = open_input_file($file, 0);
        $inputsrc{$file}->{"open"} = defined($inputsrc{$file}->{"fh"});

        if ($reopen_timeout)  { $inputsrc{$file}->{"lastopen"} = $time; }

      }

      # if we have waited for new bytes for more than $input_timeout
      # seconds, execute external script $timeout_script with commandline
      # parameters "1 <filename>"

      if ($input_timeout  &&  !$inputsrc{$file}->{"scriptexec"}  &&
          $time - $inputsrc{$file}->{"lastread"} >= $input_timeout) {

        log_msg(LOG_INFO,
                "No input, executing script $timeout_script 1 $file");

        shell_cmd("$timeout_script 1 $file");
        $inputsrc{$file}->{"scriptexec"} = 1;

      }

      # if we have waited for new bytes for more than $reopen_timeout
      # seconds, reopen the input file

      if ($reopen_timeout  &&  !$inputsrc{$file}->{"open"}  &&
          $time - $inputsrc{$file}->{"lastopen"} >= $reopen_timeout) {

        log_msg(LOG_DEBUG, "Attempting to (re)open $file");

        if (exists($inputsrc{$file}->{"read_from_start"})) {

          $inputsrc{$file}->{"fh"} = open_input_file($file, 0);

          if (defined($inputsrc{$file}->{"fh"})) {
            delete $inputsrc{$file}->{"read_from_start"};
          }

        } else {
          $inputsrc{$file}->{"fh"} = open_input_file($file, -1);
        }

        $inputsrc{$file}->{"open"} = defined($inputsrc{$file}->{"fh"});
        $inputsrc{$file}->{"lastopen"} = $time;

      }

    }

  }
  
  # if we succeeded to read new data and write it to the read buffer, 
  # return the first line from the buffer; otherwise return undef

  if (scalar(@readbuffer)) {
    $_[0] = shift @readbuffer;
    $_[1] = shift @readbuffer;
  } else {
    $_[0] = undef;
    $_[1] = $newdata;
  }

}


###################################################
# Functions related to signal reception and sending
###################################################


# Parameters: -
# Action: check whether signals have arrived and process them

sub check_signals {

  my($file, @file_list);
  my(@allkeys, @keys);
  my($templevel);

  # if SIGHUP has arrived, do a full restart of SEC 

  if ($refresh) {

    log_msg(LOG_NOTICE, "SIGHUP received: full restart of SEC");

    # terminate child processes

    child_cleanup();

    # clear correlation operations, contexts and user-defined variables

    %corr_list = ();
    %context_list = (); 
    %variables = ();

    # clear pending events

    @pending_events = ();

    # close input sources

    foreach $file (@inputfiles) {
      if ($inputsrc{$file}->{"open"})  { close($inputsrc{$file}->{"fh"}); }
    }

    # close the logfile and connection to the system logger

    if ($logfile)  { close(LOGFILE); }
    if ($syslogf)  { eval { Sys::Syslog::closelog() }; }

    # now the SEC internal state has been cleared, input sources and log 
    # handles closed - re-read SEC command line and resource file options

    read_options();

    # open the logfile and connection to the system logger

    if ($logfile)  { open_logfile($logfile); }
    if ($syslogf)  { open_syslog($syslogf); }

    # read configuration from SEC rule files

    read_config();

    # open input sources and resize the input buffer

    open_input(-1);
    resize_input_buffer();

    # if -intevents flag was specified, generate the SEC_RESTART event

    if ($intevents)  { internal_event("SEC_RESTART"); }

    # set the signal flag back to zero

    $refresh = 0;

  }

  # if SIGABRT has arrived, do a soft restart of SEC 

  if ($softrefresh) {

    log_msg(LOG_NOTICE, "SIGABRT received: soft restart of SEC");

    # close input sources

    foreach $file (@inputfiles) {
      if ($inputsrc{$file}->{"open"})  { close($inputsrc{$file}->{"fh"}); }
    }

    # close the logfile and connection to the system logger

    if ($logfile)  { close(LOGFILE); }
    if ($syslogf)  { eval { Sys::Syslog::closelog() }; }

    # now input sources and log handles have been closed -  
    # re-read SEC command line and resource file options

    read_options();

    # open the logfile and connection to the system logger

    if ($logfile)  { open_logfile($logfile); }
    if ($syslogf)  { open_syslog($syslogf); }

    # read configuration from SEC rule files that are either new or
    # have been modified, and store to the array @file_list the names
    # of files that have been modified or removed

    soft_read_config(\@file_list);

    # clear event correlation operations related to the modified and 
    # removed configuration files

    @allkeys = keys %corr_list;

    foreach $file (@file_list) {
      @keys = grep($corr_list{$_}->{"File"} eq $file, @allkeys);
      delete @corr_list{@keys};
    }

    # open input sources and resize the input buffer

    open_input(-1);
    resize_input_buffer();

    # if -intevents flag was specified, generate the SEC_SOFTRESTART event

    if ($intevents)  { internal_event("SEC_SOFTRESTART"); }

    # set the signal flag back to zero

    $softrefresh = 0;

  }

  # if SIGUSR1 has arrived, create the dump file

  if ($dumpdata) {

    log_msg(LOG_NOTICE, "SIGUSR1 received: dumping data to $dumpfile");

    # write info about SEC state to the dump file

    dump_data();

    # set the signal flag back to zero

    $dumpdata = 0;

  }

  # if SIGUSR2 has arrived, restart logging

  if ($openlog) {

    log_msg(LOG_NOTICE, "SIGUSR2 received: restarting logging");

    # reopen the logfile and connection to the system logger

    if ($logfile) {
      close(LOGFILE);
      open_logfile($logfile);
    }
 
    if ($syslogf) {
      eval { Sys::Syslog::closelog() };
      open_syslog($syslogf);
    }

    # set the signal flag back to zero

    $openlog = 0;

  }

  # if SIGINT has arrived, set the debug level to a new value

  if ($debuglevelset) {

    # if the current debuglevel is 6, roll over to 1,
    # otherwise increase the current level by 1

    $templevel = ($debuglevel == 6)?1:$debuglevel+1;

    log_msg(LOG_NOTICE, "SIGINT received: setting debuglevel to $templevel");

    $debuglevel = $templevel;

    # set the signal flag back to zero

    $debuglevelset = 0;

  }

  # if SIGTERM has arrived, shutdown SEC

  if ($terminate) {

    log_msg(LOG_NOTICE, "SIGTERM received: shutting down SEC");

    # If -intevents flag was specified, generate the SEC_SHUTDOWN event.
    # Note that the $terminate flag will be set back to zero, as if
    # SEC_SHUTDOWN event was generated before SIGTERM under normal circum-
    # stances (when $terminate is set, SEC does not fork any new processes). 
    # Note also, that after generating SEC_SHUTDOWN event, SEC will sleep for 
    # TERMTIMEOUT seconds, so that child processes that were triggered by 
    # SEC_SHUTDOWN have time to create a signal handler for SIGTERM if needed.

    if ($intevents) { 
      $terminate = 0;
      internal_event("SEC_SHUTDOWN"); 
      sleep(TERMTIMEOUT);
    }

    # final shutdown procedures

    child_cleanup();
    exit(0);

  }

}


# Parameters: -
# Action: terminate child processes

sub child_cleanup {

  my($pid);

  while($pid = each(%children)) { 
    log_msg(LOG_NOTICE, "Sending SIGTERM to process $pid");
    kill('TERM', $pid); 
  }

}


# Parameters: -
# Action: on arrival of SIGHUP set flag $refresh

sub hup_handler {

  $SIG{HUP} = \&hup_handler;
  $refresh = 1;

}               


# Parameters: -
# Action: on arrival of SIGABRT set flag $softrefresh

sub abrt_handler {

  $SIG{ABRT} = \&abrt_handler;
  $softrefresh = 1;

}               


# Parameters: -
# Action: on arrival of SIGUSR1 set flag $dumpdata

sub usr1_handler {

  $SIG{USR1} = \&usr1_handler;
  $dumpdata = 1;

}               


# Parameters: -
# Action: on arrival of SIGUSR2 set flag $openlog

sub usr2_handler {

  $SIG{USR2} = \&usr2_handler;
  $openlog = 1;

}               


# Parameters: -
# Action: on arrival of SIGINT set flag $debuglevelset

sub int_handler {

  $SIG{INT} = \&int_handler;
  $debuglevelset = 1;

}               


# Parameters: -
# Action: on arrival of SIGTERM clean things up and exit

sub term_handler {

  $SIG{TERM} = \&term_handler;
  $terminate = 1;

}               


##########################################################
# Functions related to daemonization and option processing
##########################################################


# Parameters: -
# Action: daemonize the process

sub daemonize {

  local $SIG{HUP} = 'IGNORE'; # ignore SIGHUP inside this function
  my($pid);

  # -detach is not supported on Windows

  if ($WIN32) {
    log_msg(LOG_CRIT, "'-detach' option is not supported on Win32");
    exit(1);
  }

  # if stdin was specified as input, we can't become a daemon

  if (grep($_ eq "-", @inputfiles)) {
    log_msg(LOG_CRIT,
            "Can't become a daemon (stdin is specified as input), exiting!");
    exit(1);
  }

  # fork a new copy of the process and exit from the parent

  $pid = fork();

  if (!defined($pid)) {
    log_msg(LOG_CRIT,
            "Can't fork a new process for daemonization ($!), exiting!");
    exit(1);
  }

  if ($pid)  { exit(0); }

  # create a new session and process group

  if (!POSIX::setsid()) {
    log_msg(LOG_CRIT, "Can't start a new session ($!), exiting!");
    exit(1);
  }

  # fork a second copy of the process and exit from the parent - the parent
  # as a session leader might deliver the SIGHUP signal to child when it 
  # exits, but SIGHUP is ignored inside this function

  $pid = fork();

  if (!defined($pid)) {
    log_msg(LOG_CRIT,
            "Can't fork a new process for daemonization ($!), exiting!");
    exit(1);
  }

  if ($pid)  { exit(0); }

  # connect stdin, stdout, and stderr to /dev/null

  if (!open(STDIN, '/dev/null')) {
    log_msg(LOG_CRIT, "Can't connect stdin to /dev/null ($!), exiting!");
    exit(1);
  }

  if (!open(STDOUT, '>/dev/null')) {
    log_msg(LOG_CRIT, "Can't connect stdout to /dev/null ($!), exiting!");
    exit(1);
  }

  if (!open(STDERR, '>&STDOUT')) {
    log_msg(LOG_CRIT, 
            "Can't connect stderr to stdout with dup ($!), exiting!");
    exit(1);
  }

  log_msg(LOG_DEBUG, "Daemonization complete");

}


# Parameters: -
# Action: read and process options from command line and resource file

sub read_options {

  my(@argv_backup, $option);

  # back up the @ARGV array

  @argv_backup = @ARGV;

  # open the file pointed by the SECRC environment variable and
  # read options from that file; empty lines and lines starting
  # with the #-symbol are ignored, rest of the lines are treated
  # as SEC command line options and pushed into @ARGV with
  # leading and trailing whitespace removed

  if (exists($ENV{"SECRC"})) {

    if (open(SECRC, $ENV{"SECRC"})) {

      while (<SECRC>) {
        if (/^\s*(.*\S)/) { 
          $option = $1;
          if (index($option, '#') == 0) { next; }
          push @ARGV, $option;
        }
      }

      close(SECRC);
      $rcfile_status = $ENV{"SECRC"};

    } else { 
      $rcfile_status = $ENV{"SECRC"} . " - open failed ($!)"; 
    }

  } else { $rcfile_status = "none"; }

  # set the $sec_options global variable

  $sec_options = join(" ", @ARGV);

  # (re)set option variables to default values

  @conffilepat = ();
  @inputfilepat = ();
  $input_timeout = 0;
  $timeout_script = "";
  $reopen_timeout = 0;
  $check_timeout = 0;
  $poll_timeout = 0.1;
  $blocksize = 1024;
  $bufsize = 10;
  $evstoresize = 0;
  $cleantime = 1;
  $logfile = "";
  $syslogf = "";
  $debuglevel = 6; 
  $pidfile = "";
  $dumpfile = "/tmp/sec.dump";
  $quoting = 0;
  $tail = 1;
  $fromstart = 0;
  $detach = 0;
  $intevents = 0;
  $intcontexts = 0;
  $testonly = 0;
  $help = 0;
  $version = 0;

  # parse the options given in command line and in SEC resource file

  GetOptions( "conf=s" => \@conffilepat,
              "input=s" => \@inputfilepat,
              "input_timeout=i" => \$input_timeout,
              "timeout_script=s" => \$timeout_script,
              "reopen_timeout=i" => \$reopen_timeout,
              "check_timeout=i" => \$check_timeout,
              "poll_timeout=f" => \$poll_timeout,
              "blocksize=i" => \$blocksize,
              "bufsize=i" => \$bufsize,
              "evstoresize=i" => \$evstoresize,
              "cleantime=i" => \$cleantime,
              "log=s" => \$logfile,
              "syslog=s" => \$syslogf,
              "debug=i", \$debuglevel,
              "pid=s" => \$pidfile,
              "dump=s" => \$dumpfile,
              "quoting!" => \$quoting,
              "tail!" => \$tail,
              "fromstart!" => \$fromstart,
              "detach!" => \$detach,
              "intevents!" => \$intevents,
              "intcontexts!" => \$intcontexts,
              "testonly!" => \$testonly,
              "help|?" => \$help,
              "version" => \$version );

  # check the values received from command line and resource file
  # and set option variables back to defaults, if necessary

  if (!$timeout_script  ||  $input_timeout < 0)  { $input_timeout = 0; }
  if ($reopen_timeout < 0)  { $reopen_timeout = 0; }
  if ($check_timeout < 0)  { $check_timeout = 0; }
  if ($poll_timeout < 0)  { $poll_timeout = 0.1; }
  if ($blocksize <= 0)  { $blocksize = 1024; }
  if ($bufsize <= 0)  { $bufsize = 10; }
  if ($evstoresize < 0)  { $evstoresize = 0; }
  if ($cleantime < 0)  { $cleantime = 1; }
  if ($debuglevel < 1  ||  $debuglevel > 6)  { $debuglevel = 6; }

  # restore the @ARGV array

  @ARGV = @argv_backup;

}


##################################################################
# ------------------------- MAIN PROGRAM -------------------------
##################################################################

### Read and process SEC options from command line and resource file

read_options();

### If requested, print usage/version info and exit

if ($help) { 
  print $SEC_USAGE; 
  exit(0); 
}

if ($version) { 
  print $SEC_VERSION, "\n";
  print $SEC_COPYRIGHT, "\n";
  print $SEC_LICENSE;
  exit(0); 
}

### Open logfile

if ($logfile)  { open_logfile($logfile); }
if ($syslogf)  { open_syslog($syslogf); }

log_msg(LOG_NOTICE, "$SEC_VERSION");

# If -detach flag was specified, chdir to / for not disturbing future 
# unmount of current filesystem. Must be done before read_config() to 
# receive error messages about scripts that would not be found at runtime

if ($detach) { 
  log_msg(LOG_NOTICE, "Changing working directory to /");
  chdir('/'); 
}

### Read in configuration

my $config_ok = read_config();

if ($testonly) {
  if ($config_ok)  { exit(0); }  else { exit(1); }
}

### Open input sources

if ($fromstart) { open_input(0); } 
elsif ($tail) { open_input(-1); } 
else { open_input(0); }

### Daemonize the process, if -detach flag was specified

if ($detach)  { daemonize(); }

### Create pidfile - must be done after daemonization

if ($pidfile) {
  if (open(PIDFILE, ">$pidfile")) {
    print PIDFILE "$$\n";
    close(PIDFILE);
  } else {
    log_msg(LOG_CRIT,
            "Can't open pidfile $pidfile for writing ($!), exiting!");
    exit(1);
  }
}

### Set signal handlers

$refresh = 0;
$SIG{HUP} = \&hup_handler;

$softrefresh = 0;
$SIG{ABRT} = \&abrt_handler;

$dumpdata = 0;
$SIG{USR1} = \&usr1_handler;

$openlog = 0;
$SIG{USR2} = \&usr2_handler;

$debuglevelset = 0;
if (-t STDIN) {
  log_msg(LOG_NOTICE, 
          "Stdin connected to terminal, SIGINT can't be used for changing the logging level");
} else {
  $SIG{INT} = \&int_handler;
}

$terminate = 0;
$SIG{TERM} = \&term_handler;

### Set function pointers

$matchfunc[SUBSTR] = \&match_substr;
$matchfunc[REGEXP] = \&match_regexp;
$matchfunc[PERLFUNC] = \&match_perlfunc;
$matchfunc[NSUBSTR] = sub { return !match_substr(@_); };
$matchfunc[NREGEXP] = sub { return !match_regexp(@_); };
$matchfunc[NPERLFUNC] = sub { return !match_perlfunc(@_); };
$matchfunc[TVALUE] = \&match_tvalue;

$actioncopyfunc[NONE] = \&copy_one_elem_action;
$actioncopyfunc[LOGONLY] = \&copy_two_elem_action;
$actioncopyfunc[WRITE] = \&copy_three_elem_action;
$actioncopyfunc[SHELLCOMMAND] = \&copy_two_elem_action;
$actioncopyfunc[SPAWN] = \&copy_two_elem_action;
$actioncopyfunc[PIPE] = \&copy_three_elem_action;
$actioncopyfunc[CREATECONTEXT] = \&copy_create_set_action;
$actioncopyfunc[DELETECONTEXT] = \&copy_two_elem_action;
$actioncopyfunc[OBSOLETECONTEXT] = \&copy_two_elem_action;
$actioncopyfunc[SETCONTEXT] = \&copy_create_set_action;
$actioncopyfunc[ALIAS] = \&copy_three_elem_action;
$actioncopyfunc[UNALIAS] = \&copy_two_elem_action;
$actioncopyfunc[ADD] = \&copy_three_elem_action;
$actioncopyfunc[FILL] = \&copy_three_elem_action;
$actioncopyfunc[REPORT] = \&copy_three_elem_action;
$actioncopyfunc[COPYCONTEXT] = \&copy_three_elem_action;
$actioncopyfunc[EMPTYCONTEXT] = \&copy_three_elem_action;
$actioncopyfunc[EVENT] = \&copy_three_elem_action;
$actioncopyfunc[TEVENT] = \&copy_three_elem_action;
$actioncopyfunc[RESET] = \&copy_four_elem_action;
$actioncopyfunc[ASSIGN] = \&copy_three_elem_action;
$actioncopyfunc[EVAL] = \&copy_three_elem_action;
$actioncopyfunc[CALL] = \&copy_call_action;

$actionsubstfunc[NONE] = \&subst_none_action;
$actionsubstfunc[LOGONLY] = \&subst_two_elem_action;
$actionsubstfunc[WRITE] = \&subst_three_elem_action;
$actionsubstfunc[SHELLCOMMAND] = \&subst_two_elem_action;
$actionsubstfunc[SPAWN] = \&subst_two_elem_action;
$actionsubstfunc[PIPE] = \&subst_three_elem_action;
$actionsubstfunc[CREATECONTEXT] = \&subst_create_set_action;
$actionsubstfunc[DELETECONTEXT] = \&subst_two_elem_action;
$actionsubstfunc[OBSOLETECONTEXT] = \&subst_two_elem_action;
$actionsubstfunc[SETCONTEXT] = \&subst_create_set_action;
$actionsubstfunc[ALIAS] = \&subst_three_elem_action;
$actionsubstfunc[UNALIAS] = \&subst_two_elem_action;
$actionsubstfunc[ADD] = \&subst_three_elem_action;
$actionsubstfunc[FILL] = \&subst_three_elem_action;
$actionsubstfunc[REPORT] = \&subst_three_elem_action;
$actionsubstfunc[COPYCONTEXT] = \&subst_copy_empty_action;
$actionsubstfunc[EMPTYCONTEXT] = \&subst_copy_empty_action;
$actionsubstfunc[EVENT] = \&subst_event_assign_eval_action;
$actionsubstfunc[TEVENT] = \&subst_three_elem_action;
$actionsubstfunc[RESET] = \&subst_reset_action;
$actionsubstfunc[ASSIGN] = \&subst_event_assign_eval_action;
$actionsubstfunc[EVAL] = \&subst_event_assign_eval_action;
$actionsubstfunc[CALL] = \&subst_call_action;

$processrulefunc[SINGLE] = \&process_single_rule;
$processrulefunc[SINGLE_W_SCRIPT] = \&process_singlewithscript_rule;
$processrulefunc[SINGLE_W_SUPPRESS] = \&process_singlewithsuppress_rule;
$processrulefunc[PAIR] = \&process_pair_rule;
$processrulefunc[PAIR_W_WINDOW] = \&process_pairwithwindow_rule;
$processrulefunc[SINGLE_W_THRESHOLD] = \&process_singlewiththreshold_rule;
$processrulefunc[SINGLE_W_2_THRESHOLDS] = \&process_singlewith2thresholds_rule;
$processrulefunc[JUMP] = \&process_jump_rule;

$execactionfunc[NONE] = \&execute_none_action;
$execactionfunc[LOGONLY] = \&execute_logonly_action;
$execactionfunc[WRITE] = \&execute_write_action;
$execactionfunc[SHELLCOMMAND] = \&execute_shellcmd_action;
$execactionfunc[SPAWN] = \&execute_spawn_action;
$execactionfunc[PIPE] = \&execute_pipe_action;
$execactionfunc[CREATECONTEXT] = \&execute_create_action;
$execactionfunc[DELETECONTEXT] = \&execute_delete_action;
$execactionfunc[OBSOLETECONTEXT] = \&execute_obsolete_action;
$execactionfunc[SETCONTEXT] = \&execute_set_action;
$execactionfunc[ALIAS] = \&execute_alias_action;
$execactionfunc[UNALIAS] = \&execute_unalias_action;
$execactionfunc[ADD] = \&execute_add_action;
$execactionfunc[FILL] = \&execute_fill_action;
$execactionfunc[REPORT] = \&execute_report_action;
$execactionfunc[COPYCONTEXT] = \&execute_copy_action;
$execactionfunc[EMPTYCONTEXT] = \&execute_empty_action;
$execactionfunc[EVENT] = \&execute_event_action;
$execactionfunc[TEVENT] = \&execute_tevent_action;
$execactionfunc[RESET] = \&execute_reset_action;
$execactionfunc[ASSIGN] = \&execute_assign_action;
$execactionfunc[EVAL] = \&execute_eval_action;
$execactionfunc[CALL] = \&execute_call_action;

### Set various global variables

$lastcleanuptime = $startuptime = time();
$processedlines = 0;

### Initialize input buffer

for (my $i = 0; $i < $bufsize; ++$i) { 
  $input_buffer[$i] = ""; 
  $input_sources[$i] = "";
}

$bufpos = $bufsize - 1;

### Initialize correlation list, context list, 
### buffer list, and child process list

%corr_list = ();
%context_list = ();
%children = ();

### Initialize event buffers

@events = ();
@pending_events = ();

### If -intevents flag was specified, create generate the SEC_STARTUP event

if ($intevents)  { internal_event("SEC_STARTUP"); }

### The main loop - read lines from input stream and process them

for (;;) {

  my($line, $file, $ret);
  my($context, $conffile);

  # if there are pending events in the event buffer or the read buffer, 
  # read new line from there, otherwise read new line from input stream.

  if (scalar(@events)) { 
    $line = shift @events;
    $file = undef;
  } elsif (scalar(@readbuffer)) { 
    $line = shift @readbuffer;
    $file = shift @readbuffer;
  } else {
    read_line($line, $file);
  }

  if (defined($line)) {

    if ($intcontexts) {
      if (defined($file)) { $context = $inputsrc{$file}->{"context"}; } 
        else { $context = "_INTERNAL_EVENT"; }
      $context_list{$context} = $int_contexts{$context};
    }

    # update input buffer (it is implemented as a circular buffer, since
    # according to benchmarks an array queue using shift and push is slower)

    $bufpos = ($bufpos + 1) % $bufsize;
    $input_buffer[$bufpos] = $line;
    $input_sources[$bufpos] = $file;

    # process rules from configuration files

    foreach $conffile (@maincfiles)  { process_rules($conffile); }

    if ($intcontexts)  { delete $context_list{$context}; }

    if (defined($file))  { ++$inputsrc{$file}->{"lines"}; }
    ++$processedlines;

  } elsif (!$file) {

    # if we didn't get new data and -tail option was specified, sleep 
    # for $poll_timeout seconds; if -notail option is active and all
    # input files have been closed, exit

    if ($tail) {

      # sleep with select()

      $ret = select(undef, undef, undef, $poll_timeout);

      if ((!defined($ret) || $ret < 0)  &&  $! != EINTR) {
        log_msg(LOG_CRIT, "Select error ($!), exiting!");
        child_cleanup();
        exit(1);
      }

    } elsif (!grep($inputsrc{$_}->{"open"}, @inputfiles)) {

      # after generating SEC_SHUTDOWN event, SEC will sleep for TERMTIMEOUT 
      # seconds, so that child processes that were triggered by SEC_SHUTDOWN 
      # have time to create a signal handler for SIGTERM if they wish

      if ($intevents) {
        internal_event("SEC_SHUTDOWN"); 
        sleep(TERMTIMEOUT);
      }

      child_cleanup();
      exit(0); 

    }

  }

  # search all lists, performing timed tasks associated with elements
  # and removing obsolete elements

  if (time() - $lastcleanuptime >= $cleantime) {
    process_lists();
    $lastcleanuptime = time();
  }

  # manage child processes

  if (scalar(%children))  { check_children(); }

  # check signal flags

  check_signals();

}
