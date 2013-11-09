#!/usr/bin/perl -w

#
# This lists the users that are in the system and their bandwidth quotas
#
# Programmed by Mike Dawson, PAIWASTOON Networking Services Ltd. 2009
# Free Software under GPL v2.
#

 package    esmith::FormMagick::Panel::bwlimit_ldapauth;

 use strict;

 use esmith::bwlimit::bwlimit_utils;
 use esmith::FormMagick;
 use esmith::AccountsDB;
 use esmith::ConfigDB;

 use Exporter;
 use Carp qw(verbose);

  use IO::Socket;
  use IO::Interface qw(:flags);

 use HTML::Tabulate;

 our @ISA = qw(esmith::FormMagick Exporter);

 our @EXPORT = qw();

 our $db = esmith::ConfigDB->open();
 our $adb = esmith::AccountsDB->open();

 sub new
 {
     shift;
     my $self = esmith::FormMagick->new();
     $self->{calling_package} = (caller)[0];
     bless $self;
     return $self;
 }

