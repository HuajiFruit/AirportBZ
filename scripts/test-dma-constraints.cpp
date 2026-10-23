// Compiles the exact candidate predicate used by ItlDmaArena::allocate.
// Run: c++ -std=c++11 -Wall -Wextra -Werror scripts/test-dma-constraints.cpp -o /tmp/itl-dma-test && /tmp/itl-dma-test
#include "../itl80211/ItlDmaConstraints.hpp"
#include <assert.h>
#include <stdio.h>

int main()
{
    // Valid 36-bit addresses remain usable; no forced below-4-GiB fallback.
    assert(ItlDmaCandidateFits(0x100002000ULL, 32768, 4096, true));
    assert(ItlDmaCandidateFits(0xFFFFFF000ULL, 4095, 4096, true));
    assert(ItlDmaCandidateFits(0xFFFF0000ULL, 32768, 4096, true));

    // Intel rejects both crossing and a buffer ending exactly on a boundary.
    assert(!ItlDmaCandidateFits(0xFFFFF000ULL, 8192, 4096, true));
    assert(!ItlDmaCandidateFits(0xFFFFF000ULL, 4096, 4096, true));
    assert(ItlDmaCandidateFits(0xFFFFF000ULL, 4095, 4096, true));
    assert(!ItlDmaCandidateFits(0x1FFFFF000ULL, 4096, 4096, true));
    assert(ItlDmaCandidateFits(0xFFFFF000ULL, 8192, 4096, false));
    assert(ItlDmaCandidateFits(0xFFFFF000ULL, 4096, 4096, false));

    // Alignment, overflow and invalid input are checked by production code.
    assert(!ItlDmaCandidateFits(0x100001000ULL, 4096, 8192, true));
    assert(!ItlDmaCandidateFits(UINT64_MAX - 4095, 4096, 4096, false));
    assert(!ItlDmaCandidateFits(0, 0, 4096, true));
    assert(!ItlDmaCandidateFits(0, 4096, 0, true));
    assert(!ItlDmaCandidateFits(0, 4096, 3, true));

    // A 1-MiB arena is permitted to straddle 4 GiB. Its crossing candidate
    // must be skipped, while the first page after the boundary stays usable.
    const uint64_t base = 0xFFFFF000ULL;
    uint32_t selected = 256;
    for (uint32_t page = 0; page + 8 <= 256; page++) {
        if (ItlDmaCandidateFits(base + uint64_t(page) * 4096,
                                32768, 4096, true)) {
            selected = page;
            break;
        }
    }
    assert(selected == 1);
    puts("DMA candidate constraints: all tests passed");
    return 0;
}
