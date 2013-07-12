#!/usr/bin/perl -w

#
# This lists the users that are in the system and their bandwidth quotas
#
# Programmed by Mike Dawson, PAIWASTOON Networking Services Ltd. 2009
# Free Software under GPL v2.
#

 package    esmith::FormMagick::Panel::bwlimit_mainopts;

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

sub modify_bwmain_settings() {
    my $self = shift;
    my $q = $self->{cgi};

    my $existing_setup_type_rec = $db->get("BWLimitSetupType") ||
        $db->new_record("BWLimitSetupType");
    $existing_setup_type_rec->set_prop("type",
        $q->param("BWLimitSetupType"));

    my $bwlimit_setup_rec = $db->get("BWLimit");
    $bwlimit_setup_rec->set_prop("totalup",
	$q->param("bwlimit_total_rate_up"));
    $bwlimit_setup_rec->set_prop("totaldown",
        $q->param("bwlimit_total_rate_down"));
    $bwlimit_setup_rec->set_prop("exceedpolicy",	
	$q->param("bwlimit_exceedpolicy"));
    $bwlimit_setup_rec->set_prop("sessiontime",
	$q->param("bwlimit_sessiontime"));

    $bwlimit_setup_rec->set_prop("depriorate",
	$q->param("bwlimit_depriorate"));
    $bwlimit_setup_rec->set_prop("useDynamicRates",
	$q->param("bwlimit_useDynamicRates"));

    $bwlimit_setup_rec->set_prop("configmethod",
	$q->param("bwlimit_configmethod"));

    $bwlimit_setup_rec->set_prop("CalcBandwidthURL",
	$q->param("bwlimit_CalcBandwidthURL"));

    $bwlimit_setup_rec->set_prop("CalcBandwidthWaitTime",
	$q->param("bwlimit_CalcBandwidthWaitTime"));
    $bwlimit_setup_rec->set_prop("CalcBandwidthCountTime",
	$q->param("bwlimit_CalcBandwidthCountTime"));

    $bwlimit_setup_rec->set_prop("CachePrimer",
	$q->param("bwlimit_CachePrimer"));
    $bwlimit_setup_rec->set_prop("CachePrimerStartTime",
	$q->param("bwlimit_CachePrimerStartTime"));
    $bwlimit_setup_rec->set_prop("CachePrimerRunTime",
	$q->param("bwlimit_CachePrimerRunTime"));
    $bwlimit_setup_rec->set_prop("CachePrimerSpeedLimit",
	$q->param("bwlimit_CachePrimerSpeedLimit"));

     $bwlimit_setup_rec->set_prop("autoresetgroup",
	$q->param("bwlimit_autoresetgroup"));


#    my $wanbackup_rec = $db->get("wanbackup") ||
#	$db->new_record("wanbackup");

#    $wanbackup_rec->set_prop("setup",
#	$q->param("wanbackup_setup"));
#    $wanbackup_rec->set_prop("primaryinterfacename",
#	$q->param("wanbackup_primaryinterfacename"));
#    $wanbackup_rec->set_prop("primarytestip",
#	$q->param("wanbackup_primarytestip"));
#    $wanbackup_rec->set_prop("backuptestip",
#	$q->param("wanbackup_backuptestip"));
#    $wanbackup_rec->set_prop("ethinterface",
#	$q->param("wanbackup_ethinterface"));
#    $wanbackup_rec->set_prop("staticip",	
#	$q->param("wanbackup_staticip"));
#    $wanbackup_rec->set_prop("staticgateway",
#        $q->param("wanbackup_staticgateway"));
#    $wanbackup_rec->set_prop("staticnetmask",
#        $q->param("wanbackup_staticnetmask"));
#    $wanbackup_rec->set_prop("staticdns",
#        $q->param("wanbackup_staticdns"));
#    $wanbackup_rec->set_prop("usb3gapn",
#        $q->param("wanbackup_usb3gapn"));
#    $wanbackup_rec->set_prop("usb3gusername",
#        $q->param("wanbackup_usb3gusername"));
#    $wanbackup_rec->set_prop("usb3gpassword",
#        $q->param("wanbackup_usb3gpassword"));
#    $wanbackup_rec->set_prop("usb3ginitscript",
#        $q->param("wanbackup_usb3ginitscript"));

    my $bwlimit_sql_val = 0;
    if($q->param("bwlimit_useDynamicRates") =~ m/yes/) {
        $bwlimit_sql_val = 1;
    }
    #put this into SQL
    system("mysql bwlimits -e 'update process_log set useDynamicRates = $bwlimit_sql_val'");

    if($bwlimit_sql_val == 1) {
	system("/usr/lib/bwlimit/calcBandwidth");
    }


    system("/sbin/e-smith/expand-template /etc/crontab");
    system("/sbin/e-smith/expand-template /etc/htb-gen/htb-gen.conf");
    system("/sbin/e-smith/expand-template /etc/nsm.conf.php");
    system("/sbin/e-smith/expand-template /etc/wanbackup-wvdial.conf");

    #restart cron to reflect new start time
    system("/etc/init.d/crond restart");

    #this is out until we use wanbackup
    #system("/usr/bin/sv restart wanbackup");

    system("/usr/lib/bwlimit/bwlimit-setsystemtype.pl");
    system("/etc/e-smith/events/actions/bwlimit_check_reset");

    return $self->success('SUCCESSFULLY_MODIFIED');
}

