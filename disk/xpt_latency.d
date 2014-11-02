#!/usr/sbin/dtrace -s
/*
 * xpt_latency.d	Measure CCB latency from XPT. FreeBSD.
 *
 * This is measuring some types of storage device latency just under the XPT
 * level, and much deeper than io:::start/io:::done. This script can be used
 * to narrow down the origin of latency. There's still HBA's beneath us, and
 * this doesn't measure latency due to a frozen sim queue and other factors.
 *
 * XPT = Transport Layer
 * CCB = CAM Control Blocks
 * CAM = Common Access Method (SCSI interface description)
 * SCSI = Small Computer Systems Interface
 *
 * WARNING: this is an fbt provider script, and as such is unstable and likely
 * to need changes for different kernel versions.
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

fbt::bus_dmamap_load_ccb:entry
{
	ts[arg2] = timestamp;
}

fbt::xpt_done:entry
/this->ts = ts[arg0]/
{
	@["ns"] = quantize(timestamp - this->ts);
	ts[arg0] = 0;
}
