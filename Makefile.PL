use strict;use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'BankAccount::Validator::UK',
    AUTHOR        => q{Mohammad S Anwar <mohammad.anwar@yahoo.com>},
    VERSION_FROM  => 'lib/BankAccount/Validator/UK.pm',
    ABSTRACT_FROM => 'lib/BankAccount/Validator/UK.pm',
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean         => { FILES => 'BankAccount-Validator-UK-*' },
    PREREQ_PM     => {
        'Test::More' => 0,
        'Readonly'   => '1.03',
    },
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
);