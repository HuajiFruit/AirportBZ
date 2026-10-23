// DMA candidate checks shared by the kernel allocator and host-side tests.
#ifndef ItlDmaConstraints_hpp
#define ItlDmaConstraints_hpp

#include <stdint.h>

static inline bool ItlDmaCandidateFits(uint64_t address, uint32_t size,
                                     uint32_t alignment, bool noCross4GiB)
{
    if (!size || !alignment || (alignment & (alignment - 1)) ||
        (address & (alignment - 1)) || address > UINT64_MAX - size)
        return false;

    /* Intel's ctxt-info allocation checks the end pointer, not the final
     * byte: an allocation ending exactly at 4 GiB is rejected as well.
     * See Linux iwl_txq_crosses_4g_boundary() / ctxt-info.c. */
    return !noCross4GiB || (address >> 32) == ((address + size) >> 32);
}

#endif
