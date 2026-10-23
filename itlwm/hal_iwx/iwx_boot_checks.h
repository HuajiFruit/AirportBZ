/* Shared, side-effect-free checks used by the BZ startup and error paths. */
#ifndef IWX_BOOT_CHECKS_H
#define IWX_BOOT_CHECKS_H

static inline bool
iwx_boot_io_invalid(uint32_t value)
{
    return value == 0xffffffffU || (value & 0xfffffff0U) == 0xa5a5a5a0U;
}

static inline bool
iwx_error_table_address_valid(uint32_t base, size_t size, bool bz, bool trusted)
{
    /* BZ's firmware-supplied tables live below the old 0x400000 floor.
     * Cache-control bits must already have been removed by the caller. */
    const uint32_t minimum = bz && trusted ? 0x000d0000U : 0x00400000U;
    return size >= 8 && size <= 512 && !(size & 3) && !(base & 3) &&
        base >= minimum && base < 0x40000000U &&
        size <= 0x40000000U - base;
}

#endif
