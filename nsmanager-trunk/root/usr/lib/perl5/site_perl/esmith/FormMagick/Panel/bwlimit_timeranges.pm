#!/usr/bin/perl -w
 package    esmith::FormMagick::Panel::bwlimit_timeranges;
 
 use strict;
 
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
          "<p><a class=\"button-like\" href=\"bwlimit_timeranges?page=0&wherenext=BWLIMIT_PAGE_TIMERANGE_CREATE\">"
          . $fm->localise("CREATE_TIME_RANGE")
          . "</a></p>"));
 }
 
 sub print_bwlimit_timerange_table
 {
     my $self = shift;
     my $q = $self->{cgi};
 
     my $bwlimits_time_table =
     {
        title => $self->localise('BWLIMIT_CURRENT_QUOTAS'),
 
        stripe => '#D4D0C8',
 
        fields => [ qw(TimeRangeName TimeRangeTime TimeRangeRate Modify Remove) ],
 
        labels => 1,
 
        field_attr => {
                        TimeRangeName => { label => $self->localise('LABEL_TIMERANGE_NAME') },
 
                        TimeRangeTime => { label => $self->localise('LABEL_TIMERANGE_TIME') },
 
                        TimeRangeRate => { label => $self->localise('LABEL_TIMERANGE_RATE') },
 
                        Modify => {
                                    label => $self->localise('MODIFY'),
                                    link => \&modify_link },                                  
			 Remove => {
                                    label => $self->localise('REMOVE'),
                                    link => \&delete_link },
			}

            };
 
     my @data = ();
 
     my $modify = $self->localise('MODIFY');

     my $bwtimeprops = $db->get("BWLimitTimes") or die "No BWLimitTimes Property!";
 
     for my $bwtimeprop ($bwtimeprops->props)
     {

        #should start with timerange_time_
        if($bwtimeprop =~ m/^timerange_time_(.*)$/) {
            my $timerange_name = $bwtimeprop;
            $timerange_name =~ m/^timerange_time_(.*)/;
            $timerange_name = $1;

            my $timerate_propname = "timerange_rate_" . $timerange_name;

            my $timerate_record = $bwtimeprops->prop($timerate_propname)
                or die "Did not find time rate!";

             push @data,
                 {


                    TimeRangeName => $timerange_name,

                    TimeRangeTime => $bwtimeprops->prop($bwtimeprop),

                    TimeRangeRate => $timerate_record,

                    Modify => 'Modify',

		    Remove => 'Remove',	  
                 }
        }
     }
 
     my $t = HTML::Tabulate->new($bwlimits_time_table);
 
     $t->render(\@data, $bwlimits_time_table);
 }
 
sub delete_link
{
     my ($data_item, $row, $field) = @_;

     if ($row->{TimeRangeName} eq "always") {
	return "";
     }else {
	     return "bwlimit_timeranges?" .
             join("&",
                 "page=0",
                 "page_stack=",
                 "Next=Next",
                 "TimeRangeName="     . $row->{TimeRangeName},
                 "wherenext=BWLIMIT_REMOVE_TIMERANGE");
     }
}


 sub modify_link
 {
     my ($data_item, $row, $field) = @_;

     if ($row->{TimeRangeName} eq "always") {
        return "";
     }

     return "bwlimit_timeranges?" .
             join("&",
                 "page=0",
                 "page_stack=",
                 "Next=Next",
                 "TimeRangeName="     . $row->{TimeRangeName},
                 "TimeRangeData=" . $row->{TimeRangeTime},
                 "TimeRangeRate=" . $row->{TimeRangeRate},

                 "wherenext=BWLIMIT_PAGE_TIMERANGE_MODIFY");
 }
 
 sub make_timerange_string_from_query {

  my $q = shift;

  my $daystr = "";
  my @daynames = ("M", "T", "W", "H", "F", "A", "S");

  for my $current_day (@daynames) {
	my $daykey = "day_" . $current_day;
	if($q->param($daykey)) {
		if($q->param($daykey) eq "y") {
			$daystr .= $current_day;
		}
	}
  }
  my $timerange_str = $daystr . " " .
	$q->param("start_hrs") . ":" .
	$q->param("start_mins") . "-" .
	$q->param("end_hrs") . ":" .
	$q->param("end_mins");

  
  return $timerange_str;
 }


 sub modify_bwlimit_timerange
 {
     my $self = shift;
     my $q = $self->{cgi};

     #check and see if this one already
     my $bwlimit_time_rec = $db->get('BWLimitTimes');

     my $bwlimit_timerange_name = "timerange_time_" . $q->param('TimeRangeName');
     my $bwlimit_timerate_name = "timerange_rate_" . $q->param('TimeRangeName');

     $bwlimit_time_rec->set_prop($bwlimit_timerange_name, $q->param('TimeRangeData'));
     $bwlimit_time_rec->set_prop($bwlimit_timerate_name, $q->param('TimeRangeRate'));
     my $bwlimit_timerange_arg = make_timerange_string_from_query($q)
	        =~ m/([SMTWHFA]* *(\d\d:\d\d\-\d\d:\d\d)*)/;
     $bwlimit_timerange_arg = $1;


     $bwlimit_time_rec->set_prop($bwlimit_timerange_name, $bwlimit_timerange_arg);

 
#     my $bwlimit_timerange_arg = $q->param('TimeRangeData')
#        =~ m/([SMTWHFA]* *(\d\d:\d\d\-\d\d:\d\d)*)/;
#     $bwlimit_timerange_arg = $1;

     $bwlimit_timerange_arg = "'" . $bwlimit_timerange_arg . "'";

     my $bwlimit_timerange_id = $q->param('TimeRangeName') =~ m/([\d\w]+)$/;
     $bwlimit_timerange_id = $1;

     my $bwlimit_timerate = $q->param('TimeRangeRate') =~ m/(\d+\.*\d*)/;
     $bwlimit_timerate = $1;

#    print "Calling /usr/lib/bwlimit/bwlimit_set_timerange.php $bwlimit_timerange_id $bwlimit_timerange_arg $bwlimit_timerate";

     system ("/usr/lib/bwlimit/bwlimit_set_timerange.php $bwlimit_timerange_id $bwlimit_timerange_arg $bwlimit_timerate");

     system("/sbin/e-smith/expand-template", "/etc/squid/squid.conf" );
     system("/sbin/e-smith/expand-template", "/etc/squid/squidguard.conf" );
     system("/etc/init.d/squid", "reload");

     return $self->success('SUCCESSFULLY_MODIFIED');
 }

