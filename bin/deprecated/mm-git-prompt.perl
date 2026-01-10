#!/usr/bin/env mm-perl

use strict;
use warnings;
use Getopt::Long;
use YAML    qw( LoadFile Dump DumpFile );
use Cwd;
use POSIX   qw( strftime );

# Usage:        bash:   export PS1='$(git-prompt)'
#               tcsh:   alias precmd 'set prompt=`git-prompt \!`'
#
#               interactive:
#                   git-prompt [options] [on|off]   toggle prompt generation for the current git repository
#
#                   --configuration                 display the current configuration and quit
#                   --max_status_delay <seconds>    automatically disable status summaries if they take longer than <seconds>
#
# Description:  check for a git repository and return the current branch and
#               status information in a prompt-friendly format.
#               The examples above are minimal - merge them with your existing
#               prompt as you wish.
#               If you want colors, modify the values of %flag_map or the
#               printf on the last line to suit your taste.
#
# Note:         tcsh expands ! to the current history sequence number.
#               Any characters specified on the command line will be escaped,
#               thus providing a workaround for tcsh users :-)
#
# Author:       Stephen Riehm <japh@opensauce.de>
# Date:         2009-01-30
# Version:      1.0
# Requirements: (tested)
#               git     1.6.* .. 1.6.1.3
#               perl    5.6.* .. 5.10.0

my $repo_id            = get_repo_id() or exit 0;
my $preferences_file   = "$ENV{HOME}/.git_prompt";
my $all_preferences    = load_preferences(
                                        file     => $preferences_file,
                                        repo_id  => $repo_id,
                                        defaults => { # 'factory' defaults
                                                        escape_characters   => $ENV{SHELL} =~ /csh/i ? '!' : '',
                                                        max_status_delay    => 3,         # seconds
                                                        show_status_summary => 'yes',     # yes, no, or maybe
                                                        try_again_delay     => 0,
                                                        number_of_timeouts  => 0,
                                                        last_timeout        => 0,
                                                        },
                                        ignore   => {
                                                        # only for legacy config files
                                                        last_update           => 1,
                                                        last_timeout_duration => 1,
                                                        },
                                        );

my $active_preferences = $all_preferences->{ACTIVE};

my $cli_preferences = {};
GetOptions( $cli_preferences,
        'configuration',                    # display the current configuration and quit
        'escape_characters|escape_chars:s', # output a \ before these characters to avoid confusing the shell
        'max_status_delay=i',               # how long to wait before automatically disabling status details in prompt
        'show_status_summary',              # set to 0 if git status takes too long to run in the command prompt
        'help',
        )
    or show_usage();

show_usage()    if $cli_preferences->{help};

my $command = shift || undef;
$command //= 'show_configuration'    if delete $cli_preferences->{configuration};
$command //= 'update_configuration'  if exists $cli_preferences->{escape_characters};
$command //= 'update_configuration'  if exists $cli_preferences->{max_status_delay};
$command //= 'prompt';

$active_preferences->{show_status_summary} = $cli_preferences->{show_status_summary} if exists $cli_preferences->{show_status_summary};
$active_preferences->{escape_characters}   = $cli_preferences->{escape_characters}   if exists $cli_preferences->{escape_characters};
$active_preferences->{max_status_delay}    = $cli_preferences->{max_status_delay}    if exists $cli_preferences->{max_status_delay};

if( $active_preferences->{show_status_summary} =~ /(\d+)/ )
    {
    $active_preferences->{show_status_summary} = $1 ? 'yes' : 'no';
    }

if( $command =~ /^(?:on|off)$/i )
    {
    $active_preferences->{show_status_summary} = ( $command =~ /on/i ) ? 'yes' : 'no';
    printf "git status prompt turned %s for %s\n", uc( $command ), $repo_id;
    }
elsif( 'show_configuration' =~ /${command}/i )  # backward expression to allow user to type any substring
    {
    show_preferences( preferences => $all_preferences );
    exit 0;
    }
elsif( 'update_configuration' =~ /${command}/i )  # backward expression to allow user to type any substring
    {
    show_preferences( preferences => $active_preferences );
    }
