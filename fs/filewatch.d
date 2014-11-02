#!/usr/sbin/dtrace -s
/*
 * filewatch.d	Watch open/close events for a given file. FreeBSD.
 *
 * USAGE: filewatch.d pathname
 *
 * The pathname should be the same as is used by open(). If you don't know
 * what that is, begin by tracing open() to check.
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
 * 20-Jun-2014	Brendan Gregg	Created this.
 */

#pragma D option quiet
#pragma D option defaultargs

dtrace:::BEGIN
/$$1 == ""/
{
	printf("USAGE: filewatch.d pathname\n");
	exit(1);
}

dtrace:::BEGIN
{
	filename = $$1;
	printf("Tracing events to file: \"%s\". Ctrl-C to end.\n", filename);
}

syscall::open:entry
/copyinstr(arg0) == filename/
{
	self->start = timestamp;
}

syscall::open:return
/self->start/
{
	start[pid, arg1] = self->start;
	self->start = 0;
}

syscall::close:entry
/this->start = start[pid, arg0]/
{
	printf("%Y %s, open()->close(): %d ms\n", walltimestamp, execname,
	    (timestamp - this->start) / 1000000);
	start[pid, arg0] = 0;
}
