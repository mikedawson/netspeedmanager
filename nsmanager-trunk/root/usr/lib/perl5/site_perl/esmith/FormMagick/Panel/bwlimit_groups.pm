#!/usr/bin/perl -w

#
# This lists the users that are in the system and their bandwidth quotas
#
# Programmed by Mike Dawson, PAIWASTOON Networking Services Ltd. 2009
# Free Software under GPL v2.
#

 package    esmith::FormMagick::Panel::bwlimit_groups;

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

sub print_bwlimit_table_groups {
    my $self = shift;

    &print_bwlimit_table($self, "groups");
}

sub print_groupmember_table {
    my $self = shift;
    my $q = $self->{cgi};
    my $group_name = $q->param('User');
    my @accounts_list = $adb->users;

    my $group_rec = $adb->get($group_name);
    my $group_member_str = $group_rec->prop("BWGroupMembers");
    my @group_current_members = split(/,/, $group_member_str);

    my $html = "";
    for my $user (@accounts_list) {
	my $current_username = $user->key;
	my $display_name = $user->prop("FirstName") . " " . $user->prop("LastName");
        my $checked_str = "";
	if ( my @found = grep { $_ eq $current_username } @group_current_members ) {
		$checked_str = " checked='checked' ";
	}
	$html .= "<input type='checkbox' name='bwMember' value='$current_username' $checked_str /> $display_name ($current_username) <br/>";
    }
    $html .= "<input type='hidden' name='groupName' value='$group_name'/>";

    return $html;
}

sub modifiy_bwlimit_groupmembers {
   my $self = shift;
   my $q = $self->{cgi};
   my @usersInGroup = $q->param("bwMember");
   my $group_name = $q->param("groupName");

   for my $user (@usersInGroup) {
	my $user_rec = $adb->get($user);
        $user_rec->set_prop("BWLimitCountGroup", $group_name);
   }

   #then we need to check through those that are set to be in this group - they should be in the array.  If not blank it out
   my @all_users_list = $adb->users;
   for my $current_user (@all_users_list) {
	my $current_username = $current_user->key; 
        my $current_bwgroup = $current_user->prop("BWLimitCountGroup") || "";
	if($current_bwgroup eq $group_name) {
		if ( ! (my @found = grep { $_ eq $current_username } @usersInGroup) ) {
			#this is not really in the group anymore
			$current_user->set_prop("BWLimitCountGroup", "unsorted");
		}
	}
   }

   system("/etc/e-smith/events/actions/bwlimit-update-groups");
   return $self->success('SUCCESSFULLY_MODIFIED');
}


sub modify_bwlimit {
    my $self = shift;
    my $q = $self->{cgi};

#    my $applymethod = $q->param("applymethod");
#    my $groupname = $q->param("User");
    
#    if($applymethod =~ /allgroup/) {
#	system("/etc/e-smith/events/actions/bwlimit-set-rates-from-group $groupname");
#    }

    #do the group ceiling settings etc

    my $result = &modify_bwlimit_account($self, $q);
    
    #this should now call the event to regenerate templates and compute quotas
    
    return $result;
}

sub get_acc_value {
    my $self = shift;
    my $fieldname = shift; 
    my $q = $self->{cgi};
    my $groupname = $q->param("User");
    my $group_rec = $adb->get($groupname);
    return $group_rec->prop($fieldname) || "0";
}


sub get_parent_group_options() {
    my $self = shift;
    my $q = $self->{cgi};
    my $groupname = $q->param('User');

    our $adb = esmith::AccountsDB->open();
    my @current_user_group_list = $adb->groups;

    my $targetgroup_rec = $adb->get($groupname);
    my $targetgroupid = $targetgroup_rec->prop("BWGroupClassID");
    my %retval = ();

    $retval{'root'} = 'root';
    for my $current_group_rec (@current_user_group_list) {
        my $current_group_isclass = $current_group_rec->prop("BWLimitGroupIsClass") || "";
        if($current_group_isclass eq "y") {
            my $current_group_name = $current_group_rec->key;
            if($current_group_name ne $groupname) {
	        my $thisgrp_is_parent = check_group_for_circularref($targetgroupid, $current_group_rec->prop("BWGroupClassID"));
		if($thisgrp_is_parent == 0) {
	                $retval{$current_group_rec->prop("BWGroupClassID")} = $current_group_name;
		}	
            }
        }
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

    my $table_html = make_acl_timetable($q->param('User'));
    my $msg = $self->localise('BWLIMIT_GROUP_FILTERDESC');
   
    return $msg . " <br/> " . $table_html;
}


sub validate_rate {
        my ($fm, $data, $ratefieldname, $ceilfieldname) = @_;

        my $q = $fm->{cgi};
       	return validate_rate_ceil($q, $ratefieldname, $ceilfieldname);
}

sub validate_rate_group {
        my ($fm, $data, $ratefieldname, $ceilfieldname) = @_;

        my $q = $fm->{cgi};
	return validate_rate_ceil_group($q, $ratefieldname, $ceilfieldname);
}
