#include <cuda.h>
#include "settings.h"
#include "ctrl.h"
#include "buffer.h"
#include "queue.h"
#include <nvm_util.h>
#include <nvm_error.h>
#include <nvm_types.h>
#include <nvm_admin.h>
#include <stdexcept>
#include <string>
#include <cstdint>

// CHIA-HAO: include debug.h
#include "debug.h"

using error = std::runtime_error;
using std::string;

__host__ DmaPtr prepareQueuePairOnHost(QueuePair& qp, const Controller& ctrl, const Settings& settings)
{
    size_t queueMemSize = ctrl.info.page_size * 2;
    size_t prpListSize = ctrl.info.page_size * settings.numThreads * (settings.doubleBuffered + 1);

    // qmem->vaddr will be already a device pointer after the following call
    // nvm_dma_t *qmem
    auto qmem = createDmaOnHost(ctrl.ctrl, NVM_PAGE_ALIGN(queueMemSize + prpListSize, 1UL << 16), settings.cudaDevice, settings.adapter, settings.segmentId);

    // Set members
    qp.pageSize = ctrl.info.page_size;
    qp.blockSize = ctrl.ns.lba_data_size;
    qp.nvmNamespace = ctrl.ns.ns_id;
    qp.pagesPerChunk = settings.numPages;
    qp.doubleBuffered = settings.doubleBuffered;
    
    qp.prpList = NVM_DMA_OFFSET(qmem, 2);
    qp.prpListIoAddr = qmem->ioaddrs[2];
    
    // Create completion queue
    int status = nvm_admin_cq_create(ctrl.aq_ref, &qp.cq, 1, qmem->vaddr, qmem->ioaddrs[0]);
    if (!nvm_ok(status))
    {
        throw error(string("Failed to create completion queue: ") + nvm_strerror(status));
    }

    // Get a valid device pointer for CQ doorbell
    void* devicePtr = nullptr;
    cudaError_t err = cudaHostGetDevicePointer(&devicePtr, (void*) qp.cq.db, 0);
    if (err != cudaSuccess)
    {
        throw error(string("Failed to get device pointer") + cudaGetErrorString(err));
    }
    // CHIA-HAO: for debug
    #if BENCH_DEBUG
    printf("Completin queue doorbell devicePtr %p -> %p\n", (void*)qp.cq.db, devicePtr);
    qp.cq.host_db = qp.cq.db;
    #endif /* END OF BENCH_DEBUG*/
    
    qp.cq.db = (volatile uint32_t*) devicePtr;

    // Create submission queue
    status = nvm_admin_sq_create(ctrl.aq_ref, &qp.sq, &qp.cq, 1, NVM_DMA_OFFSET(qmem, 1), qmem->ioaddrs[1]);
    if (!nvm_ok(status))
    {
        throw error(string("Failed to create submission queue: ") + nvm_strerror(status));
    }

    // Get a valid device pointer for SQ doorbell
    err = cudaHostGetDevicePointer(&devicePtr, (void*) qp.sq.db, 0);
    if (err != cudaSuccess)
    {
        throw error(string("Failed to get device pointer") + cudaGetErrorString(err));
    }
    // CHIA-HAO: for debug
    #if BENCH_DEBUG
    printf("Submission queue doorbell devicePtr %p -> %p\n", (void*)qp.sq.db, devicePtr);
    qp.sq.host_db = qp.sq.db;
    #endif /* END OF BENCH_DEBUG*/

    qp.sq.db = (volatile uint32_t*) devicePtr;

    return qmem;
}


__host__ DmaPtr prepareQueuePair(QueuePair& qp, const Controller& ctrl, const Settings& settings)
{
    size_t queueMemSize = ctrl.info.page_size * 2;
    size_t prpListSize = ctrl.info.page_size * settings.numThreads * (settings.doubleBuffered + 1);

    // qmem->vaddr will be already a device pointer after the following call
    auto qmem = createDma(ctrl.ctrl, NVM_PAGE_ALIGN(queueMemSize + prpListSize, 1UL << 16), settings.cudaDevice, settings.adapter, settings.segmentId);
    
    // CHIA-HAO:
    fprintf(stderr, "Allocate queue mem %zu bytes\n", NVM_PAGE_ALIGN(queueMemSize + prpListSize, 1UL << 16));
    for (uint32_t i = 0; i < qmem->n_ioaddrs; i++) {
        fprintf(stderr, "queue mem: %u-th page vaddr %lx and ioaddr %lx\n",
                i, (uint64_t)qmem->vaddr+qmem->page_size*i, *(qmem->ioaddrs+i));    
    }

    // Set members
    qp.pageSize = ctrl.info.page_size;
    qp.blockSize = ctrl.ns.lba_data_size;
    qp.nvmNamespace = ctrl.ns.ns_id;
    qp.pagesPerChunk = settings.numPages;
    qp.doubleBuffered = settings.doubleBuffered;
    
    qp.prpList = NVM_DMA_OFFSET(qmem, 2);
    qp.prpListIoAddr = qmem->ioaddrs[2];
    
    // CHIA-HAO
    fprintf(stderr, "%s: queu pair prpList %p (ioaddr %lx)\n", __func__, qp.prpList, qp.prpListIoAddr);

    // Create completion queue
    int status = nvm_admin_cq_create(ctrl.aq_ref, &qp.cq, 1, qmem->vaddr, qmem->ioaddrs[0]);
    if (!nvm_ok(status))
    {
        throw error(string("Failed to create completion queue: ") + nvm_strerror(status));
    }
    // CHIA-HAO:
    fprintf(stderr, "%s: cq vaddr %p, ioaddr %lx\n", __func__, qmem->vaddr, qmem->ioaddrs[0]);

    // Get a valid device pointer for CQ doorbell
    void* devicePtr = nullptr;
    cudaError_t err = cudaHostGetDevicePointer(&devicePtr, (void*) qp.cq.db, 0);
    if (err != cudaSuccess)
    {
        throw error(string("Failed to get device pointer") + cudaGetErrorString(err));
    }
    // CHIA-HAO
    printf("Completin queue doorbell devicePtr %p\n", devicePtr);
    qp.cq.host_db = qp.cq.db;
    
    qp.cq.db = (volatile uint32_t*) devicePtr;

    // Create submission queue
    status = nvm_admin_sq_create(ctrl.aq_ref, &qp.sq, &qp.cq, 1, NVM_DMA_OFFSET(qmem, 1), qmem->ioaddrs[1]);
    if (!nvm_ok(status))
    {
        throw error(string("Failed to create submission queue: ") + nvm_strerror(status));
    }
    // CHIA-HAO:
    fprintf(stderr, "%s: cq vaddr %p, ioaddr %lx\n", __func__, NVM_DMA_OFFSET(qmem, 1), qmem->ioaddrs[1]);


    // Get a valid device pointer for SQ doorbell
    err = cudaHostGetDevicePointer(&devicePtr, (void*) qp.sq.db, 0);
    if (err != cudaSuccess)
    {
        throw error(string("Failed to get device pointer") + cudaGetErrorString(err));
    }
    // CHIA-HAO
    printf("Submission queue doorbell devicePtr %p\n", devicePtr);
    qp.sq.host_db = qp.sq.db;

    qp.sq.db = (volatile uint32_t*) devicePtr;

    return qmem;
}

