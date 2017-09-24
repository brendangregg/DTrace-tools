#!/usr/sbin/dtrace -s
/*
 * runqlat.d	Measure run queue latency (aka scheduler latency). FreeBSD.
 *
 * This measures the time from enqueue to on-cpu, for the same thread.
 * I usually accomplish this by measuring enqueue to dequeue time, but
 * there appear to be missing dequeue probe points in FreeBSD 10.0.
 *
 * WARNING: This traces scheduler functions, which can incur high overhead.
 * This is not suitable for 24x7 monitoring.
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
#pragma D option dynvarsize=8m

sched:::enqueue
{
	/*
	 * For the enqueue and dequeue probes, arg0 is the thread pointer.
	 * This is convenient, but also an unstable interface. When FreeBSD
	 * supports it, this can be changed to use stable arg members.
	 */
	ts[arg0] = timestamp
}

sched:::on-cpu
/this->start = ts[(int64_t)curthread]/
{
	this->time = (timestamp - this->start) / 1000000;
	@max_ms = max(this->time);
	@dist_ms = quantize(this->time);
	ts[(int64_t)curthread] = 0;
}

profile:::tick-1sec,
dtrace:::END
{
	printf("\n%Y Run queue latency (ms):", walltimestamp);
	printa(@dist_ms);
	printa("Max run queue latency: %@d ms\n", @max_ms);
	trunc(@dist_ms); trunc(@max_ms);
}
