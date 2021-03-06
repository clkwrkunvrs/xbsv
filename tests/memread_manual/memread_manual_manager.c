/* Copyright (c) 2014 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#ifdef __KERNEL__
#include <linux/delay.h>  // msleep
#include <linux/kthread.h>
#else
#include <string.h>
#include <sys/mman.h>
#include <pthread.h>
#include <fcntl.h>
#include <sys/select.h>
#endif

#include "dmaManager.h"
#include "sock_utils.h"  // bsim_poll_interrupt()
#include "GeneratedTypes.h" 

static int trace_memory;// = 1;

#define MAX_INDARRAY 4
static PortalInternal intarr[MAX_INDARRAY];

static sem_t test_sem;
static int burstLen = 16;
#ifndef BSIM
#define numWords 0x1240000/4 // make sure to allocate at least one entry of each size
#else
#define numWords 0x1240/4
#endif
static long test_sz  = numWords*sizeof(unsigned int);
static long alloc_sz = numWords*sizeof(unsigned int);
static DmaManagerPrivate priv;

void MemreadIndicationWrapperreadDone_cb (  struct PortalInternal *p, const uint32_t mismatchCount )
{
         PORTAL_PRINTF( "Memread_readDone(mismatch = %x)\n", mismatchCount);
         sem_post(&test_sem);
}
void MMUConfigIndicationWrapperconfigResp_cb (  struct PortalInternal *p, const uint32_t pointer)
{
        //PORTAL_PRINTF("configResp %x\n", pointer);
        sem_post(&priv.confSem);
}
void MMUConfigIndicationWrapperidResponse_cb (  struct PortalInternal *p, const uint32_t sglId ) {
        priv.sglId = sglId;
        sem_post(&priv.sglIdSem);
};
void DmaDebugIndicationWrapperaddrResponse_cb (  struct PortalInternal *p, const uint64_t physAddr )
{
        PORTAL_PRINTF("DmaIndication_addrResponse(physAddr=%"PRIx64")\n", physAddr);
}
void DmaDebugIndicationWrapperreportStateDbg_cb (  struct PortalInternal *p, const DmaDbgRec rec )
{
        PORTAL_PRINTF("reportStateDbg: {x:%08x y:%08x z:%08x w:%08x}\n", rec.x,rec.y,rec.z,rec.w);
        sem_post(&priv.dbgSem);
}
void DmaDebugIndicationWrapperreportMemoryTraffic_cb (  struct PortalInternal *p, const uint64_t words )
{
        //PORTAL_PRINTF("reportMemoryTraffic: words=%"PRIx64"\n", words);
        priv.mtCnt = words;
        sem_post(&priv.mtSem);
}
void MMUConfigIndicationWrappererror_cb (  struct PortalInternal *p, const uint32_t code, const uint32_t pointer, const uint64_t offset, const uint64_t extra ) {
static int maxnumber = 10;
if (maxnumber-- > 0)
        PORTAL_PRINTF("DmaIndication::dmaError(code=%x, pointer=%x, offset=%"PRIx64" extra=%"PRIx64"\n", code, pointer, offset, extra);
}
void DmaDebugIndicationWrappererror_cb (  struct PortalInternal *p, const uint32_t code, const uint32_t pointer, const uint64_t offset, const uint64_t extra ) {
static int maxnumber = 10;
if (maxnumber-- > 0)
        PORTAL_PRINTF("DmaIndication::dmaError(code=%x, pointer=%x, offset=%"PRIx64" extra=%"PRIx64"\n", code, pointer, offset, extra);
}

void manual_event(void)
{
static int maxnumber = 20;
    int i;

    for (i = 0; i < MAX_INDARRAY; i++) {
      PortalInternal *instance = &intarr[i];
      volatile unsigned int *map_base = instance->map_base;
      unsigned int queue_status;
      while ((queue_status= READL(instance, &map_base[IND_REG_QUEUE_STATUS]))) {
        unsigned int int_src = READL(instance, &map_base[IND_REG_INTERRUPT_FLAG]);
        unsigned int int_en  = READL(instance, &map_base[IND_REG_INTERRUPT_MASK]);
        unsigned int ind_count  = READL(instance, &map_base[IND_REG_INTERRUPT_COUNT]);
if (maxnumber-- > 0)
        PORTAL_PRINTF("(%d:fpga%d) about to receive messages int=%08x en=%08x qs=%08x cnt=%x\n", i, instance->fpga_number, int_src, int_en, queue_status, ind_count);
        instance->handler(instance, queue_status-1);
      }
    }
}

#ifdef __KERNEL__
DECLARE_COMPLETION(worker_completion);
#endif
static void *pthread_worker(void *p)
{
    void *rc = NULL;
    while (1) {
#if defined(BSIM) && !defined(__KERNEL__)
        if (bsim_poll_interrupt())
#endif
            manual_event();
#ifdef __KERNEL__
        msleep(10);
        if (kthread_should_stop())
            break;
#else ///////////////////////// userspace version
        struct timeval timeout;
        timeout.tv_sec = 0;
        timeout.tv_usec = 10000;
        select(0, NULL, NULL, NULL, &timeout);
#endif
    }
#ifdef __KERNEL__
    complete(&worker_completion);
#endif
    return rc;
}

int main(int argc, const char **argv)
{
  int srcAlloc;
  unsigned int *srcBuffer;
  unsigned int ref_srcAlloc;
  int rc = 0, i;
  pthread_t tid = 0;

  init_portal_internal(&intarr[0], IfcNames_HostMMUConfigIndication, MMUConfigIndicationWrapper_handleMessage);// fpga1
  init_portal_internal(&intarr[1], IfcNames_MemreadIndication, MemreadIndicationWrapper_handleMessage); // fpga2
  init_portal_internal(&intarr[2], IfcNames_HostMMUConfigRequest, MMUConfigRequestProxy_handleMessage); // fpga3
  init_portal_internal(&intarr[3], IfcNames_MemreadRequest, MemreadRequestProxy_handleMessage);    // fpga4

#ifdef BSIM
  portalEnableInterrupts(&intarr[0]);
  portalEnableInterrupts(&intarr[1]);
  portalEnableInterrupts(&intarr[2]);
  portalEnableInterrupts(&intarr[3]);
#endif

  sem_init(&test_sem, 0, 0);
  DmaManager_init(&priv, NULL, &intarr[2]);
  srcAlloc = portalAlloc(alloc_sz);
  if (rc){
    PORTAL_PRINTF("portal alloc failed rc=%d\n", rc);
    return rc;
  }

  PORTAL_PRINTF( "Main: creating exec thread\n");
  if(pthread_create(&tid, NULL, pthread_worker, NULL)){
   PORTAL_PRINTF( "error creating exec thread\n");
   return -1;
  }
  srcBuffer = (unsigned int *)portalMmap(srcAlloc, alloc_sz);

  for (i = 0; i < numWords; i++)
    srcBuffer[i] = i;

  PORTAL_PRINTF( "Test 1: check for match\n");
  portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
  PORTAL_PRINTF( "Main: before DmaManager_reference(%x)\n", srcAlloc);
  ref_srcAlloc = DmaManager_reference(&priv, srcAlloc);
  PORTAL_PRINTF( "Main: starting read %08x\n", numWords);
  MemreadRequestProxy_startRead (&intarr[3], ref_srcAlloc, numWords, burstLen, 1);
  PORTAL_PRINTF( "Main: waiting for semaphore1\n");
  sem_wait(&test_sem);

  PORTAL_PRINTF( "Test 2: check that mismatch is detected\n");
  for (i = 0; i < numWords; i++)
    srcBuffer[i] = 1-i;
  portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
  MemreadRequestProxy_startRead (&intarr[3], ref_srcAlloc, numWords, burstLen, 1);
  PORTAL_PRINTF( "Main: waiting for semaphore2\n");
  sem_wait(&test_sem);

  PORTAL_PRINTF( "Main: all done\n");
#ifdef __KERNEL__
  if (tid && !kthread_stop (tid)) {
    printk("kthread stops");
  }
  wait_for_completion(&worker_completion);
#endif

#ifdef __KERNEL__
  portalmem_dmabuffer_destroy(srcAlloc);
#endif
  return 0;
}
