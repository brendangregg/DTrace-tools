#!/usr/sbin/dtrace -s
/*
 * wakeup.d	Trace wakeup time and emit in folded format for flame graphs.
 *
 * See the sched:::sleep predicate, which currently filters on "sshd" and
 * "vmstat" processes only. Change/remove as desired.
 *
 * Copyright (c) 2017 Brendan Gregg. All rights reserved.
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
 * 23-Sep-2017	Brendan Gregg	Created this.
 */

#pragma D option quiet
#pragma D option ustackframes=100
#pragma D option dynvarsize=32m

sched:::sleep
/execname == "sshd" || execname == "vmstat"/
{
	ts[curlwpsinfo->pr_addr] = timestamp;
}

sched:::wakeup
/ts[arg0]/
{
	this->d = timestamp - ts[arg0];
	@[args[1]->p_comm, stack(), ustack(), execname] = sum(this->d);
	ts[arg0] = 0;
}

dtrace:::END
{
	normalize(@, 1000000);
	printa("\n%s%k-%k%s\n%@d\n", @);
}
