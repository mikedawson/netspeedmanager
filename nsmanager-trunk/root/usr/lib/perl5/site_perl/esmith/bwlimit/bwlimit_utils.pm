package    esmith::bwlimit::bwlimit_utils;

use strict;

use warnings;

use esmith::FormMagick;
use esmith::AccountsDB;
use esmith::ConfigDB;

#export this and let others use it...

use base 'Exporter';

our @EXPORT = qw(
    list_timerange_names
    bwlimit_table_modify_link
    print_bwlimit_table
    modify_bwlimit_account
    bwlimit_table_usage_breakdown_link
    set_acls_from_query
    make_acl_timetable
    make_htbgroup
    get_group_childclasses_by_classid
    get_grouprec_by_classid
    get_htbparent_for_username
    check_group_for_circularref
    htbgroup_remove_circular_ref
    validate_rate_ceil
    validate_rate_ceil_group
);

our $db = esmith::ConfigDB->open();
our $adb = esmith::AccountsDB->open();

#This variable used to store the page name so that when the sub gets called it
#knows where to go back to
our $mod_link_pagename = "";


#
# Small utility function to find a list of the names of the different time ranges
# that are on the system
#
sub list_timerange_names {
    #now find out the list of timeranges
    my $bwtime_range_rec = $db->get('BWLimitTimes');
    my @bwtime_range_list = ();

    for my $bwtimeprop ($bwtime_range_rec->props) {
        #should start with timerange_time_
        if($bwtimeprop =~ m/^timerange_time_(.*)$/) {
            my $timerange_name = $bwtimeprop;
            $timerange_name =~ m/^timerange_time_(.*)/;
            $timerange_name = $1;
            push(@bwtime_range_list, $timerange_name);
        }
    }

    return @bwtime_range_list;
}


#Function to print the list of quotas for either users or groups
#
# Takes a few arguments
#
# form - reference to form magick object
# string - what_to_list - either "users" or "groups"
#
sub print_bwlimit_table
 {
     my $form = shift;
     #my $q = $self->{cgi};

     my $what_to_list = shift;
     my @fields = [ qw(User BWLimitDaily BWLimitWeekly BWLimitMonthly BWLimitRateDown BWLimitCeilDown BWLimitRateUp BWLimitCeilUp 
Modify) ];

     if ($what_to_list =~ m/^(groups)$/) {
	@fields = [ qw(User BWLimitDaily BWLimitWeekly BWLimitMonthly BWLimitRateDown BWLimitCeilDown BWLimitRateUp BWLimitCeilUp Modify BWMembers) ]
     }	

     my $bwlimits_table =
     {
        title => $form->localise('BWLIMIT_CURRENT_QUOTAS'),

        stripe => '#D4D0C8',

        fields => @fields,

        labels => 1,

        field_attr => {
                        User => { label => $form->localise('LABEL_USER') },

                        BWLimitDaily => { label => $form->localise('LABEL_BWLIMITDAILY') },

                        BWLimitWeekly => { label => $form->localise('LABEL_BWLIMITWEEKLY') },

                        BWLimitMonthly => { label => $form->localise('LABEL_BWLIMITMONTHLY') },

			BWLimitRateDown => { label => $form->localise('LABEL_BWLIMITRATEDOWN') },

			BWLimitCeilDown => { label => $form->localise('LABEL_BWLIMITCEILDOWN') },

			BWLimitRateUp => { label => $form->localise('LABEL_BWLIMITRATEUP') },

			BWLimitCeilUp => { label => $form->localise('LABEL_BWLIMITCEILUP') },
			
                        BWLimitMACAddress => { label => $form->localise('LABEL_BWLIMITMACADDRESS') },

                        BWLimitMACAddress2 => { label => $form->localise('LABEL_BWLIMITMACADDRESS2') },

			staticip => { label => $form->localise('LABEL_STATICIP') },

                        Modify => {
                                    label => $form->localise('MODIFY'),
                                    link => \&bwlimit_table_modify_link },

			BWMembers => {
                                    label => $form->localise('BWMembers'),
                                    link => \&bwlimit_table_bwmember_link },
                      },
                       
            };

     my @data = ();

     my $modify = $form->localise('MODIFY');
     my $bwmemberText = $form->localise('BWMembers');

     my $usage_breakdown = $form->localise('USAGEBREAKDOWN');

     my @accounts_list = ();

     if($what_to_list =~ m/^(users)$/) {
        @accounts_list = $adb->users;
        $mod_link_pagename = "bwlimit";
     }elsif ($what_to_list =~ m/^(groups)$/) {
        @accounts_list = $adb->groups();
        $mod_link_pagename = "bwlimit_groups";
     }

     for my $user (@accounts_list)
     {
         push @data,
             {
                User => $user->key,

                BWLimitDaily => $user->prop('BWLimitDaily') || '10',

                BWLimitWeekly => $user->prop('BWLimitWeekly') || '50',

                BWLimitMonthly => $user->prop('BWLimitMonthly') || '200',

		BWLimitRateUp => $user->prop('BWLimitRateUp') || '128',

		BWLimitCeilUp => $user->prop('BWLimitCeilUp') || '128',

		BWLimitRateDown => $user->prop('BWLimitRateDown') || '128',

		BWLimitCeilDown => $user->prop('BWLimitCeilDown') || '128',

                BWLimitMACAddress => $user->prop('BWLimitMACAddress') || '',

                BWLimitMACAddress2 => $user->prop('BWLimitMACAddress2') || '',

		BWLimitCountGroup => $user->prop('BWLimitCountGroup') || '',

		staticip => $user->prop('staticip') || '',

		BWLimit_blockdirecthttps => $user->prop('BWLimit_blockdirecthttps') || '-',

                Modify => $modify, 

		BWMembers =>  $bwmemberText,
                
             }
     }

     my $t = HTML::Tabulate->new($bwlimits_table);
 
     $t->render(\@data, $bwlimits_table);
 }

 sub bwlimit_table_usage_breakdown_link
 {
     my ($data_item, $row, $field) = @_;

     return "$mod_link_pagename?" .
             join("&",
                 "page=0",
                 "page_stack=",
                 "Next=Next",
                 "User="     . $row->{User},
                 "wherenext=BWLIMIT_PAGE_USAGE");
 }

