#
# Copyright (c) 1996, 1997, 1998 Shigio Yamaguchi. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#       File::PathConvert.pm
#
# up to 0.4  8-Mar-1998 Shigio Yamaguchi
#
#     All basic algorithms worked out & tested. Thanks Shigio! 
#        - Barrie
#
#
# 0.5 30-Aug-1998 Barrie Slaymaker
#
#     Added support for multiplatform use, fully implemented and tested only
#     for Win32 based perl.  Published for review on comp.lang.perl
#
#     Replaced common() for two reasons.  
#        (1) having common() return the common string and then using s/// to
#        chop it off the paths may have unexpected results if the paths have 
#        RE metacharacters in them.  And '.' and '\' are meta characters.  
#        (2) this is faster, since it saves calling common(), assembling the 
#        common string, returning it, and calling s///.  Although an extra 
#        join() is required.
#
#
# 0.6 05-Sep-1998 Barrie Slaymaker
#
#     Incorporated feedback from Tye McQueen to make REs more reliable and
#     clear.
#
#     Removed bug in rel2abs() that didn't see "C:/" and "/" as both being
#     root directories.  This does mean that "C:/" and "D:/" both look 
#     like "/", which is a silent bug.
#
#     Added lots of comment inline, inspired by Tye's reminder that others
#     might look to this as a style guide.  Thinking perhaps of adding
#     a "valid path RE" that would be used to validate all path parameters
#     and returns and issue warnings if they don't match.  This would be
#     a service to the module user in case some garbage gets passed in.
#
#     Moved the excising of "name/.." patterns into regularize()
#        - simplifies abs2rel() and rel2abs()
#        - reduces likelihood of having or fixing a bug in one place and not
#          another
#        - seems like this should be part of regularizing a path, anyway
#
#     Fixed a bug in regularize() that would replace a valid root
#     path beginning with the separator no matter what.  This means that
#     'C:/' would always become '/', which is unexpected by the caller.
#     The old code worked worked fine under Unix, but acted up under Win32.
#
#     Changed behavior of regularize to change an empty path to '.'.
#
#     Removed code that silently fixed some path errors in regularize.  This
#     code fixed a path beginning with '/../' to begin with '/', and also
#     fixed '//' to be '/'.  These two changes:
#        - prevent the routine from silently patching over illegal parameter
#          values that the user of this package should probably go fix
#          anyway, IMHO.  In fact, by fixing the problem at the source, the
#          API user is likely to discover some unexpected condition that was
#          overlooked or misunderstood.
#        - allow Win32 UNC pathnames to be used.  These begin with '//'.
#        - speed up regularize()
#
#     Added UNC pathname root recognition to $rootRE for Win32
#
#
# 0.7 07-Sep-1998 Barrie Slaymaker
#
#     Added @fsconfig, fssettype(), and related code.  This should allow
#     for easy reconfiguration to all OSs with Unix or DOS like concepts
#     of root and file separators.  VMS is still an open question due to
#     it's [name] construct.
#
# 0.71 12-Sep-1998 Barrie Slaymaker
#
#     Fixed bug in $drive_letter creation in test.pl pointed out by Shigio.
#
#     Adopted idiom from perlmod pod for exporting variables to fix problem
#     getting to @EXPORT_OKed variables.
#
# 0.72 12-Sep-1998 Barrie Slaymaker
#
#     Removed spurious "$::" from the vars in @EXPORT_OK.
#
#     Documented some limitations.
#
#     Cleaned up fsconfig a bit
#        - used "undef" for values that are not used
#        - improved the MacOS settings a bit
#
# 0.80 12-Sep-1998 Barrie Slaymaker
#
#     Implemented splitpath(), joinpath(), splitdirectories(), 
#     joindirectories(). This required adding the 'volume' and 'directory'
#     parameters to all @fsconfig entries.
#
#     Changed test.pl to test the above, started changing it towards using
#     arrays instead of hashes for the stimulus / response data sets.  This
#     is more convenient for testing the new routines, and delivers the
#     expected test order, unliks takeing the keys() of a hash.
#
#     Added print_error() to test.pl to make it easier to complain.
#
#     Fixed bugs that assumed that '0' would never be passed
#     in.  "if ($string)" was used in several places instead of 
#     "if ( $string ne '' )".  This would have bitten on any length
#     string of 0's, and VMS volume and directory names can sometimes
#     have these.  A directory named '0' is also not impossible.
#
#     Question: does VMS cwd() return path in Unix format or VMS format?
#     
#     Problem: $sepRE can't be used to detect single separators only in a
#     situation like Win32 UNC names, and also detect separator sequences
#     for idempotent directory separators.
#
#     Improvement: flatten out fsconfig to be 2D insstead of 3D, and never
#     derive an RE from a non-RE.  This will prevent anyone from forgetting
#     to do an RE where they really shouldn't use the default RE.  And besides,
#     they're not hard to do, and not too many can be automatically derived
#     anyway.
#
# 0.81 12-Sep-1998 Barrie Slaymaker
#
#     Removed /o's from regexs, since the OS setting can be be changed in
#     mid stream.
#
#     Restored code that 'silently fixed some path errors' in regularize.  
#     For some OSs, Unix and DOS, at least, these errors do not make
#     invalid paths, so I put them back.  This code fixes a path beginning 
#     with '/../' to begin with '/', and also fixed '//' to be '/'.  
#
#     Changed name of $rootRE to $isrootRE, and adjusted $isrootRE values 
#     to not account for volumes.  Note that $isrootRE may only be used in 
#     testing for root, not for splitting off some
#     prefix that means 'this is root'. In VMS, at least, a lack of a
#     separator indicates root, while a leading separator indicates a
#     relative path.
#
#     Made abs2rel multiplatform.  Added multiplatform tests for abs2rel and
#     rel2abs.
#
#     Fixed bug that incorrectly turned '/name/..name2' in to 'name2'.
#
# 0.82 08-Nov-1998 Barrie Slaymaker
#
#     Traded @fsconfig in for an if/elsif tree.  This should be smaller,
#     faster, and easier to understand, since I could eliminate a loop, a 
#     helper routine, and 10 function calls or so.  The speed improvement 
#     is necessary because of the shift to autodetecting unix style paths
#     when in non-unix filesystem modes.
#
#     Added beginnings of URL support.
#
#

