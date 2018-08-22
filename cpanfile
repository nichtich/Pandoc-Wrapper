requires 'perl', '5.010';

requires 'HTTP::Tiny';
requires 'JSON::PP';
requires 'IPC::Run3';
requires 'File::Which', '1.11';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Exception';
};