sub bwlimit_table_bwmember_link
 {
     my ($data_item, $row, $field) = @_;

     return "$mod_link_pagename?" .
             join("&",
                 "page=0",
                 "page_stack=",
                 "Next=Next",
                 "User="     . $row->{User},
                 "wherenext=BWLIMIT_PAGE_GROUPMEMBERS");
 }



 sub bwlimit_table_modify_link
 {
     my ($data_item, $row, $field) = @_;

     return "$mod_link_pagename?" .
             join("&",
                 "page=0",
                 "page_stack=",
                 "Next=Next",
                 "User="     . $row->{User},
                 "BWLimitDaily="     . $row->{BWLimitDaily},
                 "BWLimitWeekly="     . $row->{BWLimitWeekly},
                 "BWLimitMonthly="     . $row->{BWLimitMonthly},
		 "BWLimitRateDown=" . $row->{BWLimitRateDown},
		 "BWLimitCeilDown=" . $row->{BWLimitCeilDown},
		 "BWLimitRateUp=" . $row->{BWLimitRateUp},
		 "BWLimitCeilUp=" . $row->{BWLimitCeilUp},
                 "BWLimitMACAddress=" . $row->{BWLimitMACAddress},
		 "BWLimit_blockdirecthttps=" . $row->{BWLimit_blockdirecthttps},
		 "BWLimitCountGroup=" . $row->{BWLimitCountGroup},
		 "staticip=" . $row->{staticip},
                 "wherenext=BWLIMIT_PAGE_MODIFY");
 }


