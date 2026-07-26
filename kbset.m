// kbset — set keyboard backlight to a level and leave it there.
// Usage: kbset <0.0-1.0>        sets level, disables auto-brightness
//        kbset auto             restore auto-brightness control
// Build: clang -O2 -fobjc-arc -o kbset kbset.m -framework Foundation
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/message.h>

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: kbset <0.0-1.0>|auto\n"); return 2; }
    dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY);
    id client = [[NSClassFromString(@"KeyboardBrightnessClient") alloc] init];
    NSArray *ids = ((NSArray *(*)(id, SEL))objc_msgSend)(client, NSSelectorFromString(@"copyKeyboardBacklightIDs"));
    unsigned long long kid = [ids.firstObject unsignedLongLongValue];
    BOOL (*setB)(id, SEL, float, unsigned long long) = (void *)objc_msgSend;
    BOOL (*setAuto)(id, SEL, BOOL, unsigned long long) = (void *)objc_msgSend;
    BOOL (*suspendDim)(id, SEL, BOOL, unsigned long long) = (void *)objc_msgSend;
    float (*getF)(id, SEL, unsigned long long) = (void *)objc_msgSend;
    SEL autoSel = NSSelectorFromString(@"enableAutoBrightness:forKeyboard:");
    SEL dimSel = NSSelectorFromString(@"suspendIdleDimming:forKeyboard:");
    SEL setSel = NSSelectorFromString(@"setBrightness:forKeyboard:");

    if (!strcmp(argv[1], "auto")) {
        suspendDim(client, dimSel, NO, kid);
        setAuto(client, autoSel, YES, kid);
        printf("auto-brightness restored\n");
        return 0;
    }
    if (!strcmp(argv[1], "release")) {
        // un-suspend idle dimming but keep manual (non-ALS) control
        suspendDim(client, dimSel, NO, kid);
        printf("idle dimming released, auto-brightness left off\n");
        return 0;
    }
    float v = atof(argv[1]);
    setAuto(client, autoSel, NO, kid);
    suspendDim(client, dimSel, YES, kid);
    setB(client, setSel, v, kid);
    usleep(300000);
    printf("set %.2f -> brightness=%.3f backlightLevel=%.3f\n", v,
           getF(client, NSSelectorFromString(@"brightnessForKeyboard:"), kid),
           getF(client, NSSelectorFromString(@"backlightLevelForKeyboard:"), kid));
    return 0;
}
