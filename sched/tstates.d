#!/usr/sbin/dtrace -Cs
/*
 * tstates.d	Thread state analysis for FreeBSD.
 *
 * A proof of concept tool that prints times in different tread states,
 * to support a thread state analysis methodology:
 * http://www.brendangregg.com/tsamethod.html
 *
 * States are:
 *
 *	CPU	on-CPU
 *	RUNQ	Waiting on a CPU run queue
 *	SLP	Interruptible sleep
 *	USL	Uninterruptible sleep (eg, disk I/O)
 *	SUS	Suspended
 *	SWP	Swapped
 *	LCK	Lock
 *	IWT	Iwait
 *	YLD	Yield
 *
 * WARNING: This traces scheduler events, which may be very frequent on
 * your system, and so this may add some noticable overhead. Test in a
 * lab environment and quantify before use.
 *
 * If you see dynvardrops, it means the events were too frequent for
 * DTrace to keep up, so it has dropped events as a safety valve. The output
 * may not be reliable for that run. It can be tuned (see dynvarsize below).
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
#pragma D option dynvarsize=32m

/* from sys/proc.h: */
#define TDI_SUSPENDED   0x0001  /* On suspension queue. */
#define TDI_SLEEPING    0x0002  /* Actually asleep! (tricky). */
#define TDI_SWAPPED     0x0004  /* Stack not in mem.  Bad juju if run. */
#define TDI_LOCK        0x0008  /* Stopped on a lock. */
#define TDI_IWAIT       0x0010  /* Awaiting interrupt. */
#define TDF_SINTR       0x00000008 /* Sleep is interruptible. */

/* from td_state in sys/proc.h: */
#define TDS_INHIBITED 1

/* fake states for this program: */
#define TDI_UNINTSLEEP 0x1000  /* uninterruptible sleep */

dtrace:::BEGIN
{
	trace("Tracing scheduler events... Ctrl-C to end.\n");
}

/*
 * CPU
 * on-cpu -> off-cpu
 */
sched:::on-cpu
{
	self->rts = timestamp;
}
sched:::off-cpu
/self->rts/
{
	this->delta = timestamp - self->rts;
	@cpu[execname, pid] = sum(this->delta);
	self->rts = 0;
}

/*
 * RUNQ
 * enqueue/preempt -> dequeue/on-cpu
 */
sched:::preempt
{
	ets[(int64_t)curthread] = timestamp;
}
sched:::enqueue
{
	ets[arg0] = timestamp;
}
sched:::on-cpu
/this->start = ets[(int64_t)curthread]/
{
	this->delta = timestamp - this->start;
	@runq[execname, pid] = sum(this->delta);
	ets[(int64_t)curthread] = 0;
}
sched:::dequeue
/this->start = ets[(int64_t)arg0]/
{
	this->delta = timestamp - this->start;
	@runq[args[0]->td_name, args[0]->td_proc->p_pid] = sum(this->delta);
	ets[(int64_t)arg0] = 0;
}

/*
 * SLP (TDI_SLEEPING)
 * SUS (TDI_SUSPENDED)
 * SWP (TDI_SWAPPED)
 * LCK (TDI_LOCK)
 * IWT (TDI_IWAIT)
 * YLD (curthread->td_inhibitors == 0)
 * off-cpu (TDS_INACTIVE/TDS_INHIBITED) -> enqueue
 * I tested off-cpu (TDS 0/1) -> on-cpu without an enqueue, but didn't see it,
 * so it looks safe to rely on an enqueue event for these thread states.
 */

sched:::off-cpu
/curthread->td_state <= TDS_INHIBITED/
{
	/*
	 * Key using a associative array, since we want to trace enqueue, which
	 * is not in thread context.
	 * 
	 * Since associative arrays are racey and cause dynvardrops, I'm trying
	 * to avoid setting an extra one just for td_flags TDF_SINTR, so add
	 * that value into tdi as TDI_UNINTSLEEP.
	 */
	tdi[(int64_t)curthread] = curthread->td_inhibitors == TDI_SLEEPING &&
	    !(curthread->td_flags & TDF_SINTR) ?
	    TDI_UNINTSLEEP : curthread->td_inhibitors;
	sts[(int64_t)curthread] = timestamp;
}

/*
 * Populate this->td (thread ID), this->pid, and this->comm for later use both
 * in and out of thread context.
 */

sched:::enqueue { this->td = 0; }

sched:::enqueue
/sts[arg0]/
{
	this->td = arg0;
	this->pid = args[0]->td_proc->p_pid;
	this->comm = stringof(args[0]->td_name);
	this->tdi = tdi[arg0];
	this->delta = timestamp - sts[arg0];
	sts[arg0] = 0;
	tdi[arg0] = 0;
}

/*
 * td_inhibitors is a bit mask, but (for now) we'll only identify based on
 * one bit, in the following order from KTDSTATE in sys/proc.h:
 *
 * #define KTDSTATE(td)                                                    \
 *         (((td)->td_inhibitors & TDI_SLEEPING) != 0 ? "sleep"  :         \
 *         ((td)->td_inhibitors & TDI_SUSPENDED) != 0 ? "suspended" :      \
 *         ((td)->td_inhibitors & TDI_SWAPPED) != 0 ? "swapped" :          \
 *         ((td)->td_inhibitors & TDI_LOCK) != 0 ? "blocked" :             \
 *         ((td)->td_inhibitors & TDI_IWAIT) != 0 ? "iwait" : "yielding")
 */

sched:::enqueue /this->td && this->tdi == TDI_SLEEPING/	  { @slp[this->comm, this->pid] = sum(this->delta); }
sched:::enqueue /this->td && this->tdi == TDI_UNINTSLEEP/ { @usl[this->comm, this->pid] = sum(this->delta); }
sched:::enqueue /this->td && this->tdi == TDI_SUSPENDED/  { @sus[this->comm, this->pid] = sum(this->delta); }
sched:::enqueue /this->td && this->tdi == TDI_SWAPPED/	  { @swp[this->comm, this->pid] = sum(this->delta); }
sched:::enqueue /this->td && this->tdi == TDI_LOCK/	  { @lck[this->comm, this->pid] = sum(this->delta); }
sched:::enqueue /this->td && this->tdi == TDI_IWAIT/	  { @iwt[this->comm, this->pid] = sum(this->delta); }
sched:::enqueue /this->td && this->tdi == 0/		  { @yld[this->comm, this->pid] = sum(this->delta); }

dtrace:::END
{
	printf("Time (ms) per state:\n");

	/* output in milliseconds */
	normalize(@cpu, 1000000);
	normalize(@runq, 1000000);
	normalize(@slp, 1000000);
	normalize(@usl, 1000000);
	normalize(@sus, 1000000);
	normalize(@swp, 1000000);
	normalize(@lck, 1000000);
	normalize(@iwt, 1000000);
	normalize(@yld, 1000000);

	/* Output is 79 chars wide, on purpose. No more chars! */
	printf("%-16s %-6s %6s %5s %6s %6s %5s %5s %5s %5s %5s\n", "COMM",
	    "PID", "CPU", "RUNQ", "SLP", "USL", "SUS", "SWP", "LCK", "IWT",
	    "YLD");
	printa("%-16s %-6d %@6d %@5d %@6d %@6d %@5d %@5d %@5d %@5d %@5d\n",
	    @cpu, @runq, @slp, @usl, @sus, @swp, @lck, @iwt, @yld);
}