#
# Updates the configuration database and call systems to update the 
# MySQL bandwidth tracking database
#
# Args are:
#  form - the FormMagick form we're dealing with
#  q - the query that sent us the data
#
sub modify_bwlimit_account
 {
     my $form = shift;
     my $q = shift;

     my $account = $adb->get( $q->param('User') );

     $account->set_prop('BWLimitDaily', $q->param('BWLimitDaily'));
     $account->set_prop('BWLimitWeekly', $q->param('BWLimitWeekly'));
     $account->set_prop('BWLimitMonthly', $q->param('BWLimitMonthly'));
     $account->set_prop('BWLimitRateDown', $q->param('BWLimitRateDown'));
     $account->set_prop('BWLimitCeilDown', $q->param('BWLimitCeilDown'));
     $account->set_prop('BWLimitRateUp', $q->param('BWLimitRateUp'));
     $account->set_prop('BWLimitCeilUp', $q->param('BWLimitCeilUp'));
     $account->set_prop('BWLimitMACAddress', $q->param('BWLimitMACAddress'));
     $account->set_prop('staticip', $q->param('staticip'));
     $account->set_prop('BWLimit_blockdirecthttps', $q->param('BWLimit_blockdirecthttps'));
     if($q->param('BWLimitCountGroup')) {
	$account->set_prop('BWLimitCountGroup', $q->param('BWLimitCountGroup'));
     }

     if($q->param('BWLimitAuthSource')) {
        $account->set_prop('BWLimitAuthSource', $q->param('BWLimitAuthSource'));
     }


     my $account_type = $account->prop('type');

     &set_acls_from_query( $q, $q->param('User') );

     if($account_type =~ m/^(user)$/) {
        system("/etc/e-smith/events/actions/bwlimit_check_reset user-modify");
     }elsif($account_type =~ m/^(group)$/) {
        #do the group ceiling settings etc
   	my @GroupSettingsParams = ("BWLimitGroupRateDown", "BWLimitGroupCeilDown", "BWLimitGroupRateUp", "BWLimitGroupCeilUp", "BWLimitGroupIsClass", "BWLimitParentGroupClass");
    	
    	
    	for my $current_group_param (@GroupSettingsParams) {
        	my $current_param_val = $q->param($current_group_param);
       	 	$account->set_prop($current_group_param, $current_param_val);
    	}




        system("/etc/e-smith/events/actions/bwlimit_check_reset group-modify");
    	my $applymethod = $q->param("applymethod");
    	my $groupname = $q->param("User");

    	if($applymethod =~ /allgroup/) {
        	system("/etc/e-smith/events/actions/bwlimit-set-rates-from-group $groupname");
    	}

     }

     return $form->success('SUCCESSFULLY_MODIFIED');
}

#
# This will set the acls for a given account (user or group)
#
sub set_acls_from_query() {
    my $q = shift;
    my $username = shift;

    my $BWLimitACLAllow = '';
    my $BWLimitACLDeny = '';

    my $bwacl_list_record = $db->get('BWLimitACLs');
    my @acl_list = split(/,/, $bwacl_list_record->value);
    my @bwtime_range_list = list_timerange_names();

    for my $current_acl (@acl_list) {
        for my $current_timerange (@bwtime_range_list) {
            my $fieldname = $current_timerange . ":" . $current_acl;
            my $comboval = $q->param($fieldname);
            if($comboval) {
                if($comboval =~ m/^(true)$/) {
                    print "$fieldname = $comboval, ";
                    $BWLimitACLAllow .= $fieldname . ",";
                }elsif($comboval =~ m/^(false)$/) {
                    $BWLimitACLDeny .= $fieldname . ",";
                }
            }
        }
    }

    my $user_rec = $adb->get($username);
    $user_rec->set_prop("BWLimitACLAllow", $BWLimitACLAllow);
    $user_rec->set_prop("BWLimitACLDeny", $BWLimitACLDeny);

}


#
# Make a timetable of when items can be accessed / not accessed
#
# looks like:
#            timerange_name   timerange_name
#  aclname   <dropdown>        <dropdown>
#
# For each combo a dropdown menu appears allowing the selection of Yes, No, or Group
#
sub make_acl_timetable {
    my $username = shift;

    my $user = $adb->get($username);
    my $usertype = $user->prop('type');

    my $bwacl_list_record = $db->get('BWLimitACLs');
    my @acl_list = split(/,/, $bwacl_list_record->value);

    #now find out the list of timeranges
    my $bwtime_range_rec = $db->get('BWLimitTimes');
    my @bwtime_range_list = list_timerange_names();

    my $table_html  = "<table><tr><th>\&#160;</th>";
    #put the headers on it
    for my $current_header (@bwtime_range_list) {
        $table_html .= "<th>$current_header</th>";
    }
    $table_html .= "</tr>";

    my $users_acl_deny_list = $user->prop('BWLimitACLDeny') || '';
    my $users_acl_allow_list = $user->prop('BWLimitACLAllow') || '';

    for my $current_acl (@acl_list) {
        my %tablerow = ();
        $table_html .= "<tr><td>$current_acl</td>";

        for my $current_timerange (@bwtime_range_list) {
            #see if this appears in the deny list
            my $allow_selected_str = "";
            my $deny_selected_str = "";
            my $group_selected_str = "";
            my $fieldname = $current_timerange . ":" . $current_acl;

            if($users_acl_deny_list =~ m/($fieldname,)/) {
                $deny_selected_str = " selected='selected' ";
            }elsif($users_acl_allow_list =~ m/($fieldname,)/) {
                $allow_selected_str = " selected='selected' ";
            }else {
                $group_selected_str = " selected='selected' ";
            }

            #  note here - at the moment the value group simlpy means "skip this value"
            $tablerow{$current_timerange} =
                "<select name=\"" . $fieldname . "\">"
                . "<option value='true' $allow_selected_str > Yes</option>"
                . "<option value='false' $deny_selected_str >No</option>"
                . "<option value='group' $group_selected_str >-</option></select>";
            $table_html .= "<td>" . $tablerow{$current_timerange} . "</td>";
        }

        $table_html .= "</tr>";
    }

    $table_html .= "</table>";

    return $table_html;

}