package File::PathConvert;
require 5.002;

use strict ;

BEGIN {
   use Exporter   ();
   use vars       qw($VERSION @ISA @EXPORT_OK);
   $VERSION       = 0.82;
   @ISA           = qw(Exporter);
   @EXPORT_OK     = qw(setfstype splitpath joinpath splitdirectories joindirectories realpath abs2rel rel2abs $maxsymlinks $verbose $SL $resolved );
}

use vars      qw( $maxsymlinks $verbose $SL $resolved ) ;
use Cwd;

#
# Initialize @EXPORT_OK vars
#
$maxsymlinks   = 32;       # allowed symlink number in a path
$verbose       = 0;        # 1: verbose on, 0: verbose off
$SL            = '' ;      # Separator char export
$resolved      = '' ;      # realpath() intermediate value export

#############################################################################
#
#  Package Globals
#

my $fstype        ; # A name indicating the type of filesystem currently in use
my $sep           ; # separator
my $sepRE         ; # RE to match spearator
my $notsepRE      ; # RE to match anything else
my $volumeRE      ; # RE to match the volume name
my $directoryRE   ; # RE to match the directory name
my $isrootRE      ; # RE to match root path: applied to directory portion only
my $thisDir       ; # Name of this directory
my $thisDirRE     ; # Name of this directory
my $parentDir     ; # Name of parent directory
my $parentDirRE   ; # RE to match parent dir name
my $casesensitive ; # Set to non-zero for case sensitive name comprisions.  Only
                    # affects names, not any other REs, so $isrootRE for Win32
                    # must be case insensitive
my $idempotent    ; # Set to non-zero if '//' is equivalent to '/'.  This
                    # does not affect leading '//' and '\\' under Win32,
                    # but will fold '///' and '////', etc, in to '//' on this
                    # Win32



###########
#
# The following globals are regexs used in the indicated routines.  These
# are initialized by setfstype, so they don't need to be rebuilt each time
# the routine that uses them is called.

my $basenamesplitRE ; # Used in realpath() to split filenames.


###########
#
# This RE matches (and saves) the portion of the string that is just before
# the beginning of a name
#
my $beginning_of_name ;

