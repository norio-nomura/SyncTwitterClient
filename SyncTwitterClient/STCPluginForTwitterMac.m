//
//  STCPluginForTwitterMac.m
//  SyncTwitterClient
//

#import <objc/runtime.h>

#import "SyncTwitterClient.h"
#import "STCPluginForTwitterMac.h"
#import "TwitterMacProtocols.h"

@interface STCPluginForTwitterMac (STCPluginForTwitterMac_TMStreamViewController)
- (void)scrollViewDidScroll:(id<TMStatusStreamViewController>)vc;
- (void)statusStreamDidUpdate:(id<TMStatusStreamViewController>)vc;
@end

/*!
 *  declare for [super scrollViewDidScroll:tableView fromDevice:arg2];
 */
@interface STCPluginForTwitterMac_ABUIScrollViewDelegate : NSObject
@end
@implementation STCPluginForTwitterMac_ABUIScrollViewDelegate
- (void)scrollViewDidEndScrollingAnimation:(id<ABUIScrollView>)scrollView;
{
    // Dummy
}
- (void)scrollViewDidEndDragging:(id<ABUIScrollView>)scrollView;
{
    // Dummy
}
- (void)scrollViewDidScroll:(id<ABUIScrollView>)scrollView fromDevice:(int)arg2;
{
    // Dummy
}
@end

/*!
 *  method implementation for `TMHomeStreamViewController` and `TMActivityStreamViewController`
 */
@interface STCPluginForTwitterMac_TMStreamViewController : STCPluginForTwitterMac_ABUIScrollViewDelegate
@end

@implementation STCPluginForTwitterMac_TMStreamViewController

- (void)scrollViewDidEndScrollingAnimation:(id<ABUIScrollView>)scrollView;
{
    [super scrollViewDidEndScrollingAnimation:scrollView];
    [[STCPluginForTwitterMac plugin]scrollViewDidScroll:(id<TMStatusStreamViewController>)self];
}

- (void)scrollViewDidEndDragging:(id<ABUIScrollView>)scrollView;
{
    [super scrollViewDidEndDragging:scrollView];
    [[STCPluginForTwitterMac plugin]scrollViewDidScroll:(id<TMStatusStreamViewController>)self];
}

- (void)scrollViewDidScroll:(id<ABUIScrollView>)scrollView fromDevice:(int)arg2;
{
    [super scrollViewDidScroll:scrollView fromDevice:arg2];
    CGRect modelBounds = ((CALayer*)[scrollView.layer modelLayer]).bounds;
    CGRect presentationBounds = ((CALayer*)[scrollView.layer presentationLayer]).bounds;
    // Prevent call while scrolling by animation.
    if (CGRectEqualToRect(modelBounds, presentationBounds)) {
        [[STCPluginForTwitterMac plugin]scrollViewDidScroll:(id<TMStatusStreamViewController>)self];
    }
}

+ (BOOL)addMethod:(SEL)sel inProtocol:(Protocol*)protocol toClass:(Class)targetClass;
{
    BOOL result = NO;
    if (sel && protocol && targetClass) {
        // Get description for types
        struct objc_method_description description = protocol_getMethodDescription(protocol, sel, NO, YES);
        const char *types = description.types;
        if (types) {
            IMP imp = class_getMethodImplementation([self class], sel);
            result = class_addMethod(targetClass, sel, imp, types);
        }
    }
    return result;
}

@end

@implementation NSObject (STCPluginForTwitterMac_TMStatusStreamViewController)

- (void)STCPluginForTwitterMac_streamDidUpdate:(NSNotification*)note;
{
    [self STCPluginForTwitterMac_streamDidUpdate:note];
    if ([[(id<TMStatusStreamViewController>)self statusStream]isEqual:note.object]) {
        [[STCPluginForTwitterMac plugin]statusStreamDidUpdate:(id<TMStatusStreamViewController>)self];
    }
}

@end

@implementation STCPluginForTwitterMac {
    BOOL _isSyncingWithTweetbot;
    NSMutableDictionary *_timelineIsScrollingToStatusID;
}

/**
 * @return the single static instance of the plugin object
 */
+ (instancetype)plugin
{
    static dispatch_once_t onceToken;
    static id plugin = nil;
    
    dispatch_once(&onceToken, ^{
        plugin = [[self alloc] init];
    });
    
    return plugin;
}

