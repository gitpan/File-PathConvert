#!/usr/local/bin/perl -w

use Cwd;
use File::PathConvert qw( setfstype splitpath joinpath splitdirectories joindirectories realpath abs2rel rel2abs $verbose );

$| = 1;
open(LOG, ">LOG") || die("cannot make log file");
print "PathConvert TEST START.";
$errcount = 0;
$oldfsspec= '' ;

#
# error logging function
#
sub print_error($;$;) {
        my( $result, $expected )= @_ ;
        $errcount++;
        print "X";
        print LOG "\n";
        print LOG "Result:   $result\n";
        print LOG "Expected: $expected\n";
}

#
# splitpath & joinpath
#
@data = (
# fsspec   Input                                       $volume,                      $directory,     $filename
[ 'Win32', 'file',                                     '',                           '',             'file'       ],
[ 'Win32', '\\d1/d2\\d3/',                             '',                           '\\d1/d2\\d3/', ''           ],
[ 'Win32', 'd1/d2\\d3/',                               '',                           'd1/d2\\d3/',   ''           ],
[ 'Win32', '\\d1/d2\\d3/file',                         '',                           '\\d1/d2\\d3/', 'file'       ],
[ 'Win32', 'd1/d2\\d3/file',                           '',                           'd1/d2\\d3/',   'file'       ],
[ 'Win32', 'C:\\d1/d2\\d3/',                           'C:',                         '\\d1/d2\\d3/', ''           ],
[ 'Win32', 'C:d1/d2\\d3/',                             'C:',                         'd1/d2\\d3/',   ''           ],
[ 'Win32', 'C:\\d1/d2\\d3/file',                       'C:',                         '\\d1/d2\\d3/', 'file'       ],
[ 'Win32', 'C:d1/d2\\d3/file',                         'C:',                         'd1/d2\\d3/',   'file'       ],
[ 'Win32', 'C:\\../d2\\d3/file',                       'C:',                         '\\../d2\\d3/', 'file'       ],
[ 'Win32', 'C:../d2\\d3/file',                         'C:',                         '../d2\\d3/',   'file'       ],
[ 'Win32', '\\../..\\d1/',                             '',                           '\\../..\\d1/', ''           ],
[ 'Win32', '\\./.\\d1/',                               '',                           '\\./.\\d1/',   ''           ],
[ 'Win32', '\\\\node\\share\\d1/d2\\d3/',              '\\\\node\\share',            '\\d1/d2\\d3/', ''           ],
[ 'Win32', '\\\\node\\share\\d1/d2\\d3/file',          '\\\\node\\share',            '\\d1/d2\\d3/', 'file'       ],
[ 'Win32', '\\\\node\\share\\d1/d2\\file',             '\\\\node\\share',            '\\d1/d2\\',    'file'       ],
[ 'VMS',   'file',                                     '',                           '',             'file'       ],
[ 'VMS',   '[d1.d2.d3]',                               '',                           '[d1.d2.d3]',   ''           ],
[ 'VMS',   '[.d1.d2.d3]',                              '',                           '[.d1.d2.d3]',  ''           ],
[ 'VMS',   '[d1.d2.d3]file',                           '',                           '[d1.d2.d3]',   'file'       ],
[ 'VMS',   '[.d1.d2.d3]file',                          '',                           '[.d1.d2.d3]',  'file'       ],
[ 'VMS',   'node::volume:[d1.d2.d3]',                  'node::volume:',              '[d1.d2.d3]',   ''           ],
[ 'VMS',   'node::volume:[d1.d2.d3]file',              'node::volume:',              '[d1.d2.d3]',   'file'       ],
[ 'VMS',   'node"access_spec"::volume:[d1.d2.d3]',     'node"access_spec"::volume:', '[d1.d2.d3]',   ''           ],
[ 'VMS',   'node"access_spec"::volume:[d1.d2.d3]file', 'node"access_spec"::volume:', '[d1.d2.d3]',   'file'       ],
[ 'URL',   'file',                                     '',                           '',             'file'       ],
[ 'URL',   '/d1/d2/d3/',                               '',                           '/d1/d2/d3/',   ''           ],
[ 'URL',   'd1/d2/d3/',                                '',                           'd1/d2/d3/',    ''           ],
[ 'URL',   '/d1/d2/d3/file',                           '',                           '/d1/d2/d3/',   'file'       ],
[ 'URL',   'd1/d2/d3/file',                            '',                           'd1/d2/d3/',    'file'       ],
[ 'URL',   '/../../d1/',                               '',                           '/../../d1/',   ''           ],
[ 'URL',   '/././d1/',                                 '',                           '/././d1/',     ''           ],
[ 'URL',   'http:file',                                'http:',                      '',             'file'       ],
[ 'URL',   'http:/d1/d2/d3/',                          'http:',                      '/d1/d2/d3/',   ''           ],
[ 'URL',   'http:d1/d2/d3/',                           'http:',                      'd1/d2/d3/',    ''           ],
[ 'URL',   'http:/d1/d2/d3/file',                      'http:',                      '/d1/d2/d3/',   'file'       ],
[ 'URL',   'http:d1/d2/d3/file',                       'http:',                      'd1/d2/d3/',    'file'       ],
[ 'URL',   'http:/../../d1/',                          'http:',                      '/../../d1/',   ''           ],
[ 'URL',   'http:/././d1/',                            'http:',                      '/././d1/',     ''           ],
[ 'URL',   'http://a.b.com/file',                      'http://a.b.com',             '/',            'file'       ],
[ 'URL',   'http://a.b.com/d1/d2/d3/',                 'http://a.b.com',             '/d1/d2/d3/',   ''           ],
[ 'URL',   'http://a.b.com/d1/d2/d3/file',             'http://a.b.com',             '/d1/d2/d3/',   'file'       ],
[ 'URL',   'http://a.b.com/../../d1/',                 'http://a.b.com',             '/../../d1/',   ''           ],
[ 'URL',   'http://a.b.com/././d1/',                   'http://a.b.com',             '/././d1/',     ''           ],
[ 'URL',   'http:file?query',                          'http:',                      '',             'file?query' ],
[ 'URL',   'http:/d1/d2/d3/?query',                    'http:',                      '/d1/d2/d3/',   '?query'     ],
[ 'URL',   'http:d1/d2/d3/?query',                     'http:',                      'd1/d2/d3/',    '?query'     ],
[ 'URL',   'http:/d1/d2/d3/file?query',                'http:',                      '/d1/d2/d3/',   'file?query' ],
[ 'URL',   'http:d1/d2/d3/file?query',                 'http:',                      'd1/d2/d3/',    'file?query' ],
[ 'URL',   'http:/../../d1/?query',                    'http:',                      '/../../d1/',   '?query'     ],
[ 'URL',   'http:/././d1/?query',                      'http:',                      '/././d1/',     '?query'     ],
[ 'URL',   'http://a.b.com/file?query',                'http://a.b.com',             '/',            'file?query' ],
[ 'URL',   'http://a.b.com/d1/d2/d3/?query',           'http://a.b.com',             '/d1/d2/d3/',   '?query'     ],
[ 'URL',   'http://a.b.com/d1/d2/d3/file?query',       'http://a.b.com',             '/d1/d2/d3/',   'file?query' ],
[ 'URL',   'http://a.b.com/../../d1/?query',           'http://a.b.com',             '/../../d1/',   '?query'     ],
[ 'URL',   'http://a.b.com/././d1/?query',             'http://a.b.com',             '/././d1/',     '?query'     ],
[ 'other', 'file',                                     '',                           '',             'file'       ],
[ 'other', '/d1/d2/d3/',                               '',                           '/d1/d2/d3/',   ''           ],
[ 'other', 'd1/d2/d3/',                                '',                           'd1/d2/d3/',    ''           ],
[ 'other', '/d1/d2/d3/file',                           '',                           '/d1/d2/d3/',   'file'       ],
[ 'other', 'd1/d2/d3/file',                            '',                           'd1/d2/d3/',    'file'       ],
[ 'other', '/../../d1/',                               '',                           '/../../d1/',   ''           ],
[ 'other', '/././d1/',                                 '',                           '/././d1/',     ''           ],
);

