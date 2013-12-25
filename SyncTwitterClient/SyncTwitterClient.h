//
//  SyncTwitterClient.h
//  SyncTwitterClient
//

#import <Foundation/Foundation.h>

@protocol SyncTwitterClientPlugin;
@interface SyncTwitterClient : NSObject
/*!
 *  Send update notification to other SyncTwitterClient
 *
 *  @param timeline which has been updated.
 *  @param statusID which should be displayed on top of timeline.
 */
+ (void)sendUpdateTimeline:(NSString*)timeline position:(NSString*)statusID;

@end

@protocol SyncTwitterClientPlugin <NSObject>

/*!
 *  singleton
 *
 *  @return instance
 */
+ (instancetype)plugin;

/*!
 *  On receiving notification from other SyncTwitterClient, SyncTwitterClient will call this method.
 *
 *  @param timeline which has been updated.
 *  @param statusID which should be displayed on top of timeline.
 */
- (void)didReceiveUpdateTimeline:(NSString*)timeline position:(NSString*)statusID;

@end
