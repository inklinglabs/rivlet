// RivletStub: the executable inside every app Rivlet generates.
//
// It does one thing: find the installed Rivlet.app, load
// RivletRuntime.framework out of it, and hand control to the runtime's
// single entry point. Keep this file small and its behaviour stable; a stub
// built for Rivlet 1.0 must keep working with every later runtime.

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

typedef int (*RivletMainFn)(int argc, char **argv);

static const char *kMakerBundleID = "com.inklinglabs.rivlet";
static const char *kRuntimeRelativePath =
    "/Contents/Frameworks/RivletRuntime.framework/RivletRuntime";
static const char *kReleasesURL =
    "https://github.com/inklinglabs/rivlet/releases/latest";

// Returns the runtime's exit status, or -1 if nothing could be loaded at path.
static int try_runtime(const char *path, int argc, char **argv) {
    struct stat st;
    if (stat(path, &st) != 0) {
        return -1;
    }
    void *handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        fprintf(stderr, "RivletStub: could not load %s: %s\n", path, dlerror());
        return -1;
    }
    RivletMainFn entry = (RivletMainFn)dlsym(handle, "RivletRuntimeMain");
    if (entry == NULL) {
        fprintf(stderr, "RivletStub: %s has no RivletRuntimeMain\n", path);
        return -1;
    }
    return entry(argc, argv);
}

static int try_app_bundle(const char *appPath, int argc, char **argv) {
    char path[PATH_MAX];
    if (snprintf(path, sizeof path, "%s%s", appPath, kRuntimeRelativePath) >= (int)sizeof path) {
        return -1;
    }
    return try_runtime(path, argc, argv);
}

static void show_missing_runtime_alert(void) {
    CFOptionFlags response = 0;
    CFUserNotificationDisplayAlert(
        0, kCFUserNotificationStopAlertLevel, NULL, NULL, NULL,
        CFSTR("This app needs Rivlet"),
        CFSTR("Rivlet provides the engine this app runs on, and it could not "
              "be found on this Mac. Download Rivlet, move it to your "
              "Applications folder, and open this app again."),
        CFSTR("Download Rivlet"), CFSTR("Quit"), NULL, &response);
    if (response == kCFUserNotificationDefaultResponse) {
        CFStringRef s = CFStringCreateWithCString(NULL, kReleasesURL, kCFStringEncodingUTF8);
        CFURLRef url = CFURLCreateWithString(NULL, s, NULL);
        if (url != NULL) {
            LSOpenCFURLRef(url, NULL);
            CFRelease(url);
        }
        CFRelease(s);
    }
}

int main(int argc, char **argv) {
    int status;

    // 1. Explicit override, used while developing the runtime.
    const char *override = getenv("RIVLET_RUNTIME");
    if (override != NULL && override[0] != '\0') {
        status = try_runtime(override, argc, argv);
        if (status >= 0) {
            return status;
        }
    }

    // 2. Wherever LaunchServices says Rivlet.app lives.
    CFStringRef bundleID = CFStringCreateWithCString(NULL, kMakerBundleID, kCFStringEncodingUTF8);
    CFArrayRef urls = LSCopyApplicationURLsForBundleIdentifier(bundleID, NULL);
    CFRelease(bundleID);
    if (urls != NULL) {
        CFIndex count = CFArrayGetCount(urls);
        for (CFIndex i = 0; i < count; i++) {
            CFURLRef url = CFArrayGetValueAtIndex(urls, i);
            char appPath[PATH_MAX];
            if (CFURLGetFileSystemRepresentation(url, true, (UInt8 *)appPath, sizeof appPath)) {
                status = try_app_bundle(appPath, argc, argv);
                if (status >= 0) {
                    CFRelease(urls);
                    return status;
                }
            }
        }
        CFRelease(urls);
    }

    // 3. The usual places, in case LaunchServices has not seen Rivlet yet.
    const char *home = getenv("HOME");
    char userApps[PATH_MAX];
    if (home != NULL) {
        snprintf(userApps, sizeof userApps, "%s/Applications/Rivlet.app", home);
        status = try_app_bundle(userApps, argc, argv);
        if (status >= 0) {
            return status;
        }
    }
    status = try_app_bundle("/Applications/Rivlet.app", argc, argv);
    if (status >= 0) {
        return status;
    }

    show_missing_runtime_alert();
    return 1;
}
