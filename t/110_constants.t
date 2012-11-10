# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# Test a few random constants to make sure they match up

use Test;
use Sys::Ptrace qw(PTRACE_ATTACH PTRACE_SYSCALL PTRACE_GETREGS PTRACE_TRACEME PT_TRACE_ME);

plan tests => 4;

# Load the default constants into a dummy package called "Default"
package Default;

delete $INC{"linux/ptrace.ph"};
delete $INC{"sys/ptrace.ph"};
delete $INC{"asm/ptrace.ph"};

eval { require "linux/ptrace.ph"; };
eval { require "sys/ptrace.ph"; };

package main;

ok PTRACE_ATTACH(),   &Default::PTRACE_ATTACH();
ok PTRACE_SYSCALL(),  &Default::PTRACE_SYSCALL();
ok PTRACE_GETREGS(),  &Default::PTRACE_GETREGS();
ok PTRACE_TRACEME,    PT_TRACE_ME;