sub check_timelist_name {
        my ($fm, $data) = @_;

        if($data =~ m/(\w+)/) {
                if($1 eq $data) {
                        return "OK";
                }else {
                       	return "Invalid List Name - letters and numbers only please";
                }
        }else {
               	return "Invalid List name - letters and numbers only please";
        }

}

sub print_timecontrol {
     my $self = shift;
     my $q = $self->{cgi};

     my $timerangedata = $q->param("TimeRangeData") || "S 00:00-23:59";

     $timerangedata =~ m/(\w+) (\d\d):(\d\d)-(\d\d):(\d\d)/;
     my $daynames = $1;
     my $start_hrs = $2;
     my $start_mins = $3;
     my $end_hrs = $4;
     my $end_mins = $5;

     print '<tr><td class="sme-noborders-label">' . $self->localise("TIMERANGE") . "</td>";
     print '<td classs="sme-noborders-content">';	
     #print "Dayname = $daynames staart hrs = ";

     my @daynames = ("M", "T", "W", "H", "F", "A", "S");
     
     for my $currentday (@daynames) {
	my $checkedval = "";
	if($daynames =~ m/$currentday/) {
		$checkedval = " checked='checked' ";
	}
	
	print "<input type='checkbox' name='day_" . $currentday . "' $checkedval value='y'/>\n";
       	print $self->localise("DAYNAME_" . $currentday);


     }
	print "<br/>";
    
     make_select_number(int($start_hrs), "start_hrs", 24);
     print ":";
     make_select_number(int($start_mins), "start_mins", 60);
     print " - ";
     make_select_number(int($end_hrs), "end_hrs", 24);
     print ":";
     make_select_number(int($end_mins), "end_mins", 60);

     print "</td></tr>";

}


sub make_select_number {
     my $currentval = shift;
     my $fieldname = shift;
     my $lastnum = shift;

     print "<select name='$fieldname'>";
     for(my $i = 0; $i < $lastnum; $i++) {
	my $select_str = "";
	if($i < 10) {
		$i = "0" . $i;
	}

	if($i == $currentval) {
		$select_str = " selected='selected' ";
	}
	print "<option value='$i' $select_str >$i</option>\n";
     }
     print "</select>";
}


sub print_remove_text
 {
    my $self = shift;
    my $q = $self->{cgi};
    my $timerange_name = $q->param("TimeRangeName") =~ m/([\d\w]+)$/;;
    $timerange_name = $1;

    print "<input type='hidden' name='TimeRangeName' value='$timerange_name'/>\n";
    print "<p>Are you sure you want to remove $timerange_name list ?</p>\n";
}

sub remove_timerange
{
    my $self = shift;
    my $q = $self->{cgi};

    my $list_to_remove = $q->param("TimeRangeName")  =~ m/([\d\w]+)$/;
    $list_to_remove = $1;


    my $current_bw_list_property = $db->get("BWLimitTimes");
    $current_bw_list_property->delete_prop("timerange_rate_" . $list_to_remove);
    $current_bw_list_property->delete_prop("timerange_time_" . $list_to_remove);

    system("/usr/lib/bwlimit/bwlimit_remove_timerange.php $list_to_remove");
    system("/sbin/e-smith/expand-template /etc/squid/squid.conf");
    system("/etc/init.d/squid reload");
    return $self->success('SUCCESSFULLY_REMOVED');

}
 
 # 1;
