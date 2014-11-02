#!/usr/sbin/dtrace -s
/*
 * proctime.d	Trace process runtime and CPU time. FreeBSD.
 *
 * This is a work in progress. Measuring on-CPU times may only work properly
 * when a proc:::lwp-start probe is added to FreeBSD. A different way to read
 * on-CPU time would be to dig it from the rusage structs on proc exit,
 * however, this approach would be using an unstable interface.
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
#pragma D option switchrate=5

dtrace:::BEGIN
{
	printf("%-20s %-6s %-16s %11s %11s\n", "TIME", "PID", "COMM",
	   "RUNTIMEms", "TotalCPUms");
}

proc:::exec-success
{
	start[pid] = timestamp;
	tcpu[pid] = -vtimestamp;
}

proc:::lwp-exit
/start[pid]/
{
	/* remember exited thread's CPU time */
	tcpu[pid] += vtimestamp;
}

proc:::exit
/this->s = start[pid]/
{
	this->total_cpu = tcpu[pid] + vtimestamp;
	printf("%-20Y %-6d %-16s %12d %12d\n", walltimestamp, pid, execname,
	    (timestamp - this->s) / 1000000, this->total_cpu / 1000000);
	start[pid] = 0;
	tcpu[pid] = 0;
}
