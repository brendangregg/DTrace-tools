#!/usr/sbin/dtrace -s
/*
 * bioq_latency.d	Measure bioq resident time. FreeBSD.
 *
 * Measure the time that block I/O is on the bioq, from insertion
 * to removal.
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
 * 10-Jul-2014	Brendan Gregg	Created this.
 */

#pragma D option quiet

dtrace:::BEGIN
{
	trace("Tracing bioq events... Ctrl-C to end.\n");
}

/* See "BIO queue implementation" comments in sys/kern/subr_disk.c */

/* bioq insertions */
fbt::bioq_disksort:entry,
fbt::bioq_insert_tail:entry,
fbt::bioq_insert_head:entry
{
	/* index timestamps by struct bio * */
	ts[arg1] = timestamp;
}

/* bioq removals */
fbt::bioq_takefirst:return,	/* arg1 is rval */
fbt::bioq_remove:entry		/* arg1 is entry arg */
/this->ts = ts[arg1]/
{
	@ = quantize(timestamp - this->ts);
	ts[arg1] = 0;
}

/* debug */
fbt::brelse:entry
/ts[arg0]/
{
	printf("released but not bioq removed...\n");
	stack();
	ts[arg0] = 0;
}

dtrace:::END
{
	printf("bioq queue duration time (ns):");
	printa(@);
}
