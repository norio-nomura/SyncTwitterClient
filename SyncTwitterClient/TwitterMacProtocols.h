//
//  TwitterMacProtocols.h
//  SyncTwitterClient
//

#import <Foundation/Foundation.h>

#pragma mark - Models

@protocol TwitterUser
@property(copy, nonatomic) NSString *fullName;
@property(copy, nonatomic) NSString *username;
@property(copy, nonatomic) NSString *userID;
@end

@protocol TwitterAccount
@property(retain, nonatomic) id<TwitterUser> user;
@end

@protocol TwitterStatus
@property(copy, nonatomic) NSString *statusID;
@end

@protocol TwitterStream
/*!
 *  array of TwitterStatus
 */
@property(retain, nonatomic) NSArray *statuses;
@end

@protocol TwitterConcreteStatusesStream<TwitterStream>
/*!
 *  @return oldest status id string from loaded statuses
 */
- (id)oldestStatusID;
/*!
 *  @return newest status id string from loaded statuses
 */
- (id)newestStatusID;
@end

@protocol TwitterAccountStream<TwitterConcreteStatusesStream>
@property(nonatomic) id<TwitterAccount> account;
@end

#pragma mark - cloned classes of UIKit

/*!
 *  clone of UIView
 */
@protocol ABUIView
@property(nonatomic) CGRect bounds;
@property(nonatomic) CGRect frame;
@end

@protocol ABUIScrollViewDelegate;

/*!
 *  clone of UIScrollView
 */
@protocol ABUIScrollView<ABUIView>
/*!
 *  UIScrollView.contentOffset
 */
@property(nonatomic) CGPoint contentOffset;

@property(readonly, nonatomic) CALayer *layer;

@end

/*!
 *  clone of UITableView
 */
@protocol ABUITableView<ABUIScrollView>
/*!
 *  Returns an index path identifying the row and section of the selected row.
 *
 *  @return An index path identifying the row and section indexes of the selected row or nil if the index path is invalid.
 */
- (NSIndexPath*)indexPathForSelectedRow;
/*!
 *  -[UITableView selectRowAtIndexPath:animated:scrollPosition:]
 *
 *  @param indexPath      indexPath
 *  @param scrollPosition UITableViewScrollPosition
 *  @param animated       animated
 */
- (void)scrollToRowAtIndexPath:(NSIndexPath*)indexPath atScrollPosition:(int)scrollPosition animated:(BOOL)animated;
/*!
 *  -[UITableView visibleCells]
 *
 *  @return array of ABUITableViewCell
 */
- (NSArray*)visibleCells;

@end

@protocol ABUITableViewCell<ABUIView>
@property(readonly, nonatomic) id<ABUITableView> tableView;
@end

@protocol ABUIViewController
@end

#pragma mark - Views

@protocol TMCell<ABUITableViewCell,NSObject>
@end

@protocol TMStatusCell<TMCell>
@property(retain, nonatomic) id<TwitterStatus> status;
@end

@protocol TMStreamTableView<ABUITableView>
@end

#pragma mark - View Controllers

@protocol TMViewController<ABUIViewController>
@end

@protocol TMStreamViewController<TMViewController>
/*!
 *  Declared as ABUITableView, but TMStreamTableView instance is on runtime.
 */
@property(readonly, nonatomic) id<TMStreamTableView> tableView;
/*!
 *  select tableview's row which identified by statusID
 *
 *  @param statusID TwitterStatus.statusID
 */
- (void)selectObjectWithStreamPositionID:(id)statusID;
@end

@protocol TMStatusStreamViewController<TMStreamViewController>
@property(retain, nonatomic) id<TwitterAccountStream> statusStream;
/*!
 *  is loading newer status
 *
 *  @return YES if loading newer.
 */
- (BOOL)isLoadingNewer;

/*!
 *  trigger load newer statuses
 *
 *  @param arg1 unkown(nil)
 */
- (void)loadNewer:(id)arg1;

/*!
 *  trigger load older statuses
 *
 *  @param arg1 unkown(nil)
 */
- (void)loadOlder:(id)arg1;
@end

@protocol TMColumnViewController<ABUIViewController>
/*!
 *  Declared as ABUIViewController, but TMStatusStreamViewController instance is on runtime.
 */
@property(readonly, nonatomic) id<TMStreamViewController> topViewController;
@end

@protocol TMRootViewController<ABUIViewController>
@property(readonly, nonatomic) id<TMColumnViewController> columnViewController;
@end

@protocol Tweetie2AppDelegate
@property(readonly, nonatomic) id<TMRootViewController> rootViewController;
@end