for( $i= 0; $i <= $#data; ++$i ) {
        $fsspec= $data[ $i ][ 0 ] ;
        $in= $data[ $i ][ 1 ] ;

        $volume_out   = $data[ $i ][ 2 ] ;
        $directory_out= $data[ $i ][ 3 ] ;
        $filename_out = $data[ $i ][ 4 ] ;

        if ( $fsspec ne $oldfsspec ) {
            setfstype( $fsspec ) ;
            $oldfsspec= $fsspec ;
        }
        my( $volume, $directory, $filename ) = splitpath( $in );
        if (  $volume    ne $volume_out 
           || $directory ne $directory_out
           || $filename  ne $filename_out
           ) {
                print_error( 
"( '$volume', '$directory', '$filename' ) = splitpath( '$in' ) ; # for '$fsspec'", 
"( '$volume_out', '$directory_out', '$filename_out' )"
                ) ;
                next ;
        }
        print ".";
        my( $out )= joinpath( $volume, $directory, $filename ) ;
        if ( $out ne $in ) {
                print_error( 
"'$out'= joinpath( '$volume', '$directory', '$filename' ) ; # for '$fsspec'", 
"'$in'"
                ) ;
                next ;
        }
        print ".";
}

#
# joinpath
#
@data = (
# fsspec Output        $volume, $directory, $filename
[ 'VMS', '[d1.d2.d3]', '',      'd1.d2.d3', ''        ]
);

