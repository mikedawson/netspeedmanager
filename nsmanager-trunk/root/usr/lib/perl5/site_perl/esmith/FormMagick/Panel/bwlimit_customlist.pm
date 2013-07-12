#!/usr/bin/perl -w
 package    esmith::FormMagick::Panel::bwlimit_customlist;

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
          "<p><a class=\"button-like\" href=\"bwlimit_customlist?page=0&wherenext=BWLIMIT_NEW_CUSTOMLIST\">"
          . $fm->localise("CREATE_CUSTOM_LIST")
          . "</a></p>"));

}

sub print_remove_text 
 {
    my $self = shift;
    my $q = $self->{cgi};
    my $sitelist_name = $q->param("CustomListName") =~ m/([\d\w]+)$/;;
    $sitelist_name = $1;
  
    print "<input type='hidden' name='CustomListName' value='$sitelist_name'/>\n";
    print "<p>Are you sure you want to remove $sitelist_name list ?</p>\n";
}
	

sub print_bwlimit_customlist_table
 {
     my $self = shift;
     my $q = $self->{cgi};

     my $bwlimits_customlist_table =
     {
        title => $self->localise('BWLIMIT_CUSTOM_LISTS'),

        stripe => '#D4D0C8',

        fields => [ qw(CustomListName Modify Remove) ],

        labels => 1,

        field_attr => {
                        CustomListName => { label => $self->localise('LABEL_CUSTOMLIST_NAME') },

                        Modify => {
                                    label => $self->localise('MODIFY'),
                                    link => \&modify_link },
                        Remove => {
                                    label => $self->localise('REMOVE'),
                                    link => \&delete_link },
                      },
                        

     };

     my @data = ();

     my $modify = $self->localise('MODIFY');
     my $remove = $self->localise('REMOVE');

     my $bwaclprop = $db->get("BWLimitACLs") or die "No BWLimitACLs Property!";
     my $bwaclpropval = $bwaclprop->value;
     my @bwacl_list = split(/,/, $bwaclpropval);

     
     for my $bwaclprop (@bwacl_list)
     {

        #should start with timerange_time_
        if($bwaclprop =~ m/^squid_custom_(.*)$/) {
            my $customlist_name = $bwaclprop;
            $customlist_name =~ m/^squid_custom_(.*)/;
            $customlist_name = $1;

             push @data,
                 {


                    CustomListName => $customlist_name,

                    Modify => 'Modify',

                    Remove => 'Remove',
                    
                 }
        }
     }

     my $t = HTML::Tabulate->new($bwlimits_customlist_table);

     $t->render(\@data, $bwlimits_customlist_table);
 }

#
# This opens up the list of sites and puts it into a textarea...
#
sub print_sitelist {
    my $self = shift;
    my $q = $self->{cgi};
    my $sitelist_name = $q->param("CustomListName") =~ m/([\d\w]+)$/;;
    $sitelist_name = $1;

    my $filepath = "/usr/lib/bwlimit/customlists/" . $sitelist_name;
    open(my $filehandle, "<", $filepath);
    print "<tr><td class='sme-noborders-label'>Sites in List</td><td class='sme-noborders-content'>";
    print "<TEXTAREA NAME=\"CustomListSites\" ROWS=\"5\" COLS=\"60\">";
    print <$filehandle>;
    print "</textarea></td></tr>";
}

sub modify_bwlimit_customlist
 {
     my $self = shift;
     my $q = $self->{cgi};

     # find first the name of the list
     my $bwlimit_customlist_name = $q->param("CustomListName") =~ m/([\d\w]+)$/;
     $bwlimit_customlist_name = $1;
     

     my $bwlimit_customlist_sitelist = $q->param("CustomListSites") =~ m/([\d\w\s\.]+)$/;
     $bwlimit_customlist_sitelist = $1;

     # save the list to disk
     my $filepath = "/usr/lib/bwlimit/customlists/" . $bwlimit_customlist_name;
     open(my $filehandle, '>', $filepath);
     printf $filehandle $bwlimit_customlist_sitelist;
     close($filehandle);

     # check/update the ACL property
     my $aclproperty = $db->get("BWLimitACLs") or die "No BW Limit ACLs property";
     my $aclproperty_value = $aclproperty->value;
     # todo: include comma in this match
     my $list_already_exists = 0;
     if($aclproperty_value =~ m/$bwlimit_customlist_name/) {
	$list_already_exists = 1;
        # is already here - do nothing
     }else {
        my $new_acl_property_value = "squid_custom_" . $bwlimit_customlist_name
            . "," . $aclproperty_value;
        $aclproperty->set_value($new_acl_property_value);
     }
     
     # when we are doing a modify opertion we only need make squid reload
     if ($list_already_exists == 1) {
	     system( "/etc/init.d/squid", "reload" );
     }else {
	system("/sbin/e-smith/expand-template", "/etc/squid/squid.conf");
	system( "/etc/init.d/squid", "reload" );
     }

     return $self->success('SUCCESSFULLY_MODIFIED');
}

sub delete_link
{
     my ($data_item, $row, $field) = @_;

     return "bwlimit_customlist?" .
             join("&",
                 "page=0",
                 "page_stack=",
                 "Next=Next",
                 "CustomListName="     . $row->{CustomListName},
                 "wherenext=BWLIMIT_REMOVE_CUSTOMLIST");
}

sub modify_link
 {
     my ($data_item, $row, $field) = @_;

     return "bwlimit_customlist?" .
             join("&",
                 "page=0",
                 "page_stack=",
                 "Next=Next",
                 "CustomListName="     . $row->{CustomListName},
                 "wherenext=BWLIMIT_MODIFY_CUSTOMLIST");
 }

sub remove_customlist
{
    my $self = shift;
    my $q = $self->{cgi};

    my $list_to_remove = $q->param("CustomListName");


    my $current_bw_list_property = $db->get("BWLimitACLs");
    my $current_bw_list = $current_bw_list_property->value;
    my $token_to_remove = "squid_custom_" . $list_to_remove . ",";
    my @current_bw_list_tokens = split(/,/, $current_bw_list);

    my $new_bw_list = "";

    for my $current_bw_list_token (@current_bw_list_tokens) {
	$current_bw_list_token .= ",";
	if($current_bw_list_token eq $token_to_remove) {
		#do nothing
	}else {
		$new_bw_list .= $current_bw_list_token;
	}
    }

    
    $current_bw_list_property->set_value($new_bw_list);

    #now go and	update the config and apply to squid
    system ("/sbin/e-smith/expand-template", "/etc/squid/squid.conf");
    system ("/etc/init.d/squid", "reload");

         return $self->success('SUCCESSFULLY_REMOVED');


}

sub check_customlist_name {
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
