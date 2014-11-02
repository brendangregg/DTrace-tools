#!/usr/sbin/dtrace -s
/*
 * mps_latencyx.d	Measure mps latency, with extra statistics. FreeBSD.
 *
 * This is measuring storage device latency from the mps driver, which issues
 * the I/O bus commands, and is much deeper than tracing at the io:::start/
 * io:::done level. This script can be used to narrow down the origin of I/O
 * latency.
 *
 * mps -- LSI Fusion-MPT 2 Serial Attached SCSI driver
 *
 * WARNING: this is an fbt provider script, and as such is unstable and likely
 * to need changes for different kernel versions.
 *
 * Can also use mps_map_command() as the entry probe.
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
 * 26-Jun-2014	Brendan Gregg	Created this.
 */

#pragma D option quiet

dtrace:::BEGIN
{
	printf("Tracing mps I/O latency... Hit Ctrl-C to end.\n");
}

fbt::mps_enqueue_request:entry
{
	ts[arg1] = timestamp;
}

fbt::mps_complete_command:entry
/this->ts = ts[arg1]/
{
	this->delta = timestamp - this->ts;
	@dist = quantize(this->delta);
	@avgl = avg(this->delta);
	@maxl = max(this->delta);
	@minl = min(this->delta);
	@num = count();
	ts[arg1] = 0;
}

dtrace:::END
{
	printa("I/O latency distribution (ns):%@d\n", @dist);
	normalize(@avgl, 1000);
	normalize(@maxl, 1000);
	normalize(@minl, 1000);
	printa("I/O latency average: %@d us\n", @avgl);
	printa("I/O latency min:     %@d us\n", @minl);
	printa("I/O latency max:     %@d us\n", @maxl);
	printa("I/O count:           %@d I/O\n", @num);
}
