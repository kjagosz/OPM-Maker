package OPM::Maker::Command::dependencies;

# ABSTRACT: List dependencies of OTRS packages

use strict;
use warnings;

use Carp qw(croak);
use XML::LibXML;

use OPM::Maker -command;
use OPM::Maker::Utils qw(reformat_size);

sub abstract {
    return "list dependencies for OPM packages";
}

sub usage_desc {
    return "opmbuild dependencies <path_to_sopm_or_opm>";
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    
    $self->usage_error( 'need path to .sopm or .opm' ) if
        !$args or
        'ARRAY' ne ref $args or
        !defined $args->[0] or
        $args->[0] !~ /\.s?opm\z/ or
        !-f $args->[0];
}

sub execute {
    my ($self, $opt, $args) = @_;
    
    my $file = $args->[0];

    my %opts;
    if ( !$ENV{OPM_UNSECURE} ) {
        %opts = (
            no_network      => 1,
            expand_entities => 0,
        );
    }

    my $size = -s $file;

    # if file is big, but not "too big"
    my $max_size = 31_457_280;
    if ( $ENV{OPM_MAX_SIZE} ) {
        $max_size = reformat_size( $ENV{OPM_MAX_SIZE} );
    }

    if ( $size > $max_size ) {
        croak "$file too big (max size: $max_size bytes)";
    }

    if ( $size > 10_000_000 ) {
        $opts{huge} = 1;
    }

    my $parser = XML::LibXML->new( %opts );
    my $tree   = $parser->parse_file( $file );
        
    my $root_elem = $tree->getDocumentElement;

    # retrieve file information
    my @package_req = $root_elem->findnodes( 'PackageRequired' );
    my @modules_req = $root_elem->findnodes( 'ModuleRequired' );
    
    my %labels = (
        PackageRequired => 'OPM package',
        ModuleRequired  => 'CPAN module',
    );
        
    DEP:
    for my $dependency ( @package_req, @modules_req ) {
        my $type    = $dependency->nodeName;
        my $version = $dependency->findvalue( '@Version' );
        my $name    = $dependency->textContent;
        
        print "$name - $version (" . $labels{$type} . ")\n";
    }
}

1;
