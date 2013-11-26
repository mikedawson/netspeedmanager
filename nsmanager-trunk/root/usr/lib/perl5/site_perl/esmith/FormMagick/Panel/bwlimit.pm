#!/usr/bin/perl -w

#
# This lists the users that are in the system and their bandwidth quotas
#
# Programmed by Mike Dawson, PAIWASTOON Networking Services Ltd. 2009
# Free Software under GPL v2.
#

 package    esmith::FormMagick::Panel::bwlimit;
 
 use strict;

 use esmith::bwlimit::bwlimit_utils;
 use esmith::FormMagick;
 use esmith::AccountsDB;
 use esmith::ConfigDB;
 
 use Exporter;
 use Carp qw(verbose);
 
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


sub show_initial() {
    my $fm = shift;
    my $q = $fm->{cgi};

    print $q->Tr($q->td(
          "<p><a class=\"button-like\" href=\"bwlimit_customlist?page=0&wherenext=BWLIMIT_NEW_CUSTOMLIST\">"
          . $fm->localise("CREATE_CUSTOM_LIST")
          . "</a></p>"));

}


sub get_user_group_options() {
    my $self = shift;
    my $q = $self->{cgi};
    my $username = $q->param('User');

    our $adb = esmith::AccountsDB->open();
    #my @current_user_group_list = $adb->user_group_list($username);
    my @current_user_group_list = $adb->groups;

    my %retval = ();

    $retval{'unsorted'} = 'unsorted';
    for my $current_group_rec (@current_user_group_list) {
	my $current_group_name = $current_group_rec->key;
	$retval{$current_group_name} = $current_group_name;
    }


    return \%retval;
}


#
# Print a table for the user of the ACLs and timeranges so that the admin can
# select what list is allowed / blocked at what times
#
sub print_aclist_table {
    my $self = shift;
    my $q = $self->{cgi};

    #find out the list of acls
    my $msg = $self->localise("BWLIMIT_USER_FILTERDESC");

    my $table_html = make_acl_timetable($q->param('User'));
    return "$msg <br/> $table_html";
}
 
 
 
sub print_usage_summary {
    my $self = shift;
    my $q = $self->{cgi};
    my $username = $q->param("User");
    $username =~ m/(.*)/;
    $username = $1;
    my $usage_info = `/usr/lib/bwlimit/generate-user-bw-report.sh $username 86400`;
    print $usage_info;
}

sub get_current_BWLimitAuthSource {
    my $self = shift;
    my $q = $self->{cgi};
    my $username = $q->param("User");
    $username =~ m/(.*)/;
    $username = $1;
    
    my $acct_rec = $adb->get($username);
    return $acct_rec->prop("BWLimitAuthSource") || "local";
}


sub print_bwlimit_table_users {
    my $self = shift;

    &print_bwlimit_table($self, "users");
}

 sub modify_bwlimit
 {
     my $self = shift;
     my $q = $self->{cgi};

     my $result = &modify_bwlimit_account($self, $q);

     return $result;
 }

sub is_ipaddr {
	my $ipaddr = shift;
	my $isvalid = 0;
	if( $ipaddr =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)$/ )
	{
	    if($1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255)
	    {
        	$isvalid = 1;
	    }
	    
	}
	

	if($isvalid == 1) {
		return "OK";
	}else {
		return "Invalid IP Address";
	}
}

sub validate_static_ip_field {
        my ($fm, $data) = @_;

        if($data eq "") {
                return "OK";
        }else {
                return is_ipaddr($data);
        }
}

sub validate_rate {
	my ($fm, $data, $ratefieldname, $ceilfieldname) = @_;

	my $q = $fm->{cgi};
		
	return validate_rate_ceil($q, $ratefieldname, $ceilfieldname);
}


 
 1;

