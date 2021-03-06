package WWW::Mailchimp;
use Moose;
use LWP;
use JSON;
use URI;
use URI::QueryParam;

our $VERSION = '0.004';
$VERSION = eval $VERSION;

=head1 NAME

WWW::Mailchimp - Perl wrapper around the Mailchimp v1.3 API

=head1 SYNOPSIS

  use strict;
  use WWW::Mailchimp

  my $mailchimp = WWW::Mailchimp->new(apikey => $apikey);
  # defaults ( datacenter => 'us1', timeout => 5, output_format => 'json', api_version => 1.3 )

  my $campaigns = $mailchimp->campaigns;
  my $lists = $mailchimp->lists;
  my $subscribers = $mailchimp->listMembers( $lists->[0]->{id} );
  my $ok = $mailchimp->listSubscribe( id => $lists->[0]->{id}, 
                                      email_address => 'foo@bar.com',
                                      update_existing => 1,
                                      merge_vars => [ FNAME => 'foo',
                                                      LNAME => 'bar' ] );

=head1 DESCRIPTION

WWW::Mailchimp is a simple Perl wrapper around the Mailchimp API v1.3.
  
It is as simple as creating a new WWW::Mailchimp object and calling ->method
Each key/value pair becomes part of POST content, for example:

  $mailchimp->listSubscribe( id => 1, email_address => 'foo@bar.com' );

results in the query

  ?method=listSubscribe # GET URI
  # POST CONTENT
  id=1&email_address=foo@bar.com
  # apikey, output, etc are tacked on by default. This is also uri_escaped

=head1 BUGS

Currently, this module is hardcoded to JSON::from_json the result of the LWP request.
This should be changed to be dependent on the output_format. Patches welcome.

I am also rather sure handling of merge_vars can be done better. If it isn't working
properly, you can always use a key of 'merge_vars[FNAME]', for example.

=head1 SEE ALSO

Mail::Chimp::API - Perl wrapper around the Mailchimp v1.2 API using XMLRPC

=head1 AUTHOR

Justin Hunter <justin.d.hunter@gmail.com>

Fayland Lam

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Justin Hunter

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

has api_version => (
  is => 'ro',
  isa => 'Num',
  lazy => 1,
  default => 1.3,
);

has datacenter => (
  is => 'rw',
  isa => 'Str',
  lazy => 1,
  default => 'us1',
);

has apikey => (
  is => 'ro',
  isa => 'Str',
  required => 1,
  trigger => sub {
    my ($self, $val) = @_;
    my ($datacenter) = ($val =~ /\-(\w+)$/);
    $self->datacenter($datacenter)
  },
);

has api_url => (
  is => 'rw',
  isa => 'Str',
  lazy => 1,
  default => sub { my $self = shift; return 'https://' . $self->datacenter . '.api.mailchimp.com/' . $self->api_version . '/'; },
);

has output_format => (
  is => 'rw',
  isa => 'Str',
  lazy => 1,
  default => 'json',
);

has ua => (
  is => 'ro',
  isa => 'LWP::UserAgent',
  lazy => 1,
  builder => '_build_lwp',
  handles => [ qw(post) ],
);

has timeout => (
  is => 'rw',
  isa => 'Int',
  lazy => 1,
  default => 5,
);

sub _build_lwp {
  my $self = shift;
  my $ua = LWP::UserAgent->new( timeout => $self->timeout, agent => __PACKAGE__ . ' ' . $VERSION );
}

has 'json' => (
    is => 'ro',
    isa => 'JSON',
    lazy_build => 1,
);

sub _build_json { JSON->new->allow_nonref }

sub _build_query_args {
  my ($self, %args) = @_;
  my %merge_vars = @{delete $args{merge_vars} || []};
  for my $var (keys %merge_vars) {
    if (ref($merge_vars{$var}) eq 'ARRAY') {
      my $count = 0; 
      for my $val (@{$merge_vars{$var}}) {
        $args{"merge_vars[$var][$count]"} = $val;
        $count++;
      }
    } else {
      $args{"merge_vars[$var]"} = $merge_vars{$var};
    }
  }
  
  return %args;
}

sub _request {
  my $self = shift;
  my $method = shift;
  my %args = ref($_[0]) ? %{$_[0]} : @_;

  %args = $self->_build_query_args(apikey => $self->apikey, output => $self->output_format, %args);
  
  my $uri = URI->new( $self->api_url );
  $uri->query_form_hash(method => $method); # method must be in GET

  # use POST to fix '414 Request-URI Too Large'
  my $response = $self->post( $uri->canonical, \%args );
  return $response->is_success ? $self->json->decode($response->content) : $response->status_line;
}

my @api_methods = qw(
  campaignContent
  campaignCreate
  campaignDelete
  campaignEcommOrderAdd
  campaignPause
  campaignReplicate
  campaignResume
  campaignSchedule
  campaignSegmentTest
  campaignSendNow
  campaignSendTest
  campaignShareReport
  campaignTemplateContent
  campaignUnschedule
  campaignUpdate
  campaigns
  campaignAbuseReports
  campaignAdvice
  campaignAnalytics
  campaignBounceMessage
  campaignBounceMessages
  campaignClickStats
  campaignEcommOrders
  campaignEepUrlStats
  campaignEmailDomainPerformance
  campaignGeoOpens
  campaignGeoOpensForCountry
  campaignHardBounces
  campaignMembers
  campaignSoftBounces
  campaignStats
  campaignUnsubscribes
  campaignClickDetailAIM
  campaignEmailStatsAIM
  campaignEmailStatsAIMAll
  campaignNotOpenedAIM
  campaignOpenedAIM
  ecommOrderAdd
  ecommOrderDel
  ecommOrders
  folderAdd
  folderDel
  folderUpdate
  folders
  campaignsForEmail
  chimpChatter
  generateText
  getAccountDetails
  inlineCss
  listsForEmail
  ping
  listAbuseReports
  listActivity
  listBatchSubscribe
  listBatchUnsubscribe
  listClients
  listGrowthHistory
  listInterestGroupAdd
  listInterestGroupDel
  listInterestGroupUpdate
  listInterestGroupingAdd
  listInterestGroupingDel
  listInterestGroupingUpdate
  listInterestGroupings
  listLocations
  listMemberActivity
  listMemberInfo
  listMembers
  listMergeVarAdd
  listMergeVarDel
  listMergeVarUpdate
  listMergeVars
  listStaticSegmentAdd
  listStaticSegmentDel
  listStaticSegmentMembersAdd
  listStaticSegmentMembersDel
  listStaticSegmentReset
  listStaticSegments
  listSubscribe
  listUnsubscribe
  listUpdateMember
  listWebhookAdd
  listWebhookDel
  listWebhooks
  lists
  apikeyAdd
  apikeyExpire
  apikeys
  templateAdd
  templateDel
  templateInfo
  templateUndel
  templateUpdate
  templates
);

for my $method (@api_methods) {
  __PACKAGE__->meta->add_method( $method => sub { shift->_request($method, @_) } );
}

1;