#
# This will generate lines for the /etc/htb-gen/htb-gen-groups
#
#
sub make_htbgroup {
    my $retstr = "";
    my $groupclassid = shift;
    my $current_group = get_grouprec_by_classid($groupclassid);
    

    my $groupname = $current_group->key;
    my $parent_class = $current_group->prop("BWLimitParentGroupClass") || "root";
    my $parent_class_down =     '$c_parent_d';
    my $parent_class_up = '$c_parent_u';
    if($parent_class ne "root") {
        $parent_class_down = $parent_class;
        $parent_class_up = int($parent_class) + 1;
    }


    $retstr .= '_do_conf $backend "parent" "' . $groupname . '_down" '
        .  $current_group->prop("BWLimitGroupRateDown") . ' '
        .  $current_group->prop("BWLimitGroupCeilDown") . ' '
        . ' "24" '
        . $current_group->prop("BWGroupClassID") . ' '
        . $parent_class_down .  '  $iface_down false ' . "\n";

    my $up_classid = int($current_group->prop("BWGroupClassID")) + 1;

    $retstr .= '_do_conf $backend "parent" "' . $groupname . '_up" '
        .  $current_group->prop("BWLimitGroupRateUp") . ' '
        .  $current_group->prop("BWLimitGroupCeilUp") . ' '
        . ' "24" '
        . $up_classid . ' '
        . $parent_class_up . '  $iface_up false ' . "\n";

    #now run for any child classes
    my @childclassarr = get_group_childclasses_by_classid($groupclassid);
    for my $current_child_id(@childclassarr) {
	$retstr .= make_htbgroup($current_child_id);
    }
    
    return $retstr;
}


sub get_group_childclasses_by_classid {
    my $parentid = shift;
    my @retval = ();
    my @grouplist = $adb->groups;
    for my $current_group (@grouplist) {
	my $current_parentclass = $current_group->prop("BWLimitParentGroupClass") || "-";
	if($current_parentclass eq $parentid) {
		push(@retval, $current_group->prop("BWGroupClassID"));
	}
    }

    return @retval;
    
}

sub get_grouprec_by_classid {
    my $groupclassid = shift;
    my @grouplist = $adb->groups;
    for my $current_group (@grouplist) {
        my $currentgroupid = $current_group->prop("BWGroupClassID") || "";
        if($currentgroupid eq $groupclassid) {
                return $current_group;
        }
    }

    return 0;
}

sub get_htbparent_for_username {
    my $username = shift;
    my $username_rec = $adb->get($username);
    my $username_count_grp = $username_rec->prop("BWLimitCountGroup") || "";
    if($username_count_grp eq "unsorted" || $username_count_grp eq "") {
	return "0";
    }

    my $foundit = 0;
    my $grp_to_check = $username_count_grp;
    while($foundit != 1) {
	my $group_rec = $adb->get($grp_to_check);
        if($group_rec->prop("BWLimitGroupIsClass") eq "y") {
	    return $group_rec->prop("BWGroupClassID");
        }elsif($group_rec->prop("BWLimitParentGroupClass") eq "root" || $group_rec->prop("BWLimitParentGroupClass")  eq "")  {
	    #there is no parent class
	    return "0";
        }

        $grp_to_check = $group_rec->prop("BWLimitParentGroupClass");
    }
}


