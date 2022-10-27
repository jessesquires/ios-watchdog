//
//  Created by Jesse Squires.
//  https://www.jessesquires.com
//
//  GitHub
//  https://github.com/jessesquires/ios-watchdog
//
//  Copyright © 2022-present Jesse Squires
//

#import "WatchdogRunLoopObserver.h"
#include <mach/mach_time.h>

// The default number of seconds that must pass to consider a run loop stalled.
// Docs: https://developer.apple.com/documentation/xcode/addressing-watchdog-terminations
//
// Per the docs, the iOS watchdog will terminate apps after 5 seconds.
// Using 4 gives us a bit of wiggle room to log before termination happens.
static const NSTimeInterval DefaultStallingThreshold = 4;

@interface WatchdogRunLoopObserver ()

// The run loop to watch.
@property (nonatomic, assign, readonly) CFRunLoopRef runLoop;

// The observer used to watch the run loop.
@property (nonatomic, assign, readonly) CFRunLoopObserverRef observer;

// The number of seconds that must pass to consider the run loop stalled.
@property (nonatomic, assign, readonly) NSTimeInterval threshold;

// The mach_absolute_time() at which the current run loop iteration was started,
// or 0 if there is no current iteration in progress.
//
// This property is not thread-safe, and must only be accessed from the thread
// that the run loop is associated with.
@property (nonatomic, assign) uint64_t startTime;

@end

@implementation WatchdogRunLoopObserver

- (instancetype)init {
    return [self initWithRunLoop:CFRunLoopGetMain()
               stallingThreshold:DefaultStallingThreshold];
}

- (instancetype)initWithRunLoop:(CFRunLoopRef)runLoop
              stallingThreshold:(NSTimeInterval)threshold {
    NSParameterAssert(runLoop != NULL);
    NSParameterAssert(threshold > 0);

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _runLoop = (CFRunLoopRef)CFRetain(runLoop);
    _threshold = threshold;

    // Pre-calculate timebase information.
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);

    NSTimeInterval secondsPerMachTime = timebase.numer / timebase.denom / 1e9;

    __weak typeof(self) weakSelf = self;

    // Observe at an extremely low order so that we can catch stalling even in
    // high-priority operations (like UI redrawing or animation).
    _observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopAllActivities, YES, INT_MIN,
                                                   ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        switch (activity) {
                // What we consider one "iteration" might start with any one of these events.
            case kCFRunLoopEntry:
            case kCFRunLoopBeforeTimers:
            case kCFRunLoopAfterWaiting:
            case kCFRunLoopBeforeSources:
                if (strongSelf.startTime == 0) {
                    strongSelf.startTime = mach_absolute_time();
                }
                break;

            case kCFRunLoopBeforeWaiting:
            case kCFRunLoopExit: {
                uint64_t endTime = mach_absolute_time();
                if (strongSelf.startTime <= 0) {
                    break;
                }

                uint64_t elapsed = endTime - strongSelf.startTime;

                NSTimeInterval duration = elapsed * secondsPerMachTime;
                if (duration > strongSelf.threshold) {
                    [strongSelf iterationStalledWithDuration:duration];
                }

                strongSelf.startTime = 0;
                break;
            }

            default:
                NSAssert(NO, @"WatchdogRunLoopObserver should not have been triggered for activity %i", (int)activity);
        }
    });

    if (_observer == NULL) {
        return nil;
    }

    return self;
}

- (void)dealloc {
    if (_observer != NULL) {
        CFRunLoopObserverInvalidate(_observer);

        CFRelease(_observer);
        _observer = NULL;
    }

    if (_runLoop != NULL) {
        CFRelease(_runLoop);
        _runLoop = NULL;
    }
}

- (void)start {
    CFRunLoopAddObserver(self.runLoop, self.observer, kCFRunLoopCommonModes);
}

- (void)stop {
    self.startTime = 0;
    CFRunLoopRemoveObserver(self.runLoop, self.observer, kCFRunLoopCommonModes);
}

- (void)iterationStalledWithDuration:(NSTimeInterval)duration {
    [self.delegate runLoopDidStallWithDuration:duration];
}

@end