for( $i= 0; $i <= $#data; ++$i ) {
        $fsspec= $data[ $i ][ 0 ] ;
        $expected= $data[ $i ][ 1 ] ;

        $volume   = $data[ $i ][ 2 ] ;
        $directory= $data[ $i ][ 3 ] ;
        $filename = $data[ $i ][ 4 ] ;

        if ( $fsspec ne $oldfsspec ) {
            setfstype( $fsspec ) ;
            $oldfsspec= $fsspec ;
        }
        my( $out ) = joinpath( $volume, $directory, $filename );
        if ( $out ne $expected ) {
                print_error( 
"'$out' = joinpath( '$volume', '$directory', '$filename' ) ; # for '$fsspec'", 
"'$expected'"
                ) ;
                next ;
        }
        print ".";
}
setfstype( $^O ) ;

#
# splitdirectories & joindirectories
#
@data = (
# fsspec   I               O             
[ 'Win32', '',             '',            ''    ],   
[ 'Win32', '\\d1/d2\\d3/', '/d1/d2/d3/',  '',   'd1', 'd2', 'd3', '' ],
[ 'Win32', 'd1/d2\\d3/',   'd1/d2/d3/',   'd1', 'd2', 'd3', ''    ],
[ 'Win32', '\\d1/d2\\d3',  '/d1/d2/d3',   '',   'd1', 'd2', 'd3'  ],
[ 'Win32', 'd1/d2\\d3',    'd1/d2/d3',    'd1', 'd2', 'd3'  ],   

[ 'VMS',   '',             '[]',          ''    ],   
[ 'VMS',   '[]',           '[]',          ''    ],   
[ 'VMS',   'd1.d2.d3',     '[d1.d2.d3]',  'd1', 'd2', 'd3'  ],   
[ 'VMS',   '[d1.d2.d3]',   '[d1.d2.d3]',  'd1', 'd2', 'd3'  ],   
[ 'VMS',   '.d1.d2.d3',    '[.d1.d2.d3]', '',   'd1', 'd2', 'd3'  ],
[ 'VMS',   '[.d1.d2.d3]',  '[.d1.d2.d3]', '',   'd1', 'd2', 'd3'  ],
[ 'VMS',   '.-.d2.d3',     '[.-.d2.d3]',  '',   '-',  'd2', 'd3'  ],
[ 'VMS',   '[.-.d2.d3]',   '[.-.d2.d3]',  '',   '-',  'd2', 'd3'  ],

[ 'URL',   '',             '',            ''    ],   
[ 'URL',   '/d1/d2/d3/',   '/d1/d2/d3/',  '',   'd1', 'd2', 'd3', '' ],
[ 'URL',   'd1/d2/d3/',    'd1/d2/d3/',   'd1', 'd2', 'd3', ''    ],
[ 'URL',   '/d1/d2/d3',    '/d1/d2/d3',   '',   'd1', 'd2', 'd3'  ],
[ 'URL',   'd1/d2/d3',     'd1/d2/d3',    'd1', 'd2', 'd3'  ],

[ 'other', '',             '',            ''    ],   
[ 'other', '/d1/d2/d3/',   '/d1/d2/d3/',  '',   'd1', 'd2', 'd3', '' ],
[ 'other', 'd1/d2/d3/',    'd1/d2/d3/',   'd1', 'd2', 'd3', ''    ],
[ 'other', '/d1/d2/d3',    '/d1/d2/d3',   '',   'd1', 'd2', 'd3'  ],
[ 'other', 'd1/d2/d3',     'd1/d2/d3',    'd1', 'd2', 'd3'  ]    
);

