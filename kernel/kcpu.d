#!/usr/sbin/dtrace -s
/*
 * kcpu.d	Kernel CPU profile.
 *
 * USAGE: ./kcpu.d [duration_s]
 *
 * This samples at 99 Hertz. Adjust this rate in the script if desired.
 * Only the top 20 most frequent stacks are printed. This, too, can be
 * adjusted in the script if needed.
 *
 * I usually do this as a one-liner, but it can be handy to have a
 * script for the same purpose, as the basis for customizations.
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
#pragma D option stackframes=100

inline int limit = 20;		/* Max number of stacks to print */

dtrace:::BEGIN
/$1/
{
	secs = $1;
	i = 0;
	printf("Sampling kernel stacks for %d seconds...\n", secs);
}

dtrace:::BEGIN
/!$1/
{
	printf("Sampling kernel stacks... Ctrl-C to end\n");
}

profile:::profile-99
{
	@[execname, stack()] = count();
}

profile:::tick-1s
/secs && ++i >= secs/
{
	exit(0);
}

dtrace:::END
{
	trunc(@, limit);
	printf("Top %d kernel stacks:\n", limit);
	printa(@);
}
