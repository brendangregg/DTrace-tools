#!/usr/sbin/dtrace -s
/*
 * wakeup_slower.d	Trace wakeup stacks slower than a threshold. FreeBSD.
 *
 * USAGE: ./wakeup_slower.d [min_ms [procname]]
 *
 * Edit the "target" string below to be the process name of interest.
 *
 * This shows all wakeup events, with wakeup stacks, slower than the minimum
 * milliseconds specified as an argument. If no argument is specified, all
 * wakeup events are shown. A second argument can be provided to specify which
 * process names to trace.
 *
 * eg:
 *	./wakeup_slower.d 100		# show events greater than 100 ms
 *	./wakeup_slower.d 10 httpd	# greater than 10 ms for "httpd"
 *
 * Wakeup stacks show who wokeup who, and why. Also see offcpu_slower.d for the
 * stacks that were directly blocked.
 *
 * WARNING: This traces the scheduler probes, which are not usually lightweight.
 * This is not a suitable script for 24x7 monitoring.
 *
 * Copyright (c) 2014 Brendan Gregg. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * 19-Jun-2014	Brendan Gregg	Created this.
 */

#pragma D option quiet
#pragma D option defaultargs
#pragma D option dynvarsize=8m
#pragma D option switchrate=10

dtrace:::BEGIN
{
	min_ms = $1;
	target = $$2;
	min_ns = min_ms * 1000000;
	printf("Tracing sleep->wakeup events for \"%s\" ", target);
	printf("Tracing sleep->wakeup events for \"%s\" ", target != "" ?
	    target : "*");
	printf("slower than %d ms... Hit Ctrl-C to end.\n"  , min_ms);
}

sched:::sleep
/target == "" || execname == target/
{
	sleep[curlwpsinfo->pr_addr] = timestamp;
}

sched:::wakeup
/sleep[arg0] && (this->delta = (timestamp - sleep[arg0])) > min_ns/
{
	printf("\n%Y sleep->wakeup: %d ms, from %s, to %s, wait reason \"%s\"",
	    walltimestamp, this->delta / 1000000, execname, args[0]->td_name,
	    args[0]->td_wmesg != NULL ? stringof(args[0]->td_wmesg) : "-");
	stack();
}

sched:::wakeup
/sleep[curlwpsinfo->pr_addr]/
{
	sleep[curlwpsinfo->pr_addr] = 0;
}
