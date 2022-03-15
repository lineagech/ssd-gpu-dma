#ifndef __DEBUG_H__
#define __DEBUG_H__

#define BENCH_DEBUG 0

struct RuntimeCheckStruct
{
    const Controller *ctrl;
    QueuePair *host_qp;
    QueuePair *qp;
};

#endif
