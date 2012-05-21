#!perl

use Test::More tests => 2;
BEGIN {
    use_ok( 'BankAccount::Validator::UK' ) || print "Bail out!";
    use_ok( 'BankAccount::Validator::UK::Rule' ) || print "Bail out!";
}