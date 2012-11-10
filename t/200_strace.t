# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# Try using the ptrace command somehow.
# This test will count the number of syscalls that occur.

use Test;
use Sys::Ptrace qw( ptrace PTRACE_TRACEME PTRACE_SYSCALL );
use vars qw($sig_chld);

$| = 1; # Hot flush output buffer
plan tests => 4;

ok pipe (READER, WRITER);

pipe (RD_READY, WR_READY);

my $pid = fork;

if (!defined $pid) {
  print STDERR "Could not fork: $!\n";
  ok 0;
  exit 1;
}

if (!$pid) {
  # Child process
  close READER;

  # Send its output down the WRITER pipe
  open (STDOUT, ">&=".fileno(WRITER));
  open (STDIN, "</dev/null");

  # Wait for parent to block on <RD_READY>
  select (undef,undef,undef, 0.1);

  ptrace(PTRACE_TRACEME);

  # RD_READY and WR_READY must be closed to
  # signal to the parent that the TRACEME
  # is ready to go.

  close RD_READY;
  close WR_READY;

  # The following exec will block with a
  # SIGTRAP and then trigger the parent
  # with a SIGCHLD because of the TRACEME
  # property installed above:

  #exec q{perl -e 'print "Hello world\n";'}
  exec "echo Hello world"
    or die "Cannot exec";
}

# Parent process

# Safe Signal Handler
$sig_chld = 0;
$SIG{CHLD} = sub { $sig_chld = 1; };

close WRITER;
close WR_READY;

# Wait for PTRACE_TRACEME to finish.
<RD_READY>;

# Wait until child trips the SIGTRAP
select (undef,undef,undef, 0.1);

ok ptrace (PTRACE_SYSCALL, $pid, 0x1, 0);

my $tracing = 1;
my $syscalls = 0;
while ($tracing && $tracing < 200) {

  # Wait for the next SIGCHLD ...
  select (undef, undef, undef, 0.1);

  if ($sig_chld) {
    $sig_chld = 0;
    $? = 0;
    my $w = waitpid($pid, 0);
    if ($w > 0) {
      if (($? >> 8) == 5) { # SIG_TRAP
        $syscalls++;
      } else {
        $tracing = 0;
      }
    } else {
      print STDERR "DEBUG: WHOA! sig_chld without waitpid!??!?!?!?\n";
      ok 0;
      exit 1;
    }
  } else {
    $tracing++;
    print STDERR "Warning! Paused, but SIGCHLD never came.\n";
    ok 0;
    exit 1;
  }

  ptrace (PTRACE_SYSCALL, $pid);

}

ok !$tracing;

if ($tracing) {
  print STDERR "\nTook too long!\n";
  ok 0;
  exit 1;
};

my $response = <READER>;
$response ||= "(nothing)\n";

ok !!($response =~ /hello/i);

#print STDERR "DEBUG: Found [$syscalls] syscalls\n";
