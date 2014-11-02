#!/usr/sbin/dtrace -s
/*
 * dilt10k.d	Disk I/O Latency Trace. FreeBSD.
 *
 * USAGE: ./dilt.d number_of_io
 *    eg,
 *        ./dilt.d 10000	# capture 10,000 I/O
 *
 * Trace basic disk I/O latency details: start time, latency, direction, size,
 * device, device block number, and process. This is for the consumption by
 * other tools, and ideally captures at 10,000 I/O, or quits after 10 minutes.
 * Tune these as desired.
 *
 * WARNING: This script will stop working at some point and need to be fixed.
 * It uses the current FreeBSD io provider, which is not exposing translated
 * arguments properly, and so, as a workaround, it uses struct bio directly.
 *
 * WARNING: The output may not be in the correct order, due to per-CPU
 * buffering. Post sort on the first column (timestamp).
 *
 * The block number used (bio_pblkno) doesn't work with bio chaining.
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
 * 24-Jun-2014	Brendan Gregg	Created this.
 */

#pragma D option quiet
#pragma D option defaultargs
#pragma D option dynvarsize=8m
#pragma D option switchrate=5

inline int BIO_READ = 0x01;

dtrace:::BEGIN
/!$1/
{
	printf("USAGE: dilt.d number_of_io\n");
	exit(0);
}

dtrace:::BEGIN
{
	printf("ENDTIME(us) LATENCY(us) DIR SIZE(bytes) DEV BLKNO PROCESS\n");
	start = timestamp;
	n = 0;
	maxio = $1;
}

io:::start
/arg0/
{
	ts[arg0] = timestamp;
}

io:::done
/arg0 && (this->ts = ts[arg0])/
{
	/* args[0] can be NULL; io needs to be fixed */
	this->rw = args[0] != NULL ? args[0]->bio_cmd & BIO_READ ? "R" : "W" : "-";
	this->sz = args[0] != NULL ? args[0]->bio_bcount : -1;
	printf("%d %d %s %d %s%d %d %s\n", (timestamp - start) / 1000,
	    (timestamp - this->ts) / 1000, this->rw, this->sz, 
	    args[1]->device_name != "" ? args[1]->device_name : "-",
	    args[1]->unit_number, args[0] != NULL ? args[0]->bio_pblkno : 0,
	    execname);
	ts[arg0] = 0;
	n++;
}

io:::done
/n >= maxio/
{
	exit(0);
}

profile:::tick-10m { exit(0); }
