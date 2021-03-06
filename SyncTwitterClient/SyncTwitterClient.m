//
//  SyncTwitterClient.m
//  SyncTwitterClient
//

#import "SyncTwitterClient.h"
#import "STCPluginForTweetbotMac.h"
#import "STCPluginForTwitterMac.h"

static NSString *const SyncTwitterClientUpdateTimelinePositionNotification = @"SyncTwitterClientUpdateTimelinePosition";

@interface SyncTwitterClient()

@property (nonatomic) id<SyncTwitterClientPlugin>plugin;
/*!
 *  a dictionary contains @{timeline: statusID}
 */
@property (nonatomic) NSMutableDictionary *lastReceivedStatusIDs;

@end

@implementation SyncTwitterClient

/**
 * A special method called by SIMBL once the application has started and all classes are initialized.
 */
+ (void) load
{
    SyncTwitterClient* plugin = [SyncTwitterClient client];
    // ... do whatever
    if (plugin) {
    }
}

/**
 * @return the single static instance of the plugin object
 */
+ (instancetype) client
{
    static dispatch_once_t onceToken;
    static SyncTwitterClient* plugin = nil;
    
    dispatch_once(&onceToken, ^{
        plugin = [[SyncTwitterClient alloc] init];
    });
    
    return plugin;
}

- (id)init
{
    self = [super init];
    if (self) {
        _lastReceivedStatusIDs = [NSMutableDictionary dictionary];
        NSRunningApplication *app = [NSRunningApplication currentApplication];
        if ([app.bundleIdentifier isEqualToString:@"com.tapbots.TweetbotMac"]) {
            _plugin = [STCPluginForTweetbotMac plugin];
        } else if ([app.bundleIdentifier isEqualToString:@"com.twitter.twitter-mac"]) {
            _plugin = [STCPluginForTwitterMac plugin];
        }
        if (_plugin) {
            [[NSDistributedNotificationCenter defaultCenter]addObserver:self
                                                               selector:@selector(receiveUpdateTimelinePosition:)
                                                                   name:SyncTwitterClientUpdateTimelinePositionNotification
                                                                 object:nil];
        }
    }
    return self;
}

#pragma mark - SyncTwitterClientUpdateTimelinePositionNotification

- (void)receiveUpdateTimelinePosition:(NSNotification*)notification
{
    NSRunningApplication *app = [NSRunningApplication currentApplication];
    /*!
     *  notification.object is NSString which contains "#bundleIdentifier#,#userID#.(timeline|mentions),#positionID#,#latestID#"
     *  notification will be ignored if object has prefix app.bundleIdentifier
     */
    NSString *object = notification.object;
    if (![object hasPrefix:app.bundleIdentifier]) {
        NSArray *component = [object componentsSeparatedByString:@","];
        NSString *timeline = component[1];
        NSString *positionID = component[2];
        NSString *latestID = component[3];
        
        // Prevent sending same notification
        if (![_lastReceivedStatusIDs[timeline] isEqualToString:positionID]) {
            _lastReceivedStatusIDs[timeline] = positionID;
            [_plugin didReceiveUpdateTimeline:timeline position:positionID latest:latestID];
        }
    }
}

#pragma mark - Public Method

+ (void)sendUpdateTimeline:(NSString*)timeline position:(NSString*)positionID latest:(NSString*)latestID;
{
    [[SyncTwitterClient client]sendUpdateTimeline:timeline position:positionID latest:latestID];
}

- (void)sendUpdateTimeline:(NSString*)timeline position:(NSString*)positionID latest:(NSString *)latestID;
{
    // Prevent sending same notification
    if (![_lastReceivedStatusIDs[timeline] isEqualToString:positionID]) {
        _lastReceivedStatusIDs[timeline] = positionID;
        NSRunningApplication *app = [NSRunningApplication currentApplication];
        NSString *object = [NSString stringWithFormat:@"%@,%@,%@,%@", app.bundleIdentifier, timeline, positionID, latestID];
        [[NSDistributedNotificationCenter defaultCenter]postNotificationName:SyncTwitterClientUpdateTimelinePositionNotification
                                                                      object:object
                                                                    userInfo:Nil
                                                          deliverImmediately:YES];
    }
}

+ (NSString*)lastReceivedPositionForTimeline:(NSString*)timeline;
{
    return [[SyncTwitterClient client]lastReceivedPositionForTimeline:timeline];
}

- (NSString*)lastReceivedPositionForTimeline:(NSString*)timeline;
{
    return _lastReceivedStatusIDs[timeline];
}

@end
