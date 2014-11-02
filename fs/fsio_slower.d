#!/usr/sbin/dtrace -s
/*
 * fsio_slower.d	Show FS I/O slower than a threshold. FreeBSD.
 *
 * USAGE: fsio_slower.d min_ms
 *
 * Edit the script and add more syscall events if desired, and other info such
 * as the pathname.
 *
 * TODO: add kqueue()/kevent() tracing.
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
{
	min_ns = $1 * 1000000;
	printf("Tracing file events slower than %d ms. Ctrl-C to end.\n", $1);
}

syscall::open:entry,
syscall::fstat:entry,
syscall::read:entry,
syscall::pread:entry,
syscall::write:entry,
syscall::pwrite:entry,
syscall::sendfile:entry
{
	self->sys_start = timestamp;
}

syscall::open:return,
syscall::fstat:return,
syscall::read:return,
syscall::pread:return,
syscall::write:return,
syscall::pwrite:return,
syscall::sendfile:return
/self->sys_start && (timestamp - self->sys_start) > min_ns/
{
	printf("%Y %s %9s(): %d ms\n", walltimestamp, execname, probefunc,
	    (timestamp - self->sys_start) / 1000000);
}

syscall::open:return,
syscall::fstat:return,
syscall::read:return,
syscall::pread:return,
syscall::write:return,
syscall::pwrite:return,
syscall::sendfile:return
{
	self->sys_start = 0;
}

syscall::aio_read:entry
{
	/*
	 * The following trick is unstable. The first member of aiocb is the FD,
	 * so instead of declaring the whole struct, we just treat it as a *int.
	 * If struct aiocb changes ordering, this will need to chage too.
	 */
	self->aio_read_start[*(int *)copyin(arg0, sizeof(int))] = timestamp;
}

syscall::aio_error:entry
/(this->start = self->aio_read_start[this->fd = *(int *)copyin(arg0, sizeof(int))]) &&
    (timestamp - this->start) > min_ns/
{
	printf("%Y %s %9s(): %d ms\n", walltimestamp, execname, probefunc,
	    (timestamp - this->start) / 1000000);
	self->aio_read_start[this->fd] = 0;
}

syscall::aio_error:entry
{
	self->aio_read_start[this->fd] = 0;
}