#
# Will check if check_group is anyway under target_group
# return 1 if there is a circular reference, 0 otherwise
#
sub check_group_for_circularref {
    my $target_group = shift;
    my $check_group = shift;
    
    my $foundroot = 0;
    my $currentclass = get_grouprec_by_classid($check_group);
  
    while($foundroot == 0) {
	my $current_parentclassid = $currentclass->prop("BWLimitParentGroupClass");
	
        if($current_parentclassid eq "root" || $current_parentclassid eq "") {
	    return 0;
	}elsif($current_parentclassid eq $target_group) {
	    #this is a circular reference potential
	    return 1;
	}else {
	    $currentclass = get_grouprec_by_classid($current_parentclassid);
	}
    }
}


sub htbgroup_remove_circular_ref {

    my @group_list = $adb->groups;
    for my $current_group (@group_list) {
        my $foundroot = 0;
        my $current_ishtb = $current_group->prop("BWLimitGroupIsClass")     || "n";
        my $current_htbid = $current_group->prop("BWGroupClassID");

        print "Checkin $current_htbid \n";
        my $grp_to_check = $current_group;
        if($current_ishtb eq "y") {
            my $foundcircular = 0;
            my $foundinvalidparent = 0;
            my @classes_seen = ();

            while($foundroot == 0) {
                    my $ishtb = $grp_to_check->prop("BWLimitGroupIsClass") || "n";
                    my $check_htbid	= $grp_to_check->prop("BWGroupClassID");

                    if($ishtb eq "y") {
                            my $bwlimit_parentclass = $grp_to_check->prop("BWLimitParentGroupClass") || "root";
                            if($bwlimit_parentclass eq "root") {
                                    $foundroot = 1;
                            #}elsif($grp_to_check->prop("BWLimitParentGroupClass") eq $current_htbid) {
                            }elsif ( my @found = grep { $_ eq $check_htbid } @classes_seen ) {
                                    #this is circular
                                    $foundcircular = 1;
                                    $foundroot = 1;
                            }else {
                                   	$grp_to_check = get_grouprec_by_classid($grp_to_check->prop("BWLimitParentGroupClass"));
                            }
                    }else {
                            #this is now an invalid creation -
                            $foundinvalidparent = 1;
                            $foundroot = 1;
                    }

                    push(@classes_seen, $check_htbid);
            }

	    if($foundinvalidparent == 1 || $foundcircular == 1) {
                    #Something is wrong - set parent to be root
                    $current_group->set_prop("BWLimitParentGroupClass", "root");
            }
        }
    }
}

#
# Checks that the admin has not assigned a rate lower than the ceiling (invalid)
#
# Returns OK if all is OK, a string otherwise
#
sub validate_rate_ceil {
        my ($q, $ratefieldname, $ceilfieldname) = @_;

	my $ratedownstr = $q->param($ratefieldname);
	my $ceildownstr = $q->param($ceilfieldname);

	my $valid_ratemsg = validate_bwamount($ratedownstr, 2);
	if($valid_ratemsg ne "OK") {
		return $valid_ratemsg;
	}

	my $valid_ceilmsg = validate_bwamount($ceildownstr, 10);
	if($valid_ceilmsg ne "OK") {
		return $valid_ceilmsg;
	}

	

        my $ratedown = int($ratedownstr);
       	my $ceildown = int($ceildownstr);
	

        if($ratedown > $ceildown) {
                return "Error - Max rate must be greater than or equal to allocated rate";
        }

        return "OK";
}

sub validate_rate_ceil_group {
	my ($q, $ratefieldname, $ceilfieldname) = @_;
	my $rate_check_msg = validate_rate_ceil($q, $ratefieldname, $ceilfieldname);
	if($rate_check_msg ne "OK") {
		return $rate_check_msg;
	}

	#now check vs the rate defaults for users
	my $defratefieldname = "BWLimitRateDown";
	my $defceilfieldname = "BWLimitCeilDown";	
	if($ratefieldname eq "BWLimitGroupRateUp") {
		$defratefieldname = "BWLimitRateUp";
		$defceilfieldname = "BWLimitCeilUp";
	}


	if(int($q->param($defratefieldname)) > int($q->param($ratefieldname)))  {
		return "Error - default user allocation greater than group allocation";
	}

	if(int($q->param($defceilfieldname)) > int($q->param($ceilfieldname))) {
		return "Error - default user max rate greater than group max rate";	
	}

	return "OK";

}

sub validate_bwamount {
	my $entry = shift;
	my $min = shift;
	if($entry =~ /^\d+$/) {
		#its an ok numbebr

		my $intval = int($entry);	
		if($intval < $min) {
			return "Value too low - must be greater than $min";
		}
	}else {
		return "Not a valid integer";
	}

	return "OK";
}

1;