#
# This whopper of an RE looks for the pattern "name/.." if it occurs
# after the beginning of the string or after the root RE, or after a separator.
# We don't assume that the isrootRE has a trailing separator.
# It also makes sure that we aren't eliminating '../..' and './..' patterns
# by using the negative lookahead assertion '(?!' ... ')' construct.  It also
# ignores 'name/..name'.
#
my $name_sep_parentRE ;

#
# Matches '..$', '../' after a root
my $leadingParentRE ;

#
# Matches things like '/(./)+' and '^(./)+'
#
my $dot_sep_etcRE ;

#
# Matches trailing '/' or '/.'
#
my $trailing_sepRE ;


#############################################################################
#
#     Functions
#


#
# setfstype: takes the name of an operating system and sets up globals that
#            allow the other functions to operate on multiple OSs.  See 
#            %fsconfig for the sets of settings.
#
#            This is run once on module load to configure for the OS named
#            in $^O.
#
# Interface:
#       i)     $osname, as in $^O or plain english: "MacOS", "DOS, etc.
#              This is _not_ usually case sensitive.
#       r)     Name of recognized name on success else undef.  Note that, as
#              shipped, 'unix' is the default is nothing else matches.
#       go)    $fstype and lots of internal parameters and regexs.
#       x)     Dies if a parameter required in @fsconfig is missing.
#
#
# There are some things I couldn't figure a way to parameterize by setting
# globals. $fstype is checked for filesystem type-specific logic, like 
# VMS directory syntax.
#
# Setting up for a particular OS type takes two steps: identify the OS and
# set all of the 'atomic' global variables, then take some of the atomic
# globals which are regexps and build composite values from them.
#
# The atomic regexp terms are generally used to build the larger composite
# regexps that recognize and break apart paths.  This leads to 
# two important rules for the atomic regexp terms:
#
# (1) Do not use '(' ... ')' in the regex terms, since they are used to build
# regexs that use '(' ... ')' to parse paths.
#
# (2) They must be built so that a '?' or other quantifier may be appended.
# This generally means using the '(?:' ... ')' or '[' ... ']' to group
# multicharacter patterns.  Other '(?' ... ')' may also do.
#
# The routines herein strive to preserve the
# original separator and root settings, and, it turns out, never need to
# prepend root to a string (although they do need to insert separators on
# occasion).  This is good, since the Win32 root expressions can be like
# '/', '\', 'A:/', 'a:/', or even '\\' or '//' for UNC style names.
#
# Note that the default root and default notsep are not used, and so are 
# undefined.
#
# For DOS, MacOS, and VMS, we assume that all paths handed in are on the same
# volume.  This is not a significant limitation except for abs2rel, since the
# absolute path is assumed to be on the same volume as the base path.
#
sub setfstype($;) {
   my( $osname ) = @_ ;

   # Find the best match for OS and set up our atomic globals accordingly
   if ( $osname =~ /^(?:(ms)?(dos|win(32|nt)?))/i )
   {
      $fstype           = 'Win32' ;
      $sep              = '/' ;
      $sepRE            = '[\\\\/]' ;
      $notsepRE         = '[^\\\\/]' ;
      $volumeRE         = '(?:^(?:[a-zA-Z]:|(?:\\\\\\\\|//)[^\\\\/]+[\\\\/][^\\\\/]+)?)' ;
      $directoryRE      = '(?:(?:.*[\\\\/])?)' ;
      $isrootRE         = '(?:^[\\\\/])' ;
      $thisDir          = '.' ;
      $thisDirRE        = '\.' ;
      $parentDir        = '..' ;
      $parentDirRE      = '(?:\.\.)' ;
      $casesensitive    = 0 ;
      $idempotent       = 1 ;
   }
   elsif ( $osname =~ /^MacOS$/i )
   {
      $fstype           = 'MacOS' ;
      $sep              = ':' ;
      $sepRE            = '\:' ;
      $notsepRE         = '[^:]' ;
      $volumeRE         = '(?:^(?:.*::)?)' ;
      $directoryRE      = '(?:(?:.*:)?)' ;
      $isrootRE         = '(?:^:)' ;
      $thisDir          = '.' ;
      $thisDirRE        = '\.' ;
      $parentDir        = '..' ;
      $parentDirRE      = '(?:\.\.)' ;
      $casesensitive    = 0 ;
      $idempotent       = 1 ;
   }
   elsif ( $osname =~ /^VMS$/i )
   {
      $fstype           = 'VMS' ;
      $sep              = '.' ;
      $sepRE            = '[\.\]]' ;
      $notsepRE         = '[^\.\]]' ;
      # volume is node::volume:, where node:: and volume: are optional 
      # and node:: cannot be present without volume.  node can include
      # an access control string in double quotes.
      # Not supported:
      #     quoted full node names
      #     embedding a double quote in a string ("" to put " in)
      #     support ':' in node names
      #     foreign file specifications
      #     task specifications
      #     UIC Directory format (use the 6 digit name for it, instead)
      $volumeRE         = '(?:^(?:(?:[\w\$-]+(?:"[^"]*")?::)?[\w\$-]+:)?)' ;
      $directoryRE      = '(?:(?:\[.*\])?)' ;

      # Root is the lack of a leading '.', unless string is empty, which
      # means 'cwd', which is relative.
      $isrootRE         = '(?:^[^\.])' ;
      $thisDir          = '' ;
      $thisDirRE        = '\[\]' ;
      $parentDir        = '-' ;
      $parentDirRE      = '-' ;
      $casesensitive    = 0 ;
      $idempotent       = 0 ;
   }
   elsif ( $osname =~ /^URL$/i )
   {
      # URL spec based on RFC2396 (ftp://ftp.isi.edu/in-notes/rfc2396.txt)
      $fstype           = 'URL' ;
      $sep              = '/' ;
      $sepRE            = '/' ;
      $notsepRE         = '[^/]' ;
      # Volume= scheme + authority, both optional
      $volumeRE         = '(?:^(?:[a-zA-Z][a-zA-Z0-9+-.]*:)?(?://[^/?]*)?)' ;

      # Directories do _not_ include the query component: we pretend that 
      # anything after a "?" is the filename or part of it.  So a '/'
      # terminates and is part of the directory spec, while a '?' terminates
      # and is not part of the directory spec.
      #
      # We pretend that ";param" syntax does not exist
      #
      $directoryRE      = '(?:(?:[^?]*/)?)' ;
      $isrootRE         = '(?:^/)' ;
      $thisDir          = '.' ;
      $thisDirRE        = '\.' ;
      $parentDir        = '..' ;
      $parentDirRE      = '(?:\.\.)' ;
      # Assume case sensitive, since many (most?) are.  The user can override 
      # this if they so desire.
      $casesensitive    = 1 ;
      $idempotent       = 1 ;
   }
   else
   { 
      $fstype           = 'Unix' ;
      $sep              = '/' ;
      $sepRE            = '/' ;
      $notsepRE         = '[^/]' ;
      $volumeRE         = '' ;
      $directoryRE      = '(?:(?:.*/)?)' ;
      $isrootRE         = '(?:^/)' ;
      $thisDir          = '.' ;
      $thisDirRE        = '\.' ;
      $parentDir        = '..' ;
      $parentDirRE      = '(?:\.\.)' ;
      $casesensitive    = 1 ;
      $idempotent       = 1 ;
   }

   # Now set our composite regexps.

   # Maintain old name for backward compatibility
   $SL= $sep ;

   # Build lots of REs used below, so they don't need to be built every time
   # the routines that use them are called.
   $basenamesplitRE   = '^(.*)' . $sepRE . '(' . $notsepRE . '*)$' ;

   $leadingParentRE   = '(' . $isrootRE . '?)(?:' . $parentDirRE . $sepRE . ')*(?:' . $parentDirRE . '$)?' ;
   $trailing_sepRE    = '(.)' . $sepRE . $thisDirRE . '?$' ;

   $beginning_of_name = '(?:^|' . $isrootRE . '|' . $sepRE . ')' ;

   $dot_sep_etcRE     = 
      '(' . $beginning_of_name . ')(?:' . $thisDirRE . $sepRE . ')+';

   $name_sep_parentRE = 
      $beginning_of_name
      . '(?!(?:' . $thisDirRE . '|' . $parentDirRE . ')' . $sepRE . ')'
      . $notsepRE . '+' 
      . $sepRE . $parentDirRE 
      . '(?=' . $sepRE . '|$)'
      ;

   if ( $verbose ) {
      print( <<TOHERE )  ;
fstype        = "$fstype"
sep           = "$sep"
sepRE         = /$sepRE/
notsepRE      = /$notsepRE/
volumeRE      = /$volumeRE/
directoryRE   = /$directoryRE/
isrootRE      = /$isrootRE/
thisDir       = "$thisDir"
thisDirRE     = /$thisDirRE/
parentDir     = "$parentDir"
parentDirRE   = /$parentDirRE/
casesensitive = "$casesensitive"
TOHERE
   }

   return $fstype ;
}


