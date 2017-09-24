#!/usr/sbin/dtrace -s
/*
 * offcpu.d	Trace off-CPU time and emit in folded format for flame graphs.
 *
 * See the sched:::off-cpu predicate, which currently filters on "bsdtar"
 * processes only. Change/remove as desired. This program traces all off-CPU
 * events, including involuntary context switch preempts.
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

#pragma D option ustackframes=100
#pragma D option dynvarsize=32m

/*
 * Customize the following predicate as desired.
 * eg, you could add /curthread->td_state <= 1/ to exclude preempt paths and
 * involuntary context switches, which are interesting but their stacks usually
 * aren't. The "1" comes from td_state for TDS_INHIBITED. See sys/proc.h.
 *
sched:::off-cpu /execname == "bsdtar"/ { self->ts = timestamp; }

sched:::on-cpu
/self->ts/
{
	@[stack(), ustack(), execname] = sum(timestamp - self->ts);
	self->ts = 0;
}

dtrace:::END
{
	normalize(@, 1000000);
	printa("%k-%k%s\n%@d\n", @);
}
