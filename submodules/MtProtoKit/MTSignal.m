#import "MTSignal.h"

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTProtoKitDynamic.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTProtoKitMac.h>
#else
#   import <MTProtoKit/MTProtoKit.h>
#endif

#import <libkern/OSAtomic.h>

@interface MTSubscriberDisposable : NSObject <MTDisposable>
{
    MTSubscriber *_subscriber;
    id<MTDisposable> _disposable;
}

@end

@implementation MTSubscriberDisposable

- (instancetype)initWithSubscriber:(MTSubscriber *)subscriber disposable:(id<MTDisposable>)disposable
{
    self = [super init];
    if (self != nil)
    {
        _subscriber = subscriber;
        _disposable = disposable;
    }
    return self;
}

- (void)dispose
{
    [_subscriber _markTerminatedWithoutDisposal];
    [_disposable dispose];
}

@end

@interface MTSignal_ValueContainer : NSObject

@property (nonatomic, strong, readonly) id value;

@end

@implementation MTSignal_ValueContainer

- (instancetype)initWithValue:(id)value {
    self = [super init];
    if (self != nil) {
        _value = value;
    }
    return self;
}

@end

@interface MTSignalQueueState : NSObject <MTDisposable>
{
    OSSpinLock _lock;
    bool _executingSignal;
    bool _terminated;
    
    id<MTDisposable> _disposable;
    MTMetaDisposable *_currentDisposable;
    MTSubscriber *_subscriber;
    
    NSMutableArray *_queuedSignals;
    bool _queueMode;
}

@end

@implementation MTSignalQueueState

- (instancetype)initWithSubscriber:(MTSubscriber *)subscriber queueMode:(bool)queueMode
{
    self = [super init];
    if (self != nil)
    {
        _subscriber = subscriber;
        _currentDisposable = [[MTMetaDisposable alloc] init];
        _queuedSignals = queueMode ? [[NSMutableArray alloc] init] : nil;
        _queueMode = queueMode;
    }
    return self;
}

- (void)beginWithDisposable:(id<MTDisposable>)disposable
{
    _disposable = disposable;
}

- (void)enqueueSignal:(MTSignal *)signal
{
    bool startSignal = false;
    OSSpinLockLock(&_lock);
    if (_queueMode && _executingSignal)
    {
        [_queuedSignals addObject:signal];
    }
    else
    {
        _executingSignal = true;
        startSignal = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (startSignal)
    {
        __weak MTSignalQueueState *weakSelf = self;
        id<MTDisposable> disposable = [signal startWithNext:^(id next)
        {
            [_subscriber putNext:next];
        } error:^(id error)
        {
            [_subscriber putError:error];
        } completed:^
        {
            __strong MTSignalQueueState *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf headCompleted];
            }
        }];
        
        [_currentDisposable setDisposable:disposable];
    }
}

- (void)headCompleted
{
    MTSignal *nextSignal = nil;
    
    bool terminated = false;
    OSSpinLockLock(&_lock);
    _executingSignal = false;
    
    if (_queueMode)
    {
        if (_queuedSignals.count != 0)
        {
            nextSignal = _queuedSignals[0];
            [_queuedSignals removeObjectAtIndex:0];
            _executingSignal = true;
        }
        else
            terminated = _terminated;
    }
    else
        terminated = _terminated;
    OSSpinLockUnlock(&_lock);
    
    if (terminated)
        [_subscriber putCompletion];
    else if (nextSignal != nil)
    {
        __weak MTSignalQueueState *weakSelf = self;
        id<MTDisposable> disposable = [nextSignal startWithNext:^(id next)
        {
            [_subscriber putNext:next];
        } error:^(id error)
        {
            [_subscriber putError:error];
        } completed:^
        {
            __strong MTSignalQueueState *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf headCompleted];
            }
}];
        
        [_currentDisposable setDisposable:disposable];
    }
}

- (void)beginCompletion
{
    bool executingSignal = false;
    OSSpinLockLock(&_lock);
    executingSignal = _executingSignal;
    _terminated = true;
    OSSpinLockUnlock(&_lock);
    
    if (!executingSignal)
        [_subscriber putCompletion];
}

- (void)dispose
{
    [_currentDisposable dispose];
    [_disposable dispose];
}

@end

@implementation MTSignal

- (instancetype)initWithGenerator:(id<MTDisposable> (^)(MTSubscriber *))generator
{
    self = [super init];
    if (self != nil)
    {
        _generator = [generator copy];
    }
    return self;
}

- (id<MTDisposable>)startWithNext:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:error completed:completed];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<MTDisposable>)startWithNext:(void (^)(id next))next
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:nil completed:nil];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<MTDisposable>)startWithNext:(void (^)(id next))next completed:(void (^)())completed
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:nil completed:completed];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

+ (MTSignal *)single:(id)next
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        [subscriber putNext:next];
        [subscriber putCompletion];
        return nil;
    }];
}

+ (MTSignal *)fail:(id)error
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        [subscriber putError:error];
        return nil;
    }];
}

