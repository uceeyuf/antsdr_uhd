/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Old ANTSDR E310 bridge fast path between the PS GEM and the PL AXI DMA.
 *
 * Neither DMA master is cache coherent, and forwarding a frame only needs
 * its headers. A receive driver that recognises a frame as forwarded syncs
 * just E310_FASTPATH_HDR bytes for the CPU and marks the skb. Nothing on the
 * bridge path writes frame data, so the transmitting driver can map it
 * without cleaning: the device reads the DMA-written bytes from DDR, and any
 * cached payload lines are clean and never read. Locally delivered frames are
 * never marked. Packet taps on the ports only see valid headers.
 */
#ifndef _NET_E310_FASTPATH_H
#define _NET_E310_FASTPATH_H

#include <linux/skbuff.h>

#define E310_FASTPATH_MARK	0xe310fa57
/* Ethernet, IPv4 with options and UDP headers, plus NET_IP_ALIGN. */
#define E310_FASTPATH_HDR	128

static inline bool e310_fastpath_tx(const struct sk_buff *skb)
{
	return skb->mark == E310_FASTPATH_MARK && !skb_is_nonlinear(skb);
}

#endif