- (instancetype)init;
{
    self = [super init];
    if (self) {
        _isSyncingWithTweetbot = NO;
        _timelineIsScrollingToStatusID = [NSMutableDictionary dictionary];

        Class TMHomeStreamViewControllerClass =  objc_getClass("TMHomeStreamViewController");
        Protocol *ABUIScrollViewDelegateProtocol = objc_getProtocol("ABUIScrollViewDelegate");
        [STCPluginForTwitterMac_TMStreamViewController addMethod:@selector(scrollViewDidEndScrollingAnimation:)
                                                      inProtocol:ABUIScrollViewDelegateProtocol
                                                         toClass:TMHomeStreamViewControllerClass];
        [STCPluginForTwitterMac_TMStreamViewController addMethod:@selector(scrollViewDidEndDragging:)
                                                      inProtocol:ABUIScrollViewDelegateProtocol
                                                         toClass:TMHomeStreamViewControllerClass];
        [STCPluginForTwitterMac_TMStreamViewController addMethod:@selector(scrollViewDidScroll:fromDevice:)
                                                      inProtocol:ABUIScrollViewDelegateProtocol
                                                         toClass:TMHomeStreamViewControllerClass];
        
        Class target = objc_getClass("TMStatusStreamViewController");
        method_exchangeImplementations(class_getInstanceMethod(target, @selector(streamDidUpdate:)),
                                       class_getInstanceMethod(target, @selector(STCPluginForTwitterMac_streamDidUpdate:)));
    }
    return self;
}

- (void)didReceiveUpdateTimeline:(NSString*)timeline position:(NSString*)positionID latest:(NSString *)latestID;
{
    id<Tweetie2AppDelegate> delegate = [NSApp delegate];
    id<TMStreamViewController> vc = [[[delegate rootViewController]columnViewController]topViewController];
    NSString *className = NSStringFromClass(object_getClass(vc));
    
    // If current view controller is Home Timeline, it needs scroll
    if ([timeline hasSuffix:@"timeline"] && [className isEqualToString:@"TMHomeStreamViewController"]) {
        id<TMStatusStreamViewController> statusStreamVC = (id<TMStatusStreamViewController>)vc;
        id<TwitterAccountStream> stream = [statusStreamVC statusStream];
        NSString *userID = [[[stream account]user]userID];
        
        // If current userID is notified userID, it needs scroll.
        if ([timeline hasPrefix:userID]) {
            
            NSString *newestStatusID = [stream newestStatusID];
            // newestStatusID <= latestID
            if ([newestStatusID compare:latestID] != NSOrderedDescending) {
                BOOL (^predicate)(id obj, NSUInteger idx, BOOL *stop) = ^BOOL(id<TwitterStatus> obj, NSUInteger idx, BOOL *stop){
                    if ([[obj statusID] isEqualToString:positionID]) {
                        *stop = YES;
                        return YES;
                    }
                    return NO;
                };
                NSArray *statuses = [[stream statuses]copy];
                NSUInteger index = [statuses indexOfObjectWithOptions:NSEnumerationConcurrent passingTest:predicate];
                
                // If nofitied statusID is in statuses, it needs scroll.
                if (index != NSNotFound) {
                    [statusStreamVC selectObjectWithStreamPositionID:positionID];
                    NSIndexPath *indexPath = [[statusStreamVC tableView]indexPathForSelectedRow];
                    [[statusStreamVC tableView]scrollToRowAtIndexPath:indexPath atScrollPosition:1 animated:YES];
                    _isSyncingWithTweetbot = YES;
                    _timelineIsScrollingToStatusID[timeline] = positionID;
                } else {
                    _isSyncingWithTweetbot = NO;
                    NSString *oldestStatusID = [stream oldestStatusID];
                    if ([positionID compare:newestStatusID] == NSOrderedDescending) {
                        if (![statusStreamVC isLoadingNewer]) {
                            [statusStreamVC loadNewer:nil];
                        }
                    } else if ([positionID compare:oldestStatusID] == NSOrderedAscending) {
                        [statusStreamVC loadOlder:nil];
                    } else {
                        // Is position in GAP?
                    }
                }
            }
        }
    }
}