for( $i= 0; $i <= $#data; ++$i ) {
        $fsspec  = $data[ $i ][ 0 ] ;
        $in       = $data[ $i ][ 1 ] ;
        $expected = $data[ $i ][ 2 ] ;

        @intermediate_expected= @{ $data[ $i ] } ;
        splice( @intermediate_expected, 0, 3 ) ;
        $intermediate_expected = 
           join( '', ( "[ '", join( "', '", @intermediate_expected ), "' ]" ));

        if ( $fsspec ne $oldfsspec ) {
            setfstype( $fsspec ) ;
            $oldfsspec= $fsspec ;
        }
        @intermediate= splitdirectories( $in ) ;
        $intermediate = join( '', ( "[ '", join( "', '", @intermediate ), "' ]" ) ) ;
        if ( $intermediate ne $intermediate_expected ) {
                print_error( 
                        "$intermediate = splitdirectories( '$in' ) ; # for '$fsspec'", 
                        "$intermediate_expected"
                ) ;
                next ;
        }
        print ".";
        $out= joindirectories( @intermediate ) ;
        if ( $out ne $expected ) {
                print_error( 
                        "'$out' = joindirectories( $intermediate ) ; # for '$fsspec'", 
                        "'$expected'"
                ) ;
                next ;
        }
        print ".";
}

#
# abs2rel
#
# For the UNC names, note the assumption that both paths are on the
# same volume.  This is probably a bad assumption, but that's the way it
# works, for now.
#
#$current = '/t1/t2/t3';
@data = (
    # OS       INPUT                      BASE          OUTPUT                
    [ 'Win32', '/t1/t2/t3',               '/t1/t2/t3',  '.'                    ],  
    [ 'Win32', '/t1/t2/t4',               '/t1/t2/t3',  '../t4'                ],  
    [ 'Win32', '/t1/t2',                  '/t1/t2/t3',  '..'                   ],  
    [ 'Win32', '/t1/t2/t3/t4',            '/t1/t2/t3',  't4'                   ],  
    [ 'Win32', '/t4/t5/t6',               '/t1/t2/t3',  '../../../t4/t5/t6'    ],  
    [ 'Win32', '../t4',                   '/t1/t2/t3',  '../t4'                ],  
    [ 'Win32', '/',                       '/t1/t2/t3',  '../../..'             ],  
    [ 'Win32', '///',                     '/t1/t2/t3',  '../../..'             ],  
    [ 'Win32', '/.',                      '/t1/t2/t3',  '../../..'             ],  
    [ 'Win32', '/./',                     '/t1/t2/t3',  '../../..'             ],  
    [ 'Win32', '/../',                    '/t1/t2/t3',  '../../..'             ],  
    [ 'Win32', '/../../../..',            '/t1/t2/t3',  '../../..'             ],  
    [ 'Win32', '/..a/..b/..c/..',         '/t1/t2/t3',  '../../../..a/..b'     ],  
    [ 'Win32', '/..\\/..\\/..\\/..',      '/t1/t2/t3',  '../../..'             ],  
    [ 'Win32', 't1',                      '/t1/t2/t3',  't1'                   ],  
    [ 'Win32', '.',                       '/t1/t2/t3',  '.'                    ],  
    [ 'Win32', '\\\\a\\b/t1/t2/t4',       '/t1/t2/t3',  '\\\\a\\b/../t4'       ],  
    [ 'Win32', '//a\\b/t1/t2/t4',         '/t1/t2/t3',  '//a\\b/../t4'         ],  
    [ 'VMS',   'node::volume:[t1.t2.t3]', '[t1.t2.t3]',  'node::volume:'       ],
    [ 'VMS',   'node::volume:[t1.t2.t4]', '[t1.t2.t3]',  'node::volume:[.-.t4]'],
    [ 'other', '/t1/t2/t3',               '/t1/t2/t3',  '.'                    ],  
    [ 'other', '/t1/t2/t4',               '/t1/t2/t3',  '../t4'                ],  
    [ 'other', '/t1/t2',                  '/t1/t2/t3',  '..'                   ],  
    [ 'other', '/t1/t2/t3/t4',            '/t1/t2/t3',  't4'                   ],  
    [ 'other', '/t4/t5/t6',               '/t1/t2/t3',  '../../../t4/t5/t6'    ],  
    [ 'other', '../t4',                   '/t1/t2/t3',  '../t4'                ],  
    [ 'other', '/',                       '/t1/t2/t3',  '../../..'             ],  
    [ 'other', '///',                     '/t1/t2/t3',  '../../..'             ],  
    [ 'other', '/.',                      '/t1/t2/t3',  '../../..'             ],  
    [ 'other', '/./',                     '/t1/t2/t3',  '../../..'             ],  
    [ 'other', '/../',                    '/t1/t2/t3',  '../../..'             ],  
    [ 'other', '/../../../..',            '/t1/t2/t3',  '../../..'             ],  
    [ 'other', '/..\\/..\\/..\\/..',      '/t1/t2/t3',  '../../../..\\/..\\'   ],  
    [ 'other', '/..a/..b/..c/..',         '/t1/t2/t3',  '../../../..a/..b'     ],  
    [ 'other', 't1',                      '/t1/t2/t3',  't1'                   ],  
    [ 'other', '.',                       '/t1/t2/t3',  '.'                    ]   
);
for( $i= 0; $i <= $#data; ++$i ) {
        $fsspec   = $data[ $i ][ 0 ] ;
        $in       = $data[ $i ][ 1 ] ;
        $base     = $data[ $i ][ 2 ] ;
        $expected = $data[ $i ][ 3 ] ;

        if ( $fsspec ne $oldfsspec ) {
            setfstype( $fsspec ) ;
            $oldfsspec= $fsspec ;
        }
        $out = abs2rel( $in, $base );
        if ( $out eq $expected ) {
                print ".";
        } else {
                print_error(
                        "'$out' = abs2rel('$in', '$base'); # for '$fsspec'",
                        "'$expected'"
                );
        }
}
#
# rel2abs
#
$current = '/t1/t2/t3';
%data = (
        # INPUT            OUTPUT
        't4'            => '/t1/t2/t3/t4',
        't4/t5'         => '/t1/t2/t3/t4/t5',
        '.'             => '/t1/t2/t3',
        '..'            => '/t1/t2',
        '../t4'         => '/t1/t2/t4',
        '../../t5'      => '/t1/t5',
        '../../../t6'   => '/t6',
        '../../../../t7'=> '/t7',
        '../t4/t5/../t6'=> '/t1/t2/t4/t6',
        '/t1'           => '/t1',
);
foreach $in (keys(%data)) {
        $out = rel2abs($in, $current);
        if ($out eq $data{$in}) {
                print ".";
        } else {
                print_error( 
                        "'$out' = rel2abs('$in', '$current');", 
                        "'$data{$in}'" 
                );
        }
}


#----------------------------------------------------------------------
#
# From now on, use real directory tree.
# make test environment
# test/t1/ta -> t4/t5
# test/t1/t2/t3/tb -> ../../t1/ta
# test/t1/t2/tc -> t3/tb
#
#----------------------------------------------------------------------
$cdir = cwd();
use File::Path;
-d 'test/t1/t2/t3' || mkpath('test/t1/t2/t3') || die("cannot mkpath");
-d 'test/t1/t4/t5' || mkpath('test/t1/t4/t5') || die("cannot mkpath");
open(FILE, ">test/t1/t4/t5/file") || die("cannot create");
close(FILE);

( $drive_letter= $cdir ) =~ s#^((?:[a-zA-Z]:)?).*$#$1# ;

%data = (
        # INPUT            OUTPUT
        '/'                     => "$drive_letter/",
        '///'                   => "$drive_letter/",
        '/.'                    => "$drive_letter/",
        '.'                     => "$cdir",
        "test"                  => "$cdir/test",
        "file"                  => "$cdir/file",
        "test/./t1"             => "$cdir/test/t1",
        "test/t1/../t1/file"    => "$cdir/test/t1/file",
);


# Only do symbolic link tests if symlinks can be made on this OS.
chdir("$cdir/test/t1") || die("cannot chdir");
if ( -l 'ta' || eval { symlink('t4/t5', 'ta') } ) {
   $data{ "test/t1/ta"         } = "$cdir/test/t1/t4/t5" ;
}

chdir("$cdir/test/t1/t2/t3") || die("cannot chdir");
if ( -l 'tb' || eval { symlink('../../../t1/ta', 'tb') } ) {
   $data{ "test/t1/t2/t3/tb"   } = "$cdir/test/t1/t4/t5" ;
}

chdir("$cdir/test/t1/t2") || die("cannot chdir");
if ( -l 'tc' || eval { symlink('t3/tb', 'tc') } ) {
   $data{ "test/t1/t2/tc"      } = "$cdir/test/t1/t4/t5" ;
   $data{ "test/t1/t2/tc/file" } = "$cdir/test/t1/t4/t5/file" ;
}

chdir("$cdir") || die("cannot chdir");

#
# realpath
#
foreach $in (keys(%data)) {
        $out = realpath($in);
        if ($out eq $data{$in}) {
                print ".";
        } else {
                print_error(
                        "'$out' = realpath( '$in' );",
                        "'$data{$in}'"
                ) ;
        }
}
#
# print LOG
#
close(LOG);
if ($errcount) {
        print "FAILED. $errcount errors occured.\n";
        open(LOG, "LOG") || die("cannot open LOG file.");
        @log = <LOG>;
        print @log;
        close(LOG);
        exit(1);
}
print "COMPLETED.\n";
exit(0);