setfstype( $^O ) ;


#
# splitpath: Splits a path into component parts: volume, dirpath, and filename.
#
#           Very much like File::Basename::fileparse(), but doesn't concern
#           itself with extensions and knows about volume names.
#
#           Returns ($volume, $directory, $filename ).
#
#           The contents of the returned list varies by operating system.
#
#           Unix:
#              $volume: always ''
#              $directory: up to, and including, final '/'
#              $filename: after final '/'
#
#           Win32:
#              $volume: drive letter and ':', if present
#              $directory and $filename are like on Unix, but '\' and '/' are
#              equivalent and the $volume is not in $directory..
#
#           VMS:
#              $volume: up to and including first ":"
#              $directory: "[...]" component
#              $filename: the rest.
#
# Interface:
#       i)     $path
#       i)     $nofile: if true, then any trailing filename is assumed to
#              belong to the directory for non-VMS systems.
#       r)     list of ( $volume, $directory, $filename ).
#
sub splitpath {
   my( $path, $nofile )= @_ ;
   if ( $fstype ne 'VMS' && $nofile ) {
      $path =~ m/($volumeRE)(.*)()$/ ;
      return ( $1, $2, $3 ) ;
   }
   else {
      $path =~ m/($volumeRE)($directoryRE)(.*)$/ ;
      return ( $1, $2, $3 ) ;
   }
}


