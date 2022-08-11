//
//  Created by Jesse Squires.
//  https://www.jessesquires.com
//
//  GitHub
//  https://github.com/jessesquires/ios-watchdog
//
//  Copyright © 2022-present Jesse Squires
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WatchdogRunLoopObserverDelegate <NSObject>

/// Called any time the run loop stalls.
///
/// @param duration The number of seconds that elapsed in the run loop iteration.
- (void)runLoopDidStallWithDuration:(NSTimeInterval)duration;

@end

/// Observes a run loop to detect any stalling or blocking that occurs. This class is thread-safe.
@interface WatchdogRunLoopObserver : NSObject

@property (nonatomic, weak, nullable) id<WatchdogRunLoopObserverDelegate> delegate;

/// Initializes the receiver to watch the main run loop, using the default stalling threshold.
- (instancetype)init;

/// Initializes the receiver to detect when the specified run loop blocks for
/// more than `threshold` seconds.
- (instancetype)initWithRunLoop:(CFRunLoopRef)runLoop
              stallingThreshold:(NSTimeInterval)threshold NS_DESIGNATED_INITIALIZER;

/// Begins watching the receiver's run loop for stalling.
///
/// The receiver will automatically stop watching the run loop upon deallocation.
- (void)start;

/// Stops watching the receiver's run loop for stalling.
- (void)stop;

@end

NS_ASSUME_NONNULL_END
