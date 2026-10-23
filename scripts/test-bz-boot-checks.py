#!/usr/bin/env python3
"""Host unit checks for actual driver methods; no hardware emulation/boot claim."""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'itlwm/hal_iwx/ItlIwx.cpp').read_text()
var = (root / 'itlwm/hal_iwx/if_iwxvar.h').read_text()

def block(text, marker):
    start = text.index(marker)
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

structs = block(var, 'struct iwx_boot_diagnostics {') + ';\n'
for name in ('iwx_error_event_table', 'iwx_umac_error_event_table'):
    structs += block(source, 'struct ' + name + ' {') + ';\n'
# The gate-sleep slice and wait codes, taken from the driver header.
structs += '\n'.join(re.findall(r'^#define IWX_(?:GATE_|HOST_COMPLETE_)\w+\s+\d+',
                                var, re.M)) + '\n'
methods = []
for name in ('iwx_bz_config_msi', 'iwx_bz_restore_boot_interrupts',
             'iwx_read_error_table', 'iwx_bz_capture_error_tables', 'iwx_gate_sleep',
             'iwx_wait_notification'):
    match = re.search(r'(int|void) ItlIwx::\n' + name + r'\(', source)
    assert match, name
    methods.append(block(source, match.group(0)))

interrupt = block(source, 'iwx_intr(OSObject *object, IOInterruptEventSource* sender, int count)')
# Exercise the actual ALIVE action below, and check its placement in the ISR.
alive = block(interrupt, 'if (r1 & IWX_CSR_INT_BIT_ALIVE) {\n        int i;')
assert 'iwx_bz_config_msi' not in interrupt
assert 'iwx_nic_lock' not in alive
assert interrupt.index(alive) < interrupt.index('that->iwx_bz_restore_boot_interrupts(sc)')