#
# joinpath: joins the results of splitpath().  Not really necessary now, but
# good to have:
#
#     - API completeness
#     - Self documenting code
#     - Future handling of other filesystems
#
# For instance, if you leave the ':' or the '[' and ']' out of VMS $volume
# and $directory strings, this patches it up.  If you leave out the '['
# and provide the ']', or vice versa, it is not cleaned up.  This is
# because it's useful to automatically insert both '[' and ']', but if you
# leave off only one, it's likely that there's a bug elsewhere that needs
# looking in to.
#
# Automatically inserts a separator between directory and filename if needed
# for non-VMS OSs.
#
# Automatically inserts a separator between volume and directory or file 
# if needed for Win32 UNC names.
#
sub joinpath($;$;$;) {
   my( $volume, $directory, $filename )= @_ ;

   # Fix up delimiters for $volume and $directory as needed for various OSs
   if ( $fstype eq 'VMS' ) {
      $volume .= ':'
         if ( $volume ne '' && $volume !~ m/:$/ ) ;

      $directory = join( '', ( '[', $directory, ']' ) )
         if ( $directory ne '' && $directory !~ m/^\[.*\]$/ ) ;
   }
   else {
      $directory.= $sep
         if ( $directory ne '' && $filename ne '' && $directory !~ m/$sepRE$/ );

      if ( $fstype eq 'Win32' ) {
         # Add trailing '\' for UNC volume names that lack it and need it.
         $volume.= $sep
            if (  $volume    =~ m#^$sepRE{2}#
               && $volume    !~ m#$sepRE$#  
               && $directory !~ m#^$sepRE#      
               && ( $directory ne '' || $filename ne '' )
               ) ;
      }
   }

   return join( '', $volume, $directory, $filename ) ;
}


