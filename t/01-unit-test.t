use BankAccount::Validator::UK;
use Test::More tests => 4;

my $account = BankAccount::Validator::UK->new();
eval {$account->is_valid()};
like($@, qr/ERROR: Missing bank sort code./);

eval {$account->is_valid(123456)};
like($@, qr/ERROR: Missing bank account number./);

eval {$account->is_valid('ab3456', 12345678)};
like($@, qr/ERROR: Invalid bank sort code./);

eval {$account->is_valid('123456', 'abcd5678')};
like($@, qr/ERROR: Invalid bank account number./);