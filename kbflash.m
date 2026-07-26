// kbflash — "breathe" the MacBook keyboard backlight (white) as a notification.
// Usage: kbflash [cycles] [cycle_ms] [max_level]
//        (default: 5 breaths, 2400ms per breath, peak 1.0, hardware-faded)
//
// Smoothly ramps the backlight 0 -> max -> 0 (sine-eased) instead of hard
// blinking. Uses the private CoreBrightness.framework KeyboardBrightnessClient.
// Saves the current backlight level and restores it on exit.
//
// Requires System Settings > Keyboard > "Adjust keyboard brightness in low
// light" to be OFF, otherwise ambient-light suppression zeroes every set.
//
// Build: clang -O2 -fobjc-arc -o kbflash kbflash.m -framework Foundation
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <math.h>
#include <objc/message.h>
#include <unistd.h>

int main(int argc, char **argv) {
    int cycles = argc > 1 ? atoi(argv[1]) : 5;
    int cycle_ms = argc > 2 ? atoi(argv[2]) : 2400;
    float maxLevel = argc > 3 ? atof(argv[3]) : 1.0f;
    if (cycles < 1) cycles = 1;
    if (cycle_ms < 400) cycle_ms = 400;
    if (maxLevel <= 0 || maxLevel > 1) maxLevel = 1.0f;

    if (!dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY)) {
        fprintf(stderr, "dlopen CoreBrightness failed\n");
        return 1;
    }
    Class KBC = NSClassFromString(@"KeyboardBrightnessClient");
    if (!KBC) {
        fprintf(stderr, "KeyboardBrightnessClient class not found\n");
        return 1;
    }
    id client = [[KBC alloc] init];

    unsigned long long kid = 1;
    SEL idsSel = NSSelectorFromString(@"copyKeyboardBacklightIDs");
    if ([client respondsToSelector:idsSel]) {
        NSArray *ids = ((NSArray *(*)(id, SEL))objc_msgSend)(client, idsSel);
        if (ids.count) kid = [ids.firstObject unsignedLongLongValue];
    }

    SEL getSel = NSSelectorFromString(@"brightnessForKeyboard:");
    SEL setSel = NSSelectorFromString(@"setBrightness:forKeyboard:");
    SEL autoGetSel = NSSelectorFromString(@"isAutoBrightnessEnabledForKeyboard:");
    SEL autoSetSel = NSSelectorFromString(@"enableAutoBrightness:forKeyboard:");
    if (![client respondsToSelector:getSel] || ![client respondsToSelector:setSel]) {
        fprintf(stderr, "brightness selectors missing on this OS\n");
        return 1;
    }
    float (*getB)(id, SEL, unsigned long long) = (void *)objc_msgSend;
    BOOL (*setB)(id, SEL, float, unsigned long long) = (void *)objc_msgSend;
    BOOL (*getAuto)(id, SEL, unsigned long long) = (void *)objc_msgSend;
    BOOL (*setAuto)(id, SEL, BOOL, unsigned long long) = (void *)objc_msgSend;
    // fadeSpeed 0 = commit instantly; we do our own easing in fine steps.
    SEL fadeSel = NSSelectorFromString(@"setBrightness:fadeSpeed:commit:forKeyboard:");
    BOOL hasFade = [client respondsToSelector:fadeSel];
    BOOL (*setFade)(id, SEL, float, unsigned int, BOOL, unsigned long long) = (void *)objc_msgSend;
#define SET_LEVEL(v) (hasFade ? setFade(client, fadeSel, (v), 0, YES, kid) \
                              : setB(client, setSel, (v), kid))

    // Auto-brightness silently overrides manual sets, so pause it while breathing.
    BOOL hasAuto = [client respondsToSelector:autoGetSel] && [client respondsToSelector:autoSetSel];
    BOOL origAuto = hasAuto ? getAuto(client, autoGetSel, kid) : NO;
    float orig = getB(client, getSel, kid);
    if (hasAuto && origAuto) setAuto(client, autoSetSel, NO, kid);

    useconds_t half = (useconds_t)cycle_ms * 1000 / 2;
    unsigned int fadeMs = (unsigned int)(cycle_ms / 2);
    if (hasFade) {
        // Two commands per breath, hardware interpolates the whole ramp.
        // Stepping it ourselves reads as jitter: each commit cancels the
        // previous transition mid-step.
        for (int c = 0; c < cycles; c++) {
            setFade(client, fadeSel, maxLevel, fadeMs, YES, kid);
            usleep(half);
            setFade(client, fadeSel, 0.0f, fadeMs, YES, kid);
            usleep(half);
        }
        setFade(client, fadeSel, orig, 500, YES, kid);
    } else {
        const int STEPS = 64;
        useconds_t stepUs = (useconds_t)cycle_ms * 1000 / STEPS;
        for (int c = 0; c < cycles; c++) {
            for (int s = 0; s < STEPS; s++) {
                float x = (float)(0.5 * (1.0 - cos(2.0 * M_PI * s / STEPS)));
                float level = maxLevel * powf(x, 2.2f);
                setB(client, setSel, level, kid);
                usleep(stepUs);
            }
        }
        setB(client, setSel, orig, kid);
    }
    if (hasAuto && origAuto) setAuto(client, autoSetSel, YES, kid);

    printf("breathed keyboard %llu backlight %d times (restored to %.2f, auto=%d)\n",
           kid, cycles, orig, origAuto);
    return 0;
}
