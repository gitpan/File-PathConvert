use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME' => 'File::PathConvert',
    'VERSION' => '0.1',
    'clean' => {FILES => 'LOG ./test'},
    'dist' => {TARFLAGS => 'cvf', COMPRESS => 'gzip', SUFFIX => 'gz'},
);