+ (MTSignal *)never
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (__unused MTSubscriber *subscriber)
    {
        return nil;
    }];
}

+ (MTSignal *)complete
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        [subscriber putCompletion];
        return nil;
    }];
}

- (MTSignal *)then:(MTSignal *)signal
{
    return [[MTSignal alloc] initWithGenerator:^(MTSubscriber *subscriber)
    {
        MTDisposableSet *compositeDisposable = [[MTDisposableSet alloc] init];
        
        MTMetaDisposable *currentDisposable = [[MTMetaDisposable alloc] init];
        [compositeDisposable add:currentDisposable];
        
        [currentDisposable setDisposable:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [compositeDisposable add:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        }]];
        
        return compositeDisposable;
    }];
}

- (MTSignal *)delay:(NSTimeInterval)seconds onQueue:(MTQueue *)queue
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
        
        MTTimer *timer = [[MTTimer alloc] initWithTimeout:seconds repeat:false completion:^
        {
            [disposable setDisposable:[self startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } queue:queue.nativeQueue];
        
        [timer start];
        
        [disposable setDisposable:[[MTBlockDisposable alloc] initWithBlock:^
        {
            [timer invalidate];
        }]];
        
        return disposable;
    }];
}

- (MTSignal *)timeout:(NSTimeInterval)seconds onQueue:(MTQueue *)queue orSignal:(MTSignal *)signal
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
        
        MTTimer *timer = [[MTTimer alloc] initWithTimeout:seconds repeat:false completion:^
        {
            [disposable setDisposable:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } queue:queue.nativeQueue];
        [timer start];
        
        [disposable setDisposable:[self startWithNext:^(id next)
        {
            [timer invalidate];
            [subscriber putNext:next];
        } error:^(id error)
        {
            [timer invalidate];
            [subscriber putError:error];
        } completed:^
        {
            [timer invalidate];
            [subscriber putCompletion];
        }]];
        
        return disposable;
    }];
}

- (MTSignal *)catch:(MTSignal *(^)(id error))f
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTDisposableSet *disposable = [[MTDisposableSet alloc] init];
        
        [disposable add:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            MTSignal *signal = f(error);
            [disposable add:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } completed:^
        {
            [subscriber putCompletion];
        }]];
        
        return disposable;
    }];
}

+ (MTSignal *)mergeSignals:(NSArray *)signals
{
    if (signals.count == 0)
        return [MTSignal complete];
    
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTDisposableSet *disposables = [[MTDisposableSet alloc] init];
        MTAtomic *completedStates = [[MTAtomic alloc] initWithValue:[[NSSet alloc] init]];
        
        NSInteger index = -1;
        NSUInteger count = signals.count;
        for (MTSignal *signal in signals)
        {
            index++;
            
            id<MTDisposable> disposable = [signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                NSSet *set = [completedStates modify:^id(NSSet *set)
                {
                    return [set setByAddingObject:@(index)];
                }];
                if (set.count == count)
                    [subscriber putCompletion];
            }];
            
            [disposables add:disposable];
        }
        
        return disposables;
    }];
};

static dispatch_block_t recursiveBlock(void (^block)(dispatch_block_t recurse))
{
    return ^
    {
        block(recursiveBlock(block));
    };
}

- (MTSignal *)restart
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTAtomic *shouldRestart = [[MTAtomic alloc] initWithValue:@true];
        
        MTMetaDisposable *currentDisposable = [[MTMetaDisposable alloc] init];
        
        void (^start)() = recursiveBlock(^(dispatch_block_t recurse)
        {
            NSNumber *currentShouldRestart = [shouldRestart with:^id(NSNumber *current)
            {
                return current;
            }];
            
            if ([currentShouldRestart boolValue])
            {
                id<MTDisposable> disposable = [self startWithNext:^(id next)
                {
                    [subscriber putNext:next];
                } error:^(id error)
                {
                    [subscriber putError:error];
                } completed:^
                {
                    recurse();
                }];
                [currentDisposable setDisposable:disposable];
            }
        });
        
        start();
        
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            [currentDisposable dispose];
            
            [shouldRestart modify:^id(__unused id current)
            {
                return @false;
            }];
        }];
    }];
}

- (MTSignal *)take:(NSUInteger)count
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTAtomic *counter = [[MTAtomic alloc] initWithValue:@(0)];
        return [self startWithNext:^(id next)
        {
            __block bool passthrough = false;
            __block bool complete = false;
            [counter modify:^id(NSNumber *currentCount)
            {
                NSUInteger updatedCount = [currentCount unsignedIntegerValue] + 1;
                if (updatedCount <= count)
                    passthrough = true;
                if (updatedCount == count)
                    complete = true;
                return @(updatedCount);
            }];
            
            if (passthrough)
                [subscriber putNext:next];
            if (complete)
                [subscriber putCompletion];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (MTSignal *)switchToLatest
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTSignalQueueState *state = [[MTSignalQueueState alloc] initWithSubscriber:subscriber queueMode:false];
        
        [state beginWithDisposable:[self startWithNext:^(id next)
        {
            [state enqueueSignal:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [state beginCompletion];
        }]];
        
        return state;
    }];
}