harness = r'''
#include <cstdint>
#include <cstddef>
#include <cstring>
#include <cassert>
#include <cerrno>
#include <map>
#include <string>
#include <vector>
#include <cstdio>
#include "iwx_boot_checks.h"
using std::uint32_t;
constexpr int IWX_DEVICE_FAMILY_BZ = 100;
constexpr uint32_t IWX_CSR_INT_BIT_ALIVE = 1, IWX_CSR_INT_BIT_FH_RX = 0x80000000U;
constexpr uint32_t IWX_CSR_INT_BIT_SW_ERR = 1U << 25, IWX_CSR_INT_BIT_HW_ERR = 1U << 29;
constexpr uint32_t IWX_HBUS_TARG_WRPTR = 0x460, IWX_RFH_Q0_FRBDCB_WIDX_TRG = 0x1c80;
#define IWX_HBUS_TARG_WRPTR_RX_Q(q) (((q) + 512) << 16)
constexpr uint32_t IWX_UREG_CHICK = 0xa05c00, IWX_UREG_CHICK_MSI_ENABLE = 0x1000000;
constexpr uint32_t IWX_CSR_INT_MASK = 0xc, IWX_FW_ADDR_CACHE_CONTROL = 0xc0000000;
constexpr uint32_t IWX_ERROR_EVENT_TABLE_LMAC1 = 1, IWX_ERROR_EVENT_TABLE_UMAC = 4;
constexpr int THREAD_UNINT=0, THREAD_AWAKENED=0, THREAD_TIMED_OUT=1, kMillisecondScale=0;
using AbsoluteTime = uint64_t;
uint64_t test_time = 0;
uint64_t iwx_boot_time_ns() { return ++test_time; }
void clock_interval_to_deadline(uint32_t, int, uint64_t *p) { *p=0; }
struct PCI {
    std::map<std::string, uint64_t> values;
    std::map<std::string, std::vector<unsigned char>> raw;
    void setProperty(const char *n, uint64_t v, unsigned) { values[n]=v; }
    void setProperty(const char *n, bool v) { values[n]=v; }
    void setProperty(const char *n, void *v, unsigned size) {
        auto p=static_cast<unsigned char *>(v); raw[n]={p,p+size};
    }
    void removeProperty(const char *n) { raw.erase(n); }
};
''' + structs + r'''
struct iwx_softc {
    iwx_boot_diagnostics sc_boot_diag{};
    uint32_t sc_boot_filter_count=0;
    uint32_t sc_intmask=0;
    struct { int count=512, write=511; } rxq;
    int sc_device_family=IWX_DEVICE_FAMILY_BZ, sc_generation=1;
    struct { int uc_intr=0, uc_ok=0; uint32_t uc_lmac_error_event_table[2]{},
        uc_umac_error_event_table=0, error_event_table_tlv_status=0; } sc_uc;
    uint32_t sc_gate_stall_max_ms=0, sc_gate_stalls=0;
    PCI pci;
    PCI *sc_pcitag=&pci;
};
struct Gate {
    int wakes=0, sleeps=0, sleep_error=0, answer_on=0;
    uint64_t stall_ns=0;  // time each sleep spends waiting for the gate
    int *answer=nullptr;  // set on sleep answer_on, as the RX action would
    iwx_softc *sc=nullptr;
    void commandWakeup(int *) { wakes++; }
    int commandSleep(void *, AbsoluteTime, int) {
        sleeps++; if(sleep_error) sc->sc_boot_diag.error=sleep_error;
        test_time+=stall_ns;
        if(answer && sleeps==answer_on) { *answer=1; return THREAD_AWAKENED; }
        return THREAD_TIMED_OUT;
    }
};
struct ItlIwx {
    Gate gate;
    bool lock_ok=true;
    int locks=0, unlocks=0, route_writes=0, mem_reads=0;
    std::vector<uint32_t> route_reads;
    int mem_error=0; bool bad_memory=false;
    Gate *getMainCommandGate() { return &gate; }
    int iwx_nic_lock(iwx_softc *) { locks++; return lock_ok; }
    void iwx_nic_unlock(iwx_softc *) { unlocks++; }
    uint32_t iwx_read_umac_prph(iwx_softc *, uint32_t r) {
        assert(r==IWX_UREG_CHICK && !route_reads.empty());
        auto v=route_reads.front(); route_reads.erase(route_reads.begin()); return v;
    }
    void iwx_write_umac_prph(iwx_softc *, uint32_t r, uint32_t v) {
        assert(r==IWX_UREG_CHICK && v==IWX_UREG_CHICK_MSI_ENABLE); route_writes++;
    }
    int iwx_read_mem(iwx_softc *, uint32_t, void *p, int words) {
        mem_reads++; if(mem_error) return mem_error;
        memset(p,0,words*4); auto v=static_cast<uint32_t *>(p);
        v[0]=bad_memory?0xffffffffU:1; v[1]=0x1234; return 0;
    }
    int iwx_bz_config_msi(iwx_softc *, uint32_t *, uint32_t *);
    void iwx_bz_restore_boot_interrupts(iwx_softc *);
    int iwx_read_error_table(iwx_softc *, uint32_t, void *, size_t, bool);
    void iwx_bz_capture_error_tables(iwx_softc *);
    int iwx_gate_sleep(iwx_softc *, void *, uint32_t *, int);
    int iwx_wait_notification(iwx_softc *, int *, int, uint32_t);
    void iwx_update_rx_desc(iwx_softc *, decltype(iwx_softc::rxq) *, int, int) {
        assert(false && "BZ must not take the old RFH path");
    }
};
std::vector<uint32_t> mask_reads;
int mask_writes=0, race_read=0, reads=0;
std::vector<uint32_t> write_order;
uint32_t read_mask(iwx_softc *sc, uint32_t r) {
    assert(r==IWX_CSR_INT_MASK && !mask_reads.empty());
    if(++reads==race_read) sc->sc_boot_filter_count++;
    auto v=mask_reads.front(); mask_reads.erase(mask_reads.begin()); return v;
}
void write_mask(iwx_softc *, uint32_t r, uint32_t v) {
    write_order.push_back(r);
    if(r==IWX_CSR_INT_MASK) {
        assert(v==0x80000001U); mask_writes++;
    } else {
        assert(r==IWX_HBUS_TARG_WRPTR && v==(IWX_HBUS_TARG_WRPTR_RX_Q(0)|504U));
    }
}
#define IWX_READ(sc,reg) read_mask(sc,reg)
#define IWX_WRITE(sc,reg,val) write_mask(sc,reg,val)
''' + '\n'.join(methods) + '\nvoid exercise_alive(ItlIwx *that, iwx_softc *sc, uint32_t r1) {\n' + alive + '\n}\n' + r'''
int main() {
    assert(iwx_error_table_address_valid(0x2f6cb0,152,true,true));
    assert(iwx_error_table_address_valid(0x2490a8,60,true,true));
    assert(!iwx_error_table_address_valid(0x2f6cb0,152,true,false));
    assert(!iwx_error_table_address_valid(0x2f6cb0,152,false,true));
    assert(iwx_error_table_address_valid(0x400000,152,false,false));
    for(auto base:{0U,0xcffffU,0xd0001U,0xffffffffU,0x3ffffffcU})
        assert(!iwx_error_table_address_valid(base,152,true,true));
    assert(!iwx_error_table_address_valid(0xd0000,513,true,true));
    assert(!iwx_error_table_address_valid(0xd0000,7,true,true));

    for(int mode=0;mode<5;mode++) {
        ItlIwx driver; iwx_softc sc; uint32_t before,after;
        driver.lock_ok=mode!=0;
        driver.route_reads=mode==1?std::vector<uint32_t>{0xffffffffU}:
            std::vector<uint32_t>{0x10000000U,mode==2?0xa5a5a5a0U:mode==3?0U:0x1000000U};
        int err=driver.iwx_bz_config_msi(&sc,&before,&after);
        assert(err==(mode==0?EBUSY:(mode==1||mode==2)?ENXIO:0));
        assert(driver.unlocks==(mode!=0));
        assert(driver.route_writes==(mode>=2));
    }
    auto check_mask=[](std::vector<uint32_t> values,int race,int expected_error,int writes){
        ItlIwx driver; iwx_softc sc;
        sc.sc_boot_filter_count=sc.sc_boot_diag.callbacks=1;
        sc.sc_boot_diag.action_filter_mark=1;
        mask_reads=values; mask_writes=0; reads=0; race_read=race;
        driver.iwx_bz_restore_boot_interrupts(&sc);
        assert(sc.sc_boot_diag.error==expected_error && mask_writes==writes);
        assert(driver.gate.wakes==(expected_error!=0));
        assert(sc.sc_uc.uc_intr==0 && sc.sc_uc.uc_ok==0);
        if(race) assert(sc.sc_boot_diag.restore_raced==1);
        else if(!expected_error && values.front()!=0x80000001U)
            assert(sc.sc_boot_diag.restore_mismatches==1);
    };
    check_mask({0x80000001U},0,0,1);
    check_mask({1U},0,0,1); // Missing FH_RX is evidence, not EIO or a retry.
    check_mask({0U},0,0,1);
    check_mask({0xffffffffU},0,ENXIO,1);
    check_mask({0xa5a5a5a0U},0,ENXIO,1);
    check_mask({0U},1,0,1);
    {
        ItlIwx driver; iwx_softc sc;
        sc.sc_boot_filter_count=2; sc.sc_boot_diag.action_filter_mark=1;
        mask_writes=0; mask_reads.clear();
        driver.iwx_bz_restore_boot_interrupts(&sc);
        assert(mask_writes==0 && sc.sc_boot_diag.restore_raced==1 && !sc.sc_boot_diag.error);
    }

    {
        ItlIwx driver; iwx_softc sc;
        sc.sc_boot_diag.active=true;
        driver.gate.sc=&sc;
        mask_reads={0U,1U}; reads=0; race_read=0; write_order.clear();
        exercise_alive(&driver,&sc,IWX_CSR_INT_BIT_ALIVE);
        driver.iwx_bz_restore_boot_interrupts(&sc);
        assert((write_order==std::vector<uint32_t>{IWX_HBUS_TARG_WRPTR,IWX_CSR_INT_MASK}));
        assert(sc.sc_boot_diag.alive_rx_doorbell_writes==1);
        assert(sc.sc_boot_diag.alive_rx_doorbell_time_ns<sc.sc_boot_diag.restore_first_time_ns);
        assert(driver.route_writes==0 && driver.locks==0);
        assert(!sc.sc_boot_diag.error && !driver.gate.wakes);
        assert(driver.iwx_wait_notification(&sc,&sc.sc_uc.uc_intr,1,2000)==EWOULDBLOCK);
        // 2000 ms of 10 ms slices, none of them stalled.
        assert(driver.gate.sleeps==200 && !sc.sc_uc.uc_intr && !sc.sc_uc.uc_ok);
        assert(!sc.sc_gate_stalls && !sc.pci.values.count("ItlwmGateStallMaxMs"));
        for(auto cause:{IWX_CSR_INT_BIT_SW_ERR,IWX_CSR_INT_BIT_HW_ERR}) {
            write_order.clear();
            exercise_alive(&driver,&sc,IWX_CSR_INT_BIT_ALIVE|cause);
            assert(write_order.empty()); // Do not hand buffers to a fatal boot.
        }
    }

    ItlIwx driver; iwx_softc sc;
    sc.sc_uc.uc_lmac_error_event_table[0]=0; // LMAC fails; UMAC must still be captured.
    sc.sc_uc.uc_umac_error_event_table=0x2490a8;
    sc.sc_uc.error_event_table_tlv_status=5;
    driver.iwx_bz_capture_error_tables(&sc);
    assert(driver.mem_reads==1);
    assert(sc.pci.values["ItlwmLmacErrorTableReadError"]==EINVAL);
    assert(sc.pci.values["ItlwmUmacErrorId"]==0x1234);
    assert(sc.pci.raw["ItlwmUmacErrorTableRaw"].size()==60);
    driver.mem_error=EBUSY;
    driver.iwx_bz_capture_error_tables(&sc);
    assert(sc.pci.values["ItlwmUmacErrorTableReadError"]==EBUSY);
    assert(!sc.pci.values["ItlwmUmacErrorTableValid"]);
    assert(!sc.pci.raw.count("ItlwmUmacErrorTableRaw"));
    driver.mem_error=0; driver.bad_memory=true;
    driver.iwx_bz_capture_error_tables(&sc);
    assert(sc.pci.values["ItlwmUmacErrorTableReadError"]==EIO);

    ItlIwx waiter; iwx_softc waiting;
    waiting.sc_boot_diag.active=true; waiting.sc_boot_diag.error=EIO;
    waiter.gate.sc=&waiting;
    assert(waiter.iwx_wait_notification(&waiting,&waiting.sc_uc.uc_intr,1,2000)==EIO);
    assert(waiter.gate.sleeps==0 && !waiting.sc_uc.uc_intr);
    waiting.sc_boot_diag.error=0; waiter.gate.sleep_error=EBUSY;
    assert(waiter.iwx_wait_notification(&waiting,&waiting.sc_uc.uc_intr,1,2000)==EBUSY);
    assert(waiter.gate.sleeps==1 && !waiting.sc_uc.uc_intr);

    {
        // Model a long gate stall: the RX action can deliver the response only
        // after this thread gets the gate back. Charge the requested 10 ms
        // slice rather than the full wall-clock delay.
        ItlIwx stalled; iwx_softc sc; int done=0;
        stalled.gate.sc=&sc; stalled.gate.stall_ns=22000000000ULL;
        stalled.gate.answer=&done; stalled.gate.answer_on=2;
        assert(stalled.iwx_wait_notification(&sc,&done,1,1000)==0 && done==1);
        assert(stalled.gate.sleeps==2 && sc.sc_gate_stalls==2);
        assert(sc.pci.values["ItlwmGateStallMaxMs"]==22000);
        assert(sc.pci.values["ItlwmGateStallWait"]==IWX_GATE_WAIT_NOTIF);
        assert(sc.pci.values["ItlwmGateStalls"]==2);
    }
    {
        // A budget still ends the wait when every slice stalls.
        ItlIwx stalled; iwx_softc sc; int flag=0; uint32_t budget=30;
        stalled.gate.sc=&sc; stalled.gate.stall_ns=22000000000ULL;
        assert(stalled.iwx_wait_notification(&sc,&flag,1,30)==EWOULDBLOCK);
        assert(stalled.gate.sleeps==3 && !flag);
        // A slice that is woken is not charged.
        stalled.gate.stall_ns=0; stalled.gate.answer=&flag; stalled.gate.answer_on=4;
        assert(stalled.iwx_gate_sleep(&sc,&flag,&budget,IWX_GATE_WAIT_CMD)==0);
        assert(budget==30 && flag==1);
    }
    puts("PASS: BZ address checks, route errors/unlocks, ALIVE doorbell before mask restore, no route rewrite, nonfatal mask mismatch/full wait, IRQ races, independent error capture, failure wakeup, gate stalls not charged to waits.");
    puts("Scope: host unit tests of extracted production methods, not hardware or AirPort connectivity.");
}
'''

with tempfile.TemporaryDirectory(prefix='bz-boot-checks-') as directory:
    temp = Path(directory)
    (temp / 'test.cpp').write_text(harness)
    subprocess.run(['clang++', '-std=c++14', '-Wall', '-Wextra', '-Werror',
                    '-fsanitize=address,undefined', '-fno-omit-frame-pointer',
                    '-I', str(root / 'itlwm/hal_iwx'), str(temp / 'test.cpp'),
                    '-o', str(temp / 'test')], check=True)
    subprocess.run([str(temp / 'test')], check=True)
