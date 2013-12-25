//
//  STCPluginForTweetbotMac.m
//  SyncTwitterClient
//

#import <objc/runtime.h>
#import <objc/message.h>

#import "SyncTwitterClient.h"
#import "STCPluginForTweetbotMac.h"
#import "TweetbotMacProtocols.h"

static NSString *const STCPluginForTweetbotMacNotification = @"STCPluginForTweetbotMacNotification";

@implementation NSUbiquitousKeyValueStore (STCPluginForTweetbotMac)

- (void)STCPluginForTweetbotMac_setDictionary:(NSDictionary *)aDictionary forKey:(NSString *)aKey;
{
    [self STCPluginForTweetbotMac_setDictionary:aDictionary forKey:aKey];
    [[NSNotificationCenter defaultCenter]postNotificationName:STCPluginForTweetbotMacNotification
                                                       object:self
                                                     userInfo:@{NSUbiquitousKeyValueStoreChangedKeysKey:@[aKey]}];
}

@end

@implementation STCPluginForTweetbotMac

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
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
        [nc addObserver:self
               selector:@selector(receiveNSUbiquitousKeyValueStoreDidChangeExternallyNotification:)
                   name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                 object:store];
        [nc addObserver:self
               selector:@selector(receiveNSUbiquitousKeyValueStoreDidChangeExternallyNotification:)
                   name:STCPluginForTweetbotMacNotification
                 object:store];
        
        Class target = [NSUbiquitousKeyValueStore class];
        method_exchangeImplementations(class_getInstanceMethod(target, @selector(setDictionary:forKey:)),
                                       class_getInstanceMethod(target, @selector(STCPluginForTweetbotMac_setDictionary:forKey:)));

    }
    return self;
}

- (void)didReceiveUpdateTimeline:(NSString*)timeline position:(NSString*)statusID;
{
    NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];

    NSDictionary *dictionary = [store dictionaryForKey:timeline];
    if (dictionary) {
        NSDictionary *newDictionary = @{@"i": @([statusID integerValue]), @"l": dictionary[@"l"], @"op": @(0)};
        [store setDictionary:newDictionary forKey:timeline];
        [[NSNotificationCenter defaultCenter]postNotificationName:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                                                           object:store
                                                         userInfo:@{NSUbiquitousKeyValueStoreChangedKeysKey: @[timeline]}];
    }
}

#pragma mark - NSUbiquitousKeyValueStoreDidChangeExternallyNotification

- (void)receiveNSUbiquitousKeyValueStoreDidChangeExternallyNotification:(NSNotification *)note;
{
    
    NSUbiquitousKeyValueStore *store = note.object;
    for (NSString *key in note.userInfo[NSUbiquitousKeyValueStoreChangedKeysKey]) {
        if ([key hasSuffix:@"timeline"]) {
            NSDictionary *values = [store dictionaryForKey:key];
            NSNumber *position = values[@"i"];
            double op = [values[@"op"] doubleValue];
            
            // If op is offseted, should use next status as possition.
            if (op != 0) {
                Class class = objc_getClass("PTHTweetbotMainWindowController");
                id<PTHTweetbotMainWindowController> mainWindow = objc_msgSend(class,@selector(mainWindowController));
                id<PTHTweetbotCurrentUser> currentUser = [[mainWindow selectedAccount]currentUser];
                NSNumber *userID = [currentUser tidValue];
                NSString *userIDString = [NSString stringWithFormat:@"%@.",userID];
                
                // check timeline user is current user
                if ([key hasPrefix:userIDString]) {
                    id<PTHTweetbotHomeTimelineCursor> cursor = [currentUser homeTimelineCursor];
                    NSInteger index = [cursor indexOfTID:[position longLongValue]];
                    NSArray *statuses = cursor.items;
                    if (index != NSNotFound && index+1 <  statuses.count) {
                        id<PTHTweetbotStatus> status = statuses[index+1];
                        position = [status tidValue];
                    }
                }
            }
            if (position) {
                NSString *statusID = [NSString stringWithFormat:@"%@",position];
                [SyncTwitterClient sendUpdateTimeline:key position:statusID];
            }
        }
    }
}

@end
