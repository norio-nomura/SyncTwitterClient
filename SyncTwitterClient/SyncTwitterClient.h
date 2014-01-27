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
 *  @param timeline   "#userID#.(timeline|mention)" indicates timeline which has been updated.
 *  @param positionID is StatusID which should be displayed on top of timeline view.
 *  @param latestID   is sender's latest StatusID on timeline.
 */
+ (void)sendUpdateTimeline:(NSString*)timeline position:(NSString*)positionID latest:(NSString*)latestID;

/*!
 *  Last received positionID for timeline
 *
 *  @param timeline "#userID#.(timeline|mention)" indicates timeline which has been updated.
 *
 *  @return positionID If client did not receive any positionID for timeline, nil may be returned.
 */
+ (NSString*)lastReceivedPositionForTimeline:(NSString*)timeline;

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
 *  @param timeline   "#userID#.(timeline|mention)" indicates timeline which has been updated.
 *  @param positionID is StatusID which should be displayed on top of timeline view.
 *  @param latestID   is sender's latest StatusID on timeline.
 */
- (void)didReceiveUpdateTimeline:(NSString*)timeline position:(NSString*)positionID latest:(NSString*)latestID;

@end
