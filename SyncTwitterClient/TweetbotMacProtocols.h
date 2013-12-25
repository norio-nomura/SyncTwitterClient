//
//  TweetbotMacProtocols.h
//  SyncTwitterClient
//

#import <Foundation/Foundation.h>

#pragma mark - Models

@protocol PTHTweetbotObject
/*!
 *  tid is id
 */
@property(nonatomic) long long tid;
/*!
 *  NSValue of tid
 */
@property(readonly, nonatomic) NSNumber *tidValue;
@end

@protocol PTHTweetbotStatus<PTHTweetbotObject>
@end

@protocol PTHTweetbotCursor
/*!
 *  index of item specified by tid
 *
 *  @param tid is id
 *
 *  @return index of item specified by tid
 */
- (NSInteger)indexOfTID:(long long)tid;

/*!
 *  array of PTHTweetbotStatus
 */
@property(readonly, nonatomic) NSArray *items;
@end

@protocol PTHTweetbotHomeTimelineCursor<PTHTweetbotCursor>
@end

@protocol PTHTweetbotUser<PTHTweetbotObject>
@end

@protocol PTHTweetbotCurrentUser<PTHTweetbotUser>
/*!
 *
 *  Declared as PTHTweetbotCursor, but PTHTweetbotHomeTimelineCursor instance is on runtime.
 */
@property(readonly, nonatomic) id<PTHTweetbotHomeTimelineCursor> homeTimelineCursor;
@end

@protocol PTHTweetbotAccount
/*!
 *  PTHTweetbotCurrentUser
 */
@property(retain, nonatomic) id<PTHTweetbotCurrentUser> currentUser;
@end

@protocol PTHTweetbotMainWindowController
/*!
 *  Singleton
 *
 *  @return PTHTweetbotMainWindowController
 */
+ (id<PTHTweetbotMainWindowController>)mainWindowController;
/*!
 *  PTHTweetbotAccount
 */
@property(readonly, nonatomic) id<PTHTweetbotAccount> selectedAccount;
@end
