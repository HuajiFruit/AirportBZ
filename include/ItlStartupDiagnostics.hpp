#ifndef ITL_STARTUP_DIAGNOSTICS_HPP
#define ITL_STARTUP_DIAGNOSTICS_HPP

#include <IOKit/IOService.h>
#include <IOKit/IOLib.h>
#include <kern/clock.h>

// Persist startup state on the PCI provider: a controller that fails start()
// may disappear before a user can inspect it. Do not log network payloads.
inline void ItlStartupStage(IOService *provider, const char *stage)
{
    if (!provider || !stage)
        return;
    provider->setProperty("ItlwmStartupStage", stage);
    // Last uptime at each checkpoint survives ring-buffer rollover. This
    // helper is used on startup/workloop paths, never the interrupt filter.
    char key[96] = "ItlwmStageTime";
    size_t length = strlen(key);
    for (const char *p = stage; *p && length + 1 < sizeof(key); p++) {
        if ((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
            (*p >= '0' && *p <= '9'))
            key[length++] = *p;
    }
    key[length] = 0;
    uint64_t nanoseconds = 0;
    absolutetime_to_nanoseconds(mach_absolute_time(), &nanoseconds);
    provider->setProperty(key, nanoseconds, 64);
    // IOLog also writes to the kernel console, which verbose boot (-v) draws
    // on screen. Boot stalls of 15-35 s were seen between stage markers;
    // record each IOLog that blocked for 100 ms or more, keyed like the stage
    // time, so the console can be confirmed or ruled out as their cause.
    uint64_t logStart = mach_absolute_time();
    IOLog("itlwm startup: %s\n", stage);
    uint64_t logNanoseconds = 0;
    absolutetime_to_nanoseconds(mach_absolute_time() - logStart, &logNanoseconds);
    if (logNanoseconds >= 100000000ULL) {
        // "ItlwmSlowLogMs" has the same length as "ItlwmStageTime".
        memcpy(key, "ItlwmSlowLogMs", 14);
        provider->setProperty(key, logNanoseconds / 1000000, 32);
    }
}

inline void ItlStartupResult(IOService *provider, const char *result)
{
    if (!provider || !result)
        return;
    if (!strcmp(result, "starting")) {
        provider->removeProperty("ItlwmStartupFailure");
        provider->removeProperty("ItlwmStartupError");
    }
    provider->setProperty("ItlwmStartupResult", result);
    IOLog("itlwm startup result: %s\n", result);
}

inline void ItlStartupFailure(IOService *provider, const char *checkpoint, int error)
{
    if (!provider || !checkpoint)
        return;
    // Preserve the deepest failure (for example PNVM), not an outer attach()
    // failure that only reports the same error as a boolean.
    if (!provider->getProperty("ItlwmStartupFailure")) {
        provider->setProperty("ItlwmStartupFailure", checkpoint);
        provider->setProperty("ItlwmStartupError", static_cast<UInt32>(error), 32);
    }
    provider->setProperty("ItlwmStartupResult", "failed");
    IOLog("itlwm startup failure: %s error=0x%08x\n", checkpoint,
          static_cast<unsigned int>(error));
}

#endif
