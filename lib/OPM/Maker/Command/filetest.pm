package OPM::Maker::Command::filetest;

# ABSTRACT: check if filelist in .sopm includes the files on your disk

use strict;
use warnings;

use Carp qw(croak);
use File::Find::Rule;
use Path::Class ();
use XML::LibXML;

use OPM::Maker -command;
use OPM::Maker::Utils qw(
    reformat_size
    check_args_sopm
    read_ignore_file
);

sub abstract {
    return "Check if filelist in .sopm includes the files on your disk";
}

sub usage_desc {
    return "opmbuild filetest <path_to_sopm>";
}

sub validate_args {
    my ($self, $opt, $args) = @_;

    my $sopm = check_args_sopm( $args );
    
    $self->usage_error( 'need path to .sopm' ) if
        !$sopm;
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $file = check_args_sopm( $args );

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
    
    my $sopm_path = Path::Class::File->new( $file );
    my $path      = $sopm_path->dir;
    
    my $path_str     = $path->stringify;
    my $ignore_files = File::Find::Rule->file->name(".*");    
    my @files_in_fs  = File::Find::Rule->file
        ->not( $ignore_files )
        ->in ( $path_str );
    
    my %fs = map{ $_ =~ s{\A\Q$path_str\E/?}{}; $_ => 1 }
        grep{ $_ !~ /\.git|CVS|svn/ }@files_in_fs;
        
    delete $fs{ $sopm_path->basename };
    
    my $root_elem = $tree->getDocumentElement;
    
    # retrieve file information
    my @files = $root_elem->findnodes( 'Filelist/File' );
    
    my @not_found;
    
    FILE:
    for my $file ( @files ) {
        my $name = $file->findvalue( '@Location' );
        
        push @not_found, $name if !delete $fs{$name};
    }
    
    if ( @not_found ) {
        print "Files listed in .sopm but not found on disk:\n",
            map{ "    - $_\n" }@not_found;
    }
    
    if ( %fs ) {
        print "Files found on disk but not listed in .sopm:\n",
            map{ "    - $_\n" }sort keys %fs;
    }
}

1;
