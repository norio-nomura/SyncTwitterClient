//
//  STCPluginForTwitterMac.m
//  SyncTwitterClient
//

#import <objc/runtime.h>

#import "SyncTwitterClient.h"
#import "STCPluginForTwitterMac.h"
#import "TwitterMacProtocols.h"

/*!
 *  declare for [super scrollViewDidScroll:tableView fromDevice:arg2];
 */
@interface STCPluginForTwitterMac_ABUIScrollViewDelegate : NSObject
- (void)scrollViewDidScroll:(id)arg1 fromDevice:(int)arg2;
@end
@implementation STCPluginForTwitterMac_ABUIScrollViewDelegate
- (void)scrollViewDidEndScrollingAnimation:(id)arg1;
{
    
}
- (void)scrollViewDidScroll:(id)arg1 fromDevice:(int)arg2;
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

- (void)TMHomeStreamViewController_scrollViewDidEndScrollingAnimation:(id<TMStreamTableView>)tableView;
{
    [super scrollViewDidEndScrollingAnimation:tableView];
    
    static NSString *userID = nil;
    static NSString *statusID = nil;

    // userID
    id<TMStatusStreamViewController>vc = (id<TMStatusStreamViewController>)self;
    NSString *currentUserID = [[[[vc statusStream]account]user]userID];
    if (![userID isEqualToString:currentUserID]) {
        userID = [currentUserID copy];
        statusID = nil;
    }

    // From top of the view, find first cell and second cell.
    // The array which is returned by `-[TMStreamTableView visibleCells]` is not sorted.
    CGRect boundsOfTableView = [tableView bounds];
    CGFloat topOfTableView = boundsOfTableView.origin.y + boundsOfTableView.size.height;
    NSArray *visibleCells = [tableView visibleCells];
    id<TMStatusCell> firstCell = nil;
    id<TMStatusCell> secondCell = nil;
    for (id<TMStatusCell> cell in visibleCells) {
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
    
    // Notify if statusID has changed.
    if (![statusID isEqualToString:topStatusID]) {
        statusID = [topStatusID copy];
        if (statusID) {
            [SyncTwitterClient sendUpdateTimeline:[userID stringByAppendingString:@".timeline"] position:statusID];
        }
    }
}

@end

@interface STCPluginForTwitterMac ()

@property (nonatomic) SyncTwitterClient *client;

@end

@implementation STCPluginForTwitterMac

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
        // Add method to `TMHomeStreamViewController`
        Protocol *protocol = objc_getProtocol("ABUIScrollViewDelegate");
        if (protocol) {
            SEL targetSelector = @selector(scrollViewDidEndScrollingAnimation:);
            
            // Get description for types
            struct objc_method_description description = protocol_getMethodDescription(protocol, targetSelector, NO, YES);
            const char *types = description.types;
            
            //
            if (types) {
                Class impClass = [STCPluginForTwitterMac_TMStreamViewController class];
                // Add
                IMP imp = class_getMethodImplementation(impClass, @selector(TMHomeStreamViewController_scrollViewDidEndScrollingAnimation:));
                class_addMethod(objc_getClass("TMHomeStreamViewController"), targetSelector, imp, types);
                
                // TODO: Add support `TMActivityStreamViewController`
            }
        }
    }
    return self;
}

- (void)didReceiveUpdateTimeline:(NSString*)timeline position:(NSString*)statusID;
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
            BOOL (^predicate)(id obj, NSUInteger idx, BOOL *stop) = ^BOOL(id<TwitterStatus> obj, NSUInteger idx, BOOL *stop){
                if ([[obj statusID] isEqualToString:statusID]) {
                    *stop = YES;
                    return YES;
                }
                return NO;
            };
            NSArray *statuses = [[stream statuses]copy];
            NSUInteger index = [statuses indexOfObjectWithOptions:NSEnumerationConcurrent passingTest:predicate];
            
            // If nofitied statusID is in statuses, it needs scroll.
            if (index != NSNotFound) {
                [statusStreamVC selectObjectWithStreamPositionID:statusID];
                NSIndexPath *indexPath = [[statusStreamVC tableView]indexPathForSelectedRow];
                [[statusStreamVC tableView]scrollToRowAtIndexPath:indexPath atScrollPosition:1 animated:YES];
            } else {
                [statusStreamVC loadOlder:nil];
            }
        }
    }
}

@end
