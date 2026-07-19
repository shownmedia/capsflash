// capsflash — blink the caps lock LED without touching caps lock state.
// Usage: capsflash [blinks] [period_ms]   (default: 8 blinks, 120ms half-period)
//
// Finds every HID keyboard's caps-lock LED output element and toggles it.
// The real modifier state is never changed; on exit the LED is restored to
// the actual caps lock state so the indicator stays truthful.
//
// Build: clang -O2 -o capsflash capsflash.c -framework IOKit -framework CoreFoundation

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hidsystem/IOHIDLib.h>
#include <IOKit/hidsystem/IOHIDParameter.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

typedef struct {
    IOHIDDeviceRef dev;
    IOHIDElementRef elem;
} LedTarget;

static bool realCapsLockState(void) {
    bool state = false;
    io_service_t svc = IORegistryEntryFromPath(MACH_PORT_NULL,
        kIOServicePlane ":/IOResources/IOHIDSystem");
    if (svc) {
        io_connect_t conn = IO_OBJECT_NULL;
        if (IOServiceOpen(svc, mach_task_self(), kIOHIDParamConnectType, &conn) == KERN_SUCCESS) {
            IOHIDGetModifierLockState(conn, kIOHIDCapsLockState, &state);
            IOServiceClose(conn);
        }
        IOObjectRelease(svc);
    }
    return state;
}

static void setLed(LedTarget *t, bool on) {
    IOHIDValueRef v = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, t->elem, 0, on ? 1 : 0);
    IOHIDDeviceSetValue(t->dev, t->elem, v);
    CFRelease(v);
}

int main(int argc, char **argv) {
    int blinks = argc > 1 ? atoi(argv[1]) : 8;
    int period_ms = argc > 2 ? atoi(argv[2]) : 120;
    if (blinks < 1) blinks = 1;
    if (period_ms < 20) period_ms = 20;

    IOHIDManagerRef mgr = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);

    int pageKbd = kHIDPage_GenericDesktop, usageKbd = kHIDUsage_GD_Keyboard;
    CFNumberRef pageNum = CFNumberCreate(NULL, kCFNumberIntType, &pageKbd);
    CFNumberRef usageNum = CFNumberCreate(NULL, kCFNumberIntType, &usageKbd);
    const void *keys[] = { CFSTR(kIOHIDDeviceUsagePageKey), CFSTR(kIOHIDDeviceUsageKey) };
    const void *vals[] = { pageNum, usageNum };
    CFDictionaryRef match = CFDictionaryCreate(NULL, keys, vals, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOHIDManagerSetDeviceMatching(mgr, match);
    CFRelease(match); CFRelease(pageNum); CFRelease(usageNum);

    IOHIDManagerOpen(mgr, kIOHIDOptionsTypeNone);
    CFSetRef devSet = IOHIDManagerCopyDevices(mgr);
    if (!devSet) { fprintf(stderr, "no HID keyboards found\n"); return 1; }

    CFIndex ndev = CFSetGetCount(devSet);
    const void **devs = malloc(sizeof(void *) * ndev);
    CFSetGetValues(devSet, devs);

    LedTarget targets[64];
    int ntargets = 0;

    for (CFIndex i = 0; i < ndev && ntargets < 64; i++) {
        IOHIDDeviceRef dev = (IOHIDDeviceRef)devs[i];
        IOReturn r = IOHIDDeviceOpen(dev, kIOHIDOptionsTypeNone);
        if (r != kIOReturnSuccess) {
            fprintf(stderr, "device open failed (0x%x) — may need Input Monitoring permission\n", r);
            continue;
        }
        int pageLed = kHIDPage_LEDs, usageCaps = kHIDUsage_LED_CapsLock;
        CFNumberRef pl = CFNumberCreate(NULL, kCFNumberIntType, &pageLed);
        CFNumberRef uc = CFNumberCreate(NULL, kCFNumberIntType, &usageCaps);
        const void *ekeys[] = { CFSTR(kIOHIDElementUsagePageKey), CFSTR(kIOHIDElementUsageKey) };
        const void *evals[] = { pl, uc };
        CFDictionaryRef ematch = CFDictionaryCreate(NULL, ekeys, evals, 2,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFArrayRef elems = IOHIDDeviceCopyMatchingElements(dev, ematch, kIOHIDOptionsTypeNone);
        CFRelease(ematch); CFRelease(pl); CFRelease(uc);
        if (elems) {
            for (CFIndex j = 0; j < CFArrayGetCount(elems) && ntargets < 64; j++) {
                IOHIDElementRef e = (IOHIDElementRef)CFArrayGetValueAtIndex(elems, j);
                if (IOHIDElementGetType(e) == kIOHIDElementTypeOutput) {
                    targets[ntargets].dev = dev;
                    targets[ntargets].elem = (IOHIDElementRef)CFRetain(e);
                    ntargets++;
                }
            }
            CFRelease(elems);
        }
    }

    if (ntargets == 0) {
        fprintf(stderr, "no caps lock LED elements found\n");
        return 1;
    }

    bool restore = realCapsLockState();
    useconds_t half = (useconds_t)period_ms * 1000;

    for (int b = 0; b < blinks; b++) {
        for (int t = 0; t < ntargets; t++) setLed(&targets[t], true);
        usleep(half);
        for (int t = 0; t < ntargets; t++) setLed(&targets[t], false);
        usleep(half);
    }
    for (int t = 0; t < ntargets; t++) setLed(&targets[t], restore);

    printf("flashed %d LED element(s) %d times\n", ntargets, blinks);
    free(devs);
    CFRelease(devSet);
    return 0;
}
