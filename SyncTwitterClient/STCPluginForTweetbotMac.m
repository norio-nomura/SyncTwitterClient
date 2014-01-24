//
//  STCPluginForTweetbotMac.m
//  SyncTwitterClient
//

#import <objc/runtime.h>
#import <objc/message.h>

#import "SyncTwitterClient.h"
#import "STCPluginForTweetbotMac.h"
#import "TweetbotMacProtocols.h"

@interface STCPluginForTweetbotMac()
+ (void)sendUpdateValues:(NSDictionary*)values forKey:(NSString*)aKey;
@end

@implementation NSUbiquitousKeyValueStore (STCPluginForTweetbotMac)

- (void)STCPluginForTweetbotMac_setDictionary:(NSDictionary *)aDictionary forKey:(NSString *)aKey;
{
    [self STCPluginForTweetbotMac_setDictionary:aDictionary forKey:aKey];
    [STCPluginForTweetbotMac sendUpdateValues:aDictionary forKey:aKey];
}

- (NSDictionary *)STCPluginForTweetbotMac_dictionaryForKey:(NSString *)aKey
{
    NSDictionary *values = [self STCPluginForTweetbotMac_dictionaryForKey:aKey];
    [STCPluginForTweetbotMac sendUpdateValues:values forKey:aKey];
    return values;
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
        Class target = [NSUbiquitousKeyValueStore class];
        method_exchangeImplementations(class_getInstanceMethod(target, @selector(setDictionary:forKey:)),
                                       class_getInstanceMethod(target, @selector(STCPluginForTweetbotMac_setDictionary:forKey:)));
        method_exchangeImplementations(class_getInstanceMethod(target, @selector(dictionaryForKey:)),
                                       class_getInstanceMethod(target, @selector(STCPluginForTweetbotMac_dictionaryForKey:)));

    }
    return self;
}

- (void)didReceiveUpdateTimeline:(NSString*)timeline position:(NSString*)positionID latest:(NSString *)latestID;
{
    NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];

    NSDictionary *dictionary = [store dictionaryRepresentation][timeline];
    // Is tracking timeline?
    if (dictionary) {
        NSDictionary *newDictionary = @{@"i": @([positionID integerValue]), @"l": dictionary[@"l"], @"op": @(0)};
        [store setDictionary:newDictionary forKey:timeline];
        // post fake notification
        [[NSNotificationCenter defaultCenter]postNotificationName:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                                                           object:store
                                                         userInfo:@{NSUbiquitousKeyValueStoreChangedKeysKey: @[timeline]}];
    }
}

+ (void)sendUpdateValues:(NSDictionary*)values forKey:(NSString*)aKey;
{
    [[STCPluginForTweetbotMac plugin]sendUpdateValues:values forKey:aKey];
}


- (void)sendUpdateValues:(NSDictionary*)values forKey:(NSString*)aKey;
{
    if ([aKey hasSuffix:@"timeline"]) {
        NSNumber *position = values[@"i"];
        double op = [values[@"op"] doubleValue];
        
        Class class = objc_getClass("PTHTweetbotMainWindowController");
        id<PTHTweetbotMainWindowController> mainWindow = objc_msgSend(class,@selector(mainWindowController));
        id<PTHTweetbotCurrentUser> currentUser = [[mainWindow selectedAccount]currentUser];
        NSNumber *userID = [currentUser tidValue];
        NSString *userIDString = [NSString stringWithFormat:@"%@.",userID];
        
        // check timeline user is current user
        if ([aKey hasPrefix:userIDString]) {
            id<PTHTweetbotHomeTimelineCursor> cursor = [currentUser homeTimelineCursor];
            NSArray *statuses = cursor.items;
            
            // latest
            id<PTHTweetbotStatus> latestStatus = [statuses firstObject];
            NSNumber *latest = [latestStatus tidValue];
            
            // If op is offseted, should use next status as possition.
            if (op != 0) {
                NSInteger index = [cursor indexOfTID:[position longLongValue]];
                if (index != NSNotFound && index+1 <  statuses.count) {
                    id<PTHTweetbotStatus> status = statuses[index+1];
                    position = [status tidValue];
                }
            }
            if (position && latest) {
                [SyncTwitterClient sendUpdateTimeline:aKey position:[position stringValue] latest:[latest stringValue]];
            }
        }
    }
}

@end
