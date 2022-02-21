#include <CSyncHelpers.h>


void *makeEquatableEquivalenceDetector(void) {
    extern void _swift_sync_makeEquatableEquivalenceDetector(void);
    return &_swift_sync_makeEquatableEquivalenceDetector;
}