sub get_wanbackup_primaryinterfacename_options {
	my $s = IO::Socket::INET->new(Proto => 'udp');
	my @interfaces = $s->if_list;
	
	my %names = ();
	for my $if (@interfaces) {
		my $addr = $s->if_addr($if);
		$names{$if} = $if . " (" . $addr . ") ";
	}
	
	return \%names;
}


sub get_wanbackup_primaryinterfacename{
	return $db->get_prop("wanbackup", "primaryinterfacename");
}

sub get_depriorate {
	return $db->get_prop("BWLimit", "depriorate");
}

sub get_bwlimit_configmethod {
	return $db->get_prop("BWLimit", "configmethod");
}

sub get_sessiontime {
	return $db->get_prop("BWLimit", "sessiontime");
}

sub get_exceedpolicy {
	return $db->get_prop("BWLimit", "exceedpolicy");
}

sub get_useDynamicRates {
	return $db->get_prop("BWLimit", "useDynamicRates");
}

sub get_setup_type {
    return $db->get("BWLimitSetupType") || "None";

    return "ByIP";
}

sub get_reporting_style {
    return "trafficlight";
}

sub get_total_up
 {
     return $db->get_prop("BWLimit", "totalup");
 }

sub get_total_down
 {
     return $db->get_prop("BWLimit", "totaldown");
 }

sub get_wanbackup_setup {
     return $db->get_prop("wanbackup", "setup");
}

sub get_wanbackup_primarytestip {
     return $db->get_prop("wanbackup", "primarytestip");
}

sub get_wanbackup_backuptestip {
	return $db->get_prop("wanbackup", "backuptestip");
}

sub get_wanbackup_ethinterface {
	return $db->get_prop("wanbackup", "ethinterface");
}

sub get_wanbackup_staticip {
	return $db->get_prop("wanbackup", "staticip");
}

sub get_wanbackup_staticgateway {
	return $db->get_prop("wanbackup", "staticgateway");
}

sub get_wanbackup_staticnetmask {
	return $db->get_prop("wanbackup", "staticnetmask");
}

sub get_wanbackup_staticdns {
	return $db->get_prop("wanbackup", "staticdns");
}

sub get_wanbackup_usb3gapn {
	return $db->get_prop("wanbackup", "usb3gapn");
}

sub get_wanbackup_usb3gusername {
	return $db->get_prop("wanbackup", "usb3gusername");
}

sub get_wanbackup_usb3gpassword {
	return $db->get_prop("wanbackup", "usb3gpassword");
}

sub get_wanbackup_usb3ginitscript {
	return $db->get_prop("wanbackup", "usb3ginitscript");
}

sub get_bwlimit_CalcBandwidthURL() {
	return $db->get_prop("BWLimit", "CalcBandwidthURL");
}

sub get_bwlimit_CalcBandwidthWaitTime() {
	return $db->get_prop("BWLimit", "CalcBandwidthWaitTime");
}

sub get_bwlimit_CalcBandwidthCountTime() {
	return $db->get_prop("BWLimit", "CalcBandwidthCountTime");
}


sub get_bwlimit_CachePrimer() {
	return $db->get_prop("BWLimit", "CachePrimer");
}

sub get_bwlimit_CachePrimerStartTime_options {
	my %times = ();
	for(my $hrcount = 0; $hrcount < 24; $hrcount++) {
		for(my $mincount = 0; $mincount < 60; $mincount += 15) {
			my $hrformatted = $hrcount;
			my $minformatted = $mincount;
			if($hrcount < 10) {
				$hrformatted = "0" . $hrcount;
			}

			if($mincount < 10) {
				$minformatted = "0" . $mincount;
			}

			my $timename = $hrformatted . ":" . $minformatted;
			my $timecode = $hrcount . ":" . $mincount;
			$times{$timecode} = $timename;
		}
	}

	return \%times;
}

sub get_bwlimit_SessionTime_options {
       	my %times = ();
        for(my $hrcount = 0; $hrcount < 24; $hrcount++) {
		my $startMin = 0;
		if($hrcount == 0) {
			$startMin = 15;
		}

                for(my $mincount = $startMin; $mincount < 60; $mincount += 15) {
                        my $hrformatted = $hrcount;
                       	my $minformatted = $mincount;
                        if($hrcount < 10) {
                               	$hrformatted = "0" . $hrcount;
                       	}

                        if($mincount < 10) {
                                $minformatted = "0" . $mincount;
                        }

                        my $timename = $hrformatted . ":" . $minformatted;
                       	my $timecode = ($hrcount * 60 * 60) + ($mincount * 60);
                        $timecode = "$timecode";
                        $times{$timecode} = $timename;
                }
        }

        return \%times;
}



sub get_bwlimit_CachePrimerStartTime {
	return $db->get_prop("BWLimit", "CachePrimerStartTime");
}

sub get_bwlimit_CachePrimerRunTime {
	return $db->get_prop("BWLimit", "CachePrimerRunTime");
}

sub get_bwlimit_CachePrimerSpeedLimit {
	return $db->get_prop("BWLimit", "CachePrimerSpeedLimit");
}

sub get_bwlimit_autoresetgroup {
	return $db->get_prop("BWLimit", "autoresetgroup");
}

sub get_group_list() {
    my $self = shift;

    my $adb = esmith::AccountsDB->open();
    my @current_user_group_list = $adb->groups();

    my %retval = ();

    $retval{''} = '';
    for my $current_group_name (@current_user_group_list) {
	my $current_group_name_str = $current_group_name->key;
        $retval{$current_group_name_str} = $current_group_name_str;
    }


    return \%retval;
}

