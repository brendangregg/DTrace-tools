#!/usr/sbin/dtrace -s
/*
 * accept2close.d	Show socket duration: accept()->close(). FreeBSD.
 *
 * USAGE: ./accept2close.d [execname]
 *
 * An option argument of the program name, eg, "httpd", can be provided. Without
 * this, all processes are traced.
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
 * 20-Jun-2014	Brendan Gregg	Created this
 */

#pragma D option defaultargs
#pragma D option dynvarsize=8m

syscall::accept*:return
/$$1 == "" || $$1 == execname/
{
	ts[pid, arg1] = timestamp;
}

syscall::close:entry
/this->ts = ts[pid, arg0]/
{
	@["ns"] = quantize(timestamp - this->ts);
	ts[pid, arg0] = 0;
}

profile:::tick-1s
{
	printf("%Y:", walltimestamp);
	printa(@);
	trunc(@);
}
