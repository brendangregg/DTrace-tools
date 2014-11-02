#!/usr/sbin/dtrace -s
/*
 * offcpu_slower.d	Trace off-CPU stacks slower than a threshold. FreeBSD.
 *
 * USAGE: ./offcpu_slower.d [min_ms [procname]]
 *
 * This shows all off-CPU events, with stacks, slower than the minimum
 * milliseconds specified as an argument. If no argument is specified, all
 * off-CPU events are shown. A second argument can be provided to specify which
 * process names to trace.
 *
 * eg:
 *	./offcpu_slower.d 100		# show events greater than 100 ms
 *	./offcpu_slower.d 10 httpd	# greater than 10 ms for "httpd"
 *
 * Off-CPU stacks show the thread that was directly blocked. Also see
 * wakeup_slower.d, to identify the other thread that wokeup the target
 * sleeping thread.
 *
 * WARNING: This traces the scheduler on-cpu and off-cpu probes, which are
 * not lightweight. This is not a suitable script for 24x7 monitoring due to
 * the overheads involved. Test and quantify.
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
	printf("Tracing off-CPU events for \"%s\" ", target != "" ? target :
	    "*");
	printf("slower than %d ms... Hit Ctrl-C to end.\n"  , min_ms);
}

sched:::off-cpu
/target == "" || execname == target/
{
	self->ts = timestamp;
}

sched:::on-cpu
/self->ts && (this->delta = (timestamp - self->ts)) > min_ns/
{
	printf("\n%Y %s off-cpu: %d ms", walltimestamp, execname,
	    this->delta / 1000000);
	stack();
	ustack();
}

sched:::on-cpu
/self->ts/
{
	self->ts = 0;
}