#
# splitdirectories: Splits a string containing directory portion of a path
# in to component parts.  Preserves trailing null entries, unlike split().
#
# "a/b" should get you [ 'a', 'b' ]
#
# "a/b/" should get you [ 'a', 'b', '' ]
#
# "/a/b/" should get you [ '', 'a', 'b', '' ]
#
# "a/b" returns the same array as 'a/////b' for those OSs where
# the seperator is idempotent (Unix and DOS, at least, but not VMS).
#
# Interface:
#     i) directory path string
#
sub splitdirectories($;) {
   my( $directorypath )= @_ ;

   $directorypath =~ s/^\[(.*)\]$/$1/
      if ( $fstype eq 'VMS' ) ;

   #
   # split() likes to forget about trailing null fields, so here we
   # check to be sure that there will not be any before handling the
   # simple case.
   #
   return split( $sepRE, $directorypath )
      if ( $directorypath !~ m/$sepRE$/ ) ;

   #
   # since there was a trailing separator, add a file name to the end, then
   # do the split, then replace it with ''.
   #
   $directorypath.= "file" ;
   my( @directories )= split( $sepRE, $directorypath ) ;
   $directories[ $#directories ]= '' ;

   return @directories ;
}

#
# joindirectories: Joins an array of directory names in to a string, adding
# OS-specific delimiters, like '[' and ']' for VMS.
#
# Interface:
#     i) array of directory names
#     o) string representation of directory path
#
sub joindirectories {
   my( $directorypath )= join( $sep, @_ ) ;

   $directorypath = join( '', '[', $directorypath, ']' )
      if ( $fstype eq 'VMS' ) ;

   return $directorypath ;
}


#
# realpath: returns the canonicalized absolute path name
#
# Interface:
#       i)      $path   path
#       r)              resolved name on success else undef
#       go)     $resolved
#                       resolved name on success else the path name which
#                       caused the problem.
$resolved = '';
#
#       Note: this implementation is based 4.4BSD version realpath(3).
#
sub realpath($;) {
    ($resolved) = @_;
    my($backdir) = cwd();
    my($dirname, $basename, $links, $reg);

    regularize($resolved);
LOOP:
    {
        #
        # Find the dirname and basename.
        # Change directory to the dirname component.
        #
        if ($resolved =~ /$sepRE/) {
            ($dirname, $basename) = $resolved =~ /$basenamesplitRE/ ;
            $dirname = $sep if ( $dirname eq '' );
            $resolved = $dirname;
            unless (chdir($dirname)) {
                warn("realpath: chdir($dirname) failed: $! (in ${\cwd()}).") if $verbose;
                chdir($backdir);
                return undef;
            }
        } else {
            $dirname = '';
            $basename = $resolved;
        }
        #
        # If it is a symlink, read in the value and loop.
        # If it is a directory, then change to that directory.
        #
        if ( $basename ne '' ) {
            if (-l $basename) {
                unless ($resolved = readlink($basename)) {
                    warn("realpath: readlink($basename) failed: $! (in ${\cwd()}).") if $verbose;
                    chdir($backdir);
                    return undef;
                }
                $basename = '';
                if (++$links > $maxsymlinks) {
                    warn("realpath: too many symbolic links: $links.") if $verbose;
                    chdir($backdir);
                    return undef;
                }
                redo LOOP;
            } elsif (-d _) {
                unless (chdir($basename)) {
                    warn("realpath: chdir($basename) failed: $! (in ${\cwd()}).") if $verbose;
                    chdir($backdir);
                    return undef;
                }
                $basename = '';
            }
        }
    }
    #
    # Get the current directory name and append the basename.
    #
    $resolved = cwd();
    if ( $basename ne '' ) {
        $resolved .= $sep if ($resolved ne $sep);
        $resolved .= $basename
    }
    chdir($backdir);
    return $resolved;
} # end sub realpath


#
# abs2rel: make a relative pathname from an absolute pathname
#
# Interface:
#       i)      $path   absolute path(needed)
#       i)      $base   base directory(optional)
#       r)              relative path of $path
#
#       Note:   abs2rel doesn't check whether the specified path exist or not.
#
sub abs2rel($;$;) {
    my($path, $base) = @_;
    my($reg );

    my( $path_volume, $path_directory, $path_file )= splitpath( $path, 'nofile' ) ;
    if ( $path_directory !~ /$isrootRE/ ) {
        warn("abs2rel: nothing to do: '$path' is relative.") if $verbose;
        return $path;
    }

    $base = cwd()
       if ( $base eq '' ) ;

    my( $base_volume, $base_directory, $base_file )= splitpath( $base, 'nofile' ) ;
    # check for a filename, since the nofile parameter does not work for OSs
    # like VMS that have explicit delimiters between the dir and file portions
    warn( "rel2abs: filename '$base_file' passed in \$base" )
       if ( $base_file ne '' && $verbose ) ;

    if ( $base_directory !~ /$isrootRE/ ) {
        # Make $base absolute
        my( $cw_volume, $cw_directory, $dummy ) = splitpath( cwd(), 'nofile' ) ;
        # maybe we should warn if $cw_volume ne $base_volume and both are not ''
        $base_volume= $cw_volume
           if ( $base_volume eq '' && $cw_volume ne '' ) ;
        $base_directory = join( '', $cw_directory, $sep, $base_directory ) ;
    }

    regularize($path_directory);
    regularize($base_directory);

    # Now, remove all leading components that are the same, so 'name/a'
    # 'name/b' become 'a' and 'b'.
    my @pathchunks = split($sepRE, $path_directory);
    my @basechunks = split($sepRE, $base_directory);

    if ( $casesensitive ) {
        while (@pathchunks && @basechunks && $pathchunks[0] eq $basechunks[0]) {
            shift @pathchunks ;
            shift @basechunks ;
        }
    }
    else {
        while (@pathchunks && @basechunks && lc( $pathchunks[0] ) eq lc( $basechunks[0] ) ) {
            shift @pathchunks ;
            shift @basechunks ;
        }
    }
    $path_directory= join( $sep, @pathchunks );
    $base_directory= join( $sep, @basechunks );

    # Convert $base_directory from absolute to relative
    if ( $fstype eq 'VMS' ) {
        $base_directory= $sep . $base_directory
            if ( $base_directory ne '' ) ;
    }
    else {
        $base_directory=~ s/^$sepRE// ;
    }

    # $base_directory now contains the directories the resulting relative path 
    # must ascend out of before it can descend to $path_directory.  So, 
    # replace all names with $parentDir
    $base_directory =~ s/$notsepRE+/$parentDir/g;

    # Glue the two together, using a separator if necessary, and preventing an
    # empty result.
    if ( $path_directory ne '' && $base_directory ne '' ) {
        $path_directory = $base_directory . $sep . $path_directory;
    } else {
        $path_directory = $base_directory . $path_directory;
        if ( $path_directory eq '' ) {
            $path_directory = $thisDir ;
        }
    }

    regularize($path_directory);

    return joinpath( $path_volume, $path_directory, $path_file ) ;
}

#
# rel2abs: make an absolute pathname from a relative pathname
#
# Assumes no trailing file name on $base.  Ignores it if present on an OS
# like $VMS.
#
# Interface:
#       i)      $path   relative path (needed)
#       i)      $base   base directory  (optional)
#       r)              absolute path of $path
#
#       Note:   rel2abs doesn't check if the paths exist.
#
sub rel2abs($;$;) {
    my( $path, $base ) = @_;
    my( $reg );

    my( $path_volume, $path_directory, $path_file )= splitpath( $path, 'nofile' ) ;
    if ( $path_directory =~ /$isrootRE/ ) {
        warn( "rel2abs: nothing to do: '$path' is absolute" ) 
            if $verbose;
        return $path;
    }

    warn( "rel2abs: volume '$path_volume' passed in relative path: \$path" )
        if ( $path_volume ne '' && $verbose ) ;

    $base = cwd()
        if ( $base eq '' ) ;

    my( $base_volume, $base_directory, $base_file )= splitpath( $base, 'nofile' ) ;
    # check for a filename, since the nofile parameter does not work for OSs
    # like VMS that have explicit delimiters between the dir and file portions
    warn( "rel2abs: filename '$base_file' passed in \$base" )
        if ( $base_file ne '' && $verbose ) ;

    if ( $base_directory !~ /$isrootRE/ ) {
        # Make $base absolute
        my( $cw_volume, $cw_directory, $dummy ) = splitpath( cwd(), 'nofile' ) ;
        # maybe we should warn if $cw_volume ne $base_volume and both are not ''
        $base_volume= $cw_volume
            if ( $base_volume eq '' && $cw_volume ne '' ) ;
        $base_directory = join( '', $cw_directory, $sep, $base_directory ) ;
    }

    regularize( $path_directory );
    regularize( $base_directory );

    my( $result_directory ) = $base_directory . $sep . $path_directory ;

    regularize( $result_directory );

    return joinpath( $base_volume, $result_directory, $path_file ) ;
}

#
# regularize a path.  
#
#    Removes dubious and redundant information. 
#    should only be called on directory portion on OSs
#    with volumes and with delimeters that separate dir names from file names,
#    since the separators can take on different semantics, like "\\" for UNC
#    under Win32, or '.' in filenames under VMS.
#
sub regularize {
    my( $in )= \$_[ 0 ] ;

    # Combine idempotent separators.  Do this first so all other REs only
    # need to match one separator.
    $$in =~ s/$sepRE+/$sep/g
        if ( $idempotent ) ;

    # Delete all occurences of '/name/..'.  This is done with a while
    # loop to get rid of things like '/name1/name2/../..'.
    while ($$in =~ s/$name_sep_parentRE//g) {}
   
    # Get rid of ./ in '^./' and '/./'
    $$in =~ s/$dot_sep_etcRE/$1/g ;

    # Get rid of trailing '/' and '/.' unless it would leave an empty string
    $$in =~ s/$trailing_sepRE/$1/ ;

    # Get rid of '../' constructs from absolute paths
    $$in =~ s/$leadingParentRE/$1/
      if ( $$in =~ /$isrootRE/ ) ;

    # Default to current directory if it's now empty.
    $$in = $thisDir if $_[0] eq '' ;
}

1;

__END__

=head1 NAME

realpath - make a canonicalized absolute path name

abs2rel - make a relative path from an absolute path

rel2abs - make an absolute path from a relative path

=head1 SYNOPSIS

    use File::PathConvert qw(realpath abs2rel rel2abs);

    $path = realpath($path);

    $path = abs2rel($path);
    $path = abs2rel($path, $base);

    $path = rel2abs($path);
    $path = rel2abs($path, $base);

    use File::PathConvert qw($resolved);
    $path = realpath($path) || die "resolution stopped at $resolved";

=head1 DESCRIPTION

The PathConvert module provides three functions.

=over 4

=item realpath

C<realpath> makes a canonicalized absolute pathname and
resolves all symbolic links, extra ``/'' characters, and references
to /./ and /../ in the path.
C<realpath> resolves both absolute and relative paths.
It returns the resolved name on success, otherwise it returns undef
and sets the valiable C<$File::PathConvert::resolved> to the pathname
that caused the problem.

All but the last component of the path must exist.

This implementation is based on 4.4BSD realpath(3).

=item abs2rel

C<abs2rel> makes a relative path name from an absolute path name.
By default, the base is the current directory.
If you specify a second parameter, it's assumed to be the base.

The returned path may include symbolic links.
C<abs2rel> doesn't check whether or not any path exists.

=item rel2abs

C<rel2abs> makes an absolute path name from a relative path name.
By default, the base directory is the current directory.
If you specify a second parameter, it's assumed to be the base.

The returned path may include symbolic links.
C<abs2rel> doesn't check whether or not any path exists.

=head1 EXAMPLES

=item realpath

    If '/sys' is a symbolic link to '/usr/src/sys':

    chdir('/usr');
    $path = realpath('../sys/kern');

or in anywhere ...

    $path = realpath('/sys/kern');

yields:

    $path eq '/usr/src/sys/kern'

=item abs2rel

    chdir('/usr/local/lib');
    $path = abs2rel('/usr/src/sys');

or in anywhere ...

    $path = abs2rel('/usr/src/sys', '/usr/local/lib');

yields:

    $path eq '../../src/sys'

Similarly,

    $path1 = abs2rel('/usr/src/sys', '/usr');
    $path2 = abs2rel('/usr/src/sys', '/usr/src/sys');

yields:

    $path1 eq 'src/sys'
    $path2 eq '.'

=item rel2abs

    chdir('/usr/local/lib');
    $path = rel2abs('../../src/sys');

or in anywhere ...

    $path = rel2abs('../../src/sys', '/usr/local/lib');

yields:

    $path eq '/usr/src/sys'

Similarly,

    $path = rel2abs('src/sys', '/usr');
    $path = rel2abs('.', '/usr/src/sys');

yields:

    $path eq '/usr/src/sys'

=back

=head1 BUGS

If the base directory includes symbolic links, C<abs2rel> produces the
wrong path.
For example, if '/sys' is a symbolic link to '/usr/src/sys',

    $path = abs2rel('/usr/local/lib', '/sys');

yields:

    $path eq '../usr/local/lib'         # It's wrong!!

You should convert the base directory into a real path in advance.

    $path = abs2rel('/sys/kern', realpath('/sys'));

yields:

    $path eq '../../../sys/kern'        # It's correct but ...

That is correct, but a little redundant. If you wish get the simple
answer 'kern', do the following.

    $path = abs2rel(realpath('/sys/kern'), realpath('/sys'));

C<realpath> assures correct result, but don't forget that C<realpath>
requires that all but the last component of the path exist.

=head1 AUTHOR

Shigio Yamaguchi <shigio@wafu.netgate.net>

=cut
