requires 'perl', '5.010';

requires 'IPC::Run3';
requires 'File::Which';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Exception';
};