elsif( 'prompt' =~ /${command}/i )              # backward expression to allow user to type any substring
    {
    generate_prompt( active_preferences => $active_preferences );
    }

store_preferences(
                file            => $preferences_file,
                repo_id         => $repo_id,
                all_preferences => $all_preferences,
                );

exit 0;

sub get_repo_id
    {
    # don't do anything if git isn't installed
    return  unless grep( -x "$_/git", split( /:/, $ENV{PATH} ) );

    # also don't do anything if there isn't a .git directory in a parent directory
    my $repo_dir = cwd() . "/.";
    while( $repo_dir =~ s:/+[^/]*$:: )
        {
        last    if -d "${repo_dir}/.git";
        return  if $repo_dir eq '';
        }

    # use the directory as an ID
    # a hash value may be a better idea
    return $repo_dir;
    }

sub generate_prompt
    {
    my $params             = { @_ };
    my $active_preferences = $params->{active_preferences};

    # ignore git's errors
    close( STDERR );

    # status flags:
    #   ## <branch>
    #   XY <file>
    # if X is not a space, set the '!' flag (something is staged)
    # if Y is not a space, set a flag depending on the character:
    #       A   =>  '+' (there are untracked files)
    #       D   =>  '-' (some tracked files are missing)
    # anything else '?' (something has changed)
    my %flag_map = (
            staged    => '!',
            updated   => '?',
            added     => '+',
            deleted   => '-',
            undefined => '~',   # status not checked, is undefined
            );
    my @ordered_flags = @flag_map{qw( added deleted updated staged undefined )};

    my $branch = undef;
    my %flag = ();

    if( $active_preferences->{show_status_summary} eq 'maybe'
        and time() > ( $active_preferences->{last_timeout} + $active_preferences->{try_again_delay} )
        )
        {
        $active_preferences->{show_status_summary} = 'yes';
        }

    if( $active_preferences->{show_status_summary} eq 'yes' )
        {
        my $start_time = time();

        foreach my $line ( qx{ git status --porcelain --branch } )
            {
            if( $line =~ /##\s+(?<branch>\S+?)(?:\.\.\..*)?\s*$/ )
                {
                $branch = $+{branch};
                next;
                }
            $line =~ /^(?<idx>.)(?<ws>.)/;
            $flag{'!'}++                             if $+{idx} ne ' ';
            $flag{ $+{ws} =~ tr/?ADCMU/++\-???/r }++ if $+{ws}  ne ' ';
            }

        my $duration = time() - $start_time;
        if( $active_preferences->{max_status_delay} and $duration > $active_preferences->{max_status_delay} )
            {
            $active_preferences->{show_status_summary}    = 'maybe';
            $active_preferences->{last_timeout_duration}  = $duration;
            $active_preferences->{number_of_timeouts}    += 1;
            $active_preferences->{last_timeout}           = time();
            $active_preferences->{try_again_delay}        = $duration / $active_preferences->{max_status_delay}
                                                            * $active_preferences->{number_of_timeouts} * 60; # seconds
            }
        }
    else
        {
        # just show the branch name or latest tag name if status information isn't desired
        ( $branch ) = grep( s/^\*\s+//, qx{ git branch } );
        chomp( $branch );
        $branch = undef     if $branch =~ /\(no branch\)/i;
        $branch = $1        if $branch =~ /\(detached from (.*)\)/i; # this started about v1.8.3 ?
        $flag{ $flag_map{undefined} }++;
        }

    # if git branch or git status didn't return a useful result - see if the user has
    # checked out a tagged version (without creating a branch)
    if( not $branch )
        {
        my $description = qx{ git describe };
        chomp( $description );
        $branch = sprintf "'%s'", $description  if $description;
        }

    if( not $branch )
        {
        my $commit = qx{ git log --format=format:%h -n 1 };
        $branch = sprintf "'%s'", $commit;
        }

    # determine which flags to display (if any)
    my $flags        =  join( '', map { exists( $flag{$_} ) and $_ } @ordered_flags );      # ensure the flags always appear in the same order
    my $escape_chars =  $active_preferences->{escape_characters};                           # only for tcsh users
    $flags           =~ s/[$escape_chars]/\\$&/g                if $escape_chars;           # only for tcsh users

    # generate  the prompt
    printf "(%s%s)", $branch, ( $flags ? "[$flags]" : "" )      if $branch;

    return;
    }

sub show_preferences
    {
    my $params = { @_ };
    print "Configuration:\n";
    print Dump( $params->{preferences} );
    }

sub load_preferences
    {
    my $params          = { @_ };
    my $preference_file = $params->{file};
    my $defaults        = $params->{defaults};
    my $ignore          = $params->{ignore};
    my $repo_id         = $params->{repo_id};

    my $all_preferences    = ( -e $preference_file ) ? LoadFile( $preference_file ) : { GLOBAL => $defaults };
    my $active_preferences = { %{$defaults} };

    $all_preferences->{GLOBAL}{$_} = $defaults->{$_}  foreach grep( ( not exists $all_preferences->{GLOBAL}{$_} ), keys %{$defaults} );
    $all_preferences->{ACTIVE}     = $active_preferences;

    foreach my $preference_set_index ( 'GLOBAL', $repo_id )
        {
        next    unless exists $all_preferences->{$preference_set_index};

        my $preference_set = $all_preferences->{$preference_set_index};
        foreach my $preference ( sort keys %{$preference_set} )
            {
            # accept known preferences
            if( exists $defaults->{$preference} )
                {
                $active_preferences->{$preference} = $preference_set->{$preference};
                next;
                }

            # ignore known 'informational' preferences
            next if( exists $ignore->{$preference} );

            # complain that the user used an unknown preference
            printf STDERR "WARNING: unsupported git-prompt preference '%s' found in %s\n", $preference, $preference_file;
            }
        }

    return $all_preferences;
    }

sub store_preferences
    {
    my $params          = { @_ };
    my $file            = $params->{file};
    my $all_preferences = $params->{all_preferences};
    my $repo_id         = $params->{repo_id};

    my $global_preferences   = $all_preferences->{GLOBAL};
    my $active_preferences   = delete $all_preferences->{ACTIVE}; # don't write these to disk
    my $old_repo_preferences = delete $all_preferences->{$repo_id};
    my $new_repo_preferences = {};

    my $need_update = 0;
    foreach my $preference ( keys %{$active_preferences} )
        {
        if( $active_preferences->{$preference} ne $global_preferences->{$preference} )
            {
            $new_repo_preferences->{$preference} = $active_preferences->{$preference};
            }

        if( not defined $old_repo_preferences->{$preference}
            or $active_preferences->{$preference} ne $old_repo_preferences->{$preference} )
            {
            $need_update = 1;
            }
        }

    # special case: escape_characters are always global
    if( exists $new_repo_preferences->{escape_characters} )
        {
        $global_preferences->{escape_characters} = delete $new_repo_preferences->{escape_characters};
        }

    # update the preference file if requested or required
    if( $need_update )
        {
        if( keys %{$new_repo_preferences} )
            {
            $all_preferences->{$repo_id} = $new_repo_preferences;
            }
        DumpFile( $file, $all_preferences );
        }
    }

sub show_usage
    {
    print <<_EO_USAGE;
Usage:        bash:   export PS1='$(git-prompt)'
              tcsh:   alias precmd 'set prompt=`git-prompt \!`'

              interactive:
                  git-prompt [options]

                  --configuration                 display the current configuration and quit
                  --max_status_delay <seconds>    automatically disable status summaries if they take longer than <seconds>

Description:  check for a git repository and return the current branch and
              status information in a prompt-friendly format.
              The examples above are minimal - merge them with your existing
              prompt as you wish.
              If you want colors, modify the values of %flag_map or the
              printf on the last line to suit your taste.

Note:         tcsh expands ! to the current history sequence number.
              Any characters specified on the command line will be escaped,
              thus providing a workaround for tcsh users :-)

Known Bugs:   if you remove a file, the flags '-' AND '?' appear - this is
              not intended, but fixing it would make this script MUCH more
              complicated than it is now.

Author:       Stephen Riehm
Date:         2009-01-30
Version:      1.0
Requirements: (tested)
              git     1.6.* .. 1.6.1.3
              perl    5.6.* .. 5.10.0
_EO_USAGE
    exit 1;
}

exit 0;