- (void)scrollViewDidScroll:(id<TMStatusStreamViewController>)vc;
{
    static NSString *userID = nil;
    static NSString *positionID = nil;
    
    // userID
    id<TwitterAccountStream>stream = [vc statusStream];
    NSString *currentUserID = [[[stream account]user]userID];
    if (![userID isEqualToString:currentUserID]) {
        userID = [currentUserID copy];
        positionID = nil;
    }
    
    // From top of the view, find first cell and second cell.
    // The array which is returned by `-[TMStreamTableView visibleCells]` is not sorted.
    id<TMStreamTableView> tableView = [vc tableView];
    CGRect boundsOfTableView = [tableView bounds];
    CGFloat topOfTableView = boundsOfTableView.origin.y + boundsOfTableView.size.height;
    NSArray *visibleCells = [tableView visibleCells];
    id<TMStatusCell> firstCell = nil;
    id<TMStatusCell> secondCell = nil;
    Class TMStatusCellClass = objc_getClass("TMStatusCell");
    for (id<TMStatusCell> cell in visibleCells) {
        if (![cell isKindOfClass:TMStatusCellClass]) {
            continue;
        }
        NSString *statusID = [[cell status]statusID];
        if (firstCell) {
            if ([statusID compare:[[firstCell status]statusID]] == NSOrderedDescending) {
                secondCell = firstCell;
                firstCell = cell;
            } else if (!secondCell || [statusID compare:[[secondCell status]statusID]] == NSOrderedDescending) {
                secondCell = cell;
            }
        } else {
            firstCell = cell;
        }
    }
    
    // If first cell is sticking out of the view, use second cell as top cell.
    if (firstCell && secondCell) {
        CGRect frameOfCell = [firstCell frame];
        CGFloat topOfCell = frameOfCell.origin.y + frameOfCell.size.height;
        if (topOfTableView < topOfCell) {
            if (visibleCells.count>1) {
                firstCell = secondCell;
            }
        }
    }
    
    // statusID
    NSString *topStatusID = [[firstCell status]statusID];
    
    NSString *timeline = [userID stringByAppendingString:@".timeline"];
    NSString *scrollingToStatusID = _timelineIsScrollingToStatusID[timeline];
    // Check if scrolling is caused by syncing.
    if (scrollingToStatusID) {
        // If scrollingToStatusID is topStatusID, scrolling by syncing ends.
        if ([topStatusID isEqualToString:scrollingToStatusID]) {
            [_timelineIsScrollingToStatusID removeObjectForKey:timeline];
        }
    } else {
        // Notify if statusID has changed.
        if (![positionID isEqualToString:topStatusID]) {
            positionID = [topStatusID copy];
            if (_isSyncingWithTweetbot && positionID) {
                NSString *latestID = [stream newestStatusID];
                [SyncTwitterClient sendUpdateTimeline:timeline position:positionID latest:latestID];
            }
        }
    }
}

- (void)statusStreamDidUpdate:(id<TMStatusStreamViewController>)vc;
{
    NSString *className = NSStringFromClass(object_getClass(vc));
   
    // If view controller is Home Timeline, it needs check
    if ([className isEqualToString:@"TMHomeStreamViewController"]) {
        
        if (!_isSyncingWithTweetbot) {
            id<TwitterAccountStream> stream = [vc statusStream];
            NSString *userID = [[[stream account]user]userID];
            NSString *timeline = [userID stringByAppendingString:@".timeline"];
            NSString *lastReceivedPositionID = [SyncTwitterClient lastReceivedPositionForTimeline:timeline];
            if (lastReceivedPositionID) {
                NSString *newestStatusID = [stream newestStatusID];
                // lastReceivedPositionID <= newestStatusID
                if ([newestStatusID compare:lastReceivedPositionID] != NSOrderedDescending) {
                    BOOL (^predicate)(id obj, NSUInteger idx, BOOL *stop) = ^BOOL(id<TwitterStatus> obj, NSUInteger idx, BOOL *stop){
                        if ([[obj statusID] isEqualToString:lastReceivedPositionID]) {
                            *stop = YES;
                            return YES;
                        }
                        return NO;
                    };
                    NSArray *statuses = [[stream statuses]copy];
                    NSUInteger index = [statuses indexOfObjectWithOptions:NSEnumerationConcurrent passingTest:predicate];
                    
                    // If last received positionID is in statuses, it needs scroll.
                    if (index != NSNotFound) {
                        [vc selectObjectWithStreamPositionID:lastReceivedPositionID];
                        NSIndexPath *indexPath = [[vc tableView]indexPathForSelectedRow];
                        [[vc tableView]scrollToRowAtIndexPath:indexPath atScrollPosition:1 animated:YES];
                        _isSyncingWithTweetbot = YES;
                        _timelineIsScrollingToStatusID[timeline] = lastReceivedPositionID;
                    }
                }
            }
        }
    }

}

@end