- (MTSignal *)map:(id (^)(id))f {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            [subscriber putNext:f(next)];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (MTSignal *)filter:(bool (^)(id))f
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            if (f(next))
                [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (MTSignal *)mapToSignal:(MTSignal *(^)(id))f
{
    return [[self map:f] switchToLatest];
}

- (MTSignal *)onDispose:(void (^)())f
{
    return [[MTSignal alloc] initWithGenerator:^(MTSubscriber *subscriber)
    {
        MTDisposableSet *compositeDisposable = [[MTDisposableSet alloc] init];
        
        [compositeDisposable add:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }]];
        
        [compositeDisposable add:[[MTBlockDisposable alloc] initWithBlock:^
        {
            f();
        }]];
        
        return compositeDisposable;
    }];
}

- (MTSignal *)deliverOn:(MTQueue *)queue
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            [queue dispatchOnQueue:^
            {
                [subscriber putNext:next];
            }];
        } error:^(id error)
        {
            [queue dispatchOnQueue:^
            {
                [subscriber putError:error];
            }];
        } completed:^
        {
            [queue dispatchOnQueue:^
            {
                [subscriber putCompletion];
            }];
        }];
    }];
}

- (MTSignal *)startOn:(MTQueue *)queue
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        __block bool isCancelled = false;
        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
        [disposable setDisposable:[[MTBlockDisposable alloc] initWithBlock:^
        {
            isCancelled = true;
        }]];
        
        [queue dispatchOnQueue:^
        {
            if (!isCancelled)
            {
                [disposable setDisposable:[self startWithNext:^(id next)
                {
                    [subscriber putNext:next];
                } error:^(id error)
                {
                    [subscriber putError:error];
                } completed:^
                {
                    [subscriber putCompletion];
                }]];
            }
        }];
        
        return disposable;
    }];
}

- (MTSignal *)takeLast
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTAtomic *last = [[MTAtomic alloc] initWithValue:nil];
        return [self startWithNext:^(id next)
        {
            [last swap:[[MTSignal_ValueContainer alloc] initWithValue:next]];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            MTSignal_ValueContainer *value = [last with:^id(id value) {
                return value;
            }];
            if (value != nil)
            {
                [subscriber putNext:value.value];
            }
            [subscriber putCompletion];
        }];
    }];
}

- (MTSignal *)reduceLeft:(id)value with:(id (^)(id, id))f
{
    return [[MTSignal alloc] initWithGenerator:^(MTSubscriber *subscriber)
    {
        __block id intermediateResult = value;
        
        return [self startWithNext:^(id next)
        {
            intermediateResult = f(intermediateResult, next);
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            if (intermediateResult != nil)
                [subscriber putNext:intermediateResult];
            [subscriber putCompletion];
        }];
    }];
}

@end

@interface MTPipeReplayState : NSObject

@property (nonatomic, readonly) bool hasReceivedValue;
@property (nonatomic, strong, readonly) id recentValue;

@end

@implementation MTPipeReplayState

- (instancetype)initWithReceivedValue:(bool)receivedValue recentValue:(id)recentValue
{
    self = [super init];
    if (self != nil)
    {
        _hasReceivedValue = receivedValue;
        _recentValue = recentValue;
    }
    return self;
}

@end

@implementation MTPipe

- (instancetype)init
{
    return [self initWithReplay:false];
}

- (instancetype)initWithReplay:(bool)replay
{
    self = [super init];
    if (self != nil)
    {
        MTAtomic *subscribers = [[MTAtomic alloc] initWithValue:[[MTBag alloc] init]];
        MTAtomic *replayState = replay ? [[MTAtomic alloc] initWithValue:[[MTPipeReplayState alloc] initWithReceivedValue:false recentValue:nil]] : nil;
        
        _signalProducer = [^MTSignal *
        {
            return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
            {
                __block NSUInteger index = 0;
                [subscribers with:^id(MTBag *bag)
                {
                    index = [bag addItem:[^(id next)
                    {
                        [subscriber putNext:next];
                    } copy]];
                    return nil;
                }];
                
                if (replay)
                {
                    [replayState with:^id(MTPipeReplayState *state)
                    {
                        if (state.hasReceivedValue)
                            [subscriber putNext:state.recentValue];
                        return nil;
                    }];
                }
                
                return [[MTBlockDisposable alloc] initWithBlock:^
                {
                    [subscribers with:^id(MTBag *bag)
                    {
                        [bag removeItem:index];
                        return nil;
                    }];
                }];
            }];
        } copy];
        
        _sink = [^(id next)
        {
            NSArray *items = [subscribers with:^id(MTBag *bag)
            {
                return [bag copyItems];
            }];
            
            for (void (^item)(id) in items)
            {
                item(next);
            }
            
            if (replay)
            {
                [replayState modify:^id(__unused MTPipeReplayState *state)
                {
                    return [[MTPipeReplayState alloc] initWithReceivedValue:true recentValue:next];
                }];
            }
        } copy];
    }
    return self;
}

@end
