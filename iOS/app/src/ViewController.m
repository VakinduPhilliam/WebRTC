/*
 * Copyright @ 2017-present Atlassian Pty Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Availability.h>
#import <CoreSpotlight/CoreSpotlight.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "Types.h"
#import "ViewController.h"

// Needed for NSUserActivity suggestedInvocationPhrase
@import Intents;

/**
 * The query to perform through JMAddPeopleController when the InviteButton is
 * tapped in order to exercise the public API of the feature invite. If nil, the
 * InviteButton will not be rendered.
 */
static NSString * const ADD_PEOPLE_CONTROLLER_QUERY = nil;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    JitsiMeetView *view = (JitsiMeetView *) self.view;
    view.delegate = self;

#ifdef DEBUG

    // inviteController
    JMInviteController *inviteController = view.inviteController;
    inviteController.delegate = self;
    inviteController.addPeopleEnabled
        = inviteController.dialOutEnabled
        = ADD_PEOPLE_CONTROLLER_QUERY != nil;

#endif // #ifdef DEBUG

    // As this is the Jitsi Meet app (i.e. not the Jitsi Meet SDK), we do want
    // the Welcome page to be enabled. It defaults to disabled in the SDK at the
    // time of this writing but it is clearer to be explicit about what we want
    // anyway.
    view.welcomePageEnabled = YES;

    [view loadURL:nil];
}



// JitsiMeetViewDelegate

- (void)_onJitsiMeetViewDelegateEvent:(NSString *)name
                             withData:(NSDictionary *)data {
#if DEBUG
    NSLog(
        @"[%s:%d] JitsiMeetViewDelegate %@ %@",
        __FILE__, __LINE__, name, data);

    NSAssert(
        [NSThread isMainThread],
        @"JitsiMeetViewDelegate %@ method invoked on a non-main thread",
        name);
#endif
}

- (void)conferenceFailed:(NSDictionary *)data {
    [self _onJitsiMeetViewDelegateEvent:@"CONFERENCE_FAILED" withData:data];
}

- (void)conferenceJoined:(NSDictionary *)data {
    [self _onJitsiMeetViewDelegateEvent:@"CONFERENCE_JOINED" withData:data];

    // Register a NSUserActivity for this conference so it can be invoked as a
    // Siri shortcut. This is only supported in iOS >= 12.
#ifdef __IPHONE_12_0
    if (@available(iOS 12.0, *)) {
      NSUserActivity *userActivity
        = [[NSUserActivity alloc] initWithActivityType:JitsiMeetConferenceActivityType];

      NSString *urlStr = data[@"url"];
      NSURL *url = [NSURL URLWithString:urlStr];
      NSString *conference = [url.pathComponents lastObject];

      userActivity.title = [NSString stringWithFormat:@"Join %@", conference];
      userActivity.suggestedInvocationPhrase = @"Join my Jitsi meeting";
      userActivity.userInfo = @{@"url": urlStr};
      [userActivity setEligibleForSearch:YES];
      [userActivity setEligibleForPrediction:YES];
      [userActivity setPersistentIdentifier:urlStr];

      // Subtitle
      CSSearchableItemAttributeSet *attributes
        = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:(NSString *)kUTTypeItem];
      attributes.contentDescription = urlStr;
      userActivity.contentAttributeSet = attributes;

      self.userActivity = userActivity;
      [userActivity becomeCurrent];
    }
#endif

}

- (void)conferenceLeft:(NSDictionary *)data {
    [self _onJitsiMeetViewDelegateEvent:@"CONFERENCE_LEFT" withData:data];
}

- (void)conferenceWillJoin:(NSDictionary *)data {
    [self _onJitsiMeetViewDelegateEvent:@"CONFERENCE_WILL_JOIN" withData:data];
}

- (void)conferenceWillLeave:(NSDictionary *)data {
    [self _onJitsiMeetViewDelegateEvent:@"CONFERENCE_WILL_LEAVE" withData:data];
}

- (void)loadConfigError:(NSDictionary *)data {
    [self _onJitsiMeetViewDelegateEvent:@"LOAD_CONFIG_ERROR" withData:data];
}

#if DEBUG

// JMInviteControllerDelegate

- (void)beginAddPeople:(JMAddPeopleController *)addPeopleController {
    NSLog(
        @"[%s:%d] JMInviteControllerDelegate %s",
        __FILE__, __LINE__, __FUNCTION__);

    NSAssert(
        [NSThread isMainThread],
        @"JMInviteControllerDelegate beginAddPeople: invoked on a non-main thread");

    NSString *query = ADD_PEOPLE_CONTROLLER_QUERY;
    JitsiMeetView *view = (JitsiMeetView *) self.view;
    JMInviteController *inviteController = view.inviteController;

    if (query
            && (inviteController.addPeopleEnabled
                || inviteController.dialOutEnabled)) {
        addPeopleController.delegate = self;
        [addPeopleController performQuery:query];
    } else {
        // XXX Explicitly invoke endAddPeople on addPeopleController; otherwise,
        // it is going to be memory-leaked in the associated JMInviteController
        // and no subsequent InviteButton clicks/taps will be delivered.
        [addPeopleController endAddPeople];
    }
}

// JMAddPeopleControllerDelegate

- (void)addPeopleController:(JMAddPeopleController * _Nonnull)controller
          didReceiveResults:(NSArray<NSDictionary *> * _Nonnull)results
                   forQuery:(NSString * _Nonnull)query {
    NSAssert(
        [NSThread isMainThread],
        @"JMAddPeopleControllerDelegate addPeopleController:didReceiveResults:forQuery: invoked on a non-main thread");

    NSUInteger count = results.count;

    if (count) {
        // Exercise JMAddPeopleController's inviteById: implementation.
        NSMutableArray *ids = [NSMutableArray arrayWithCapacity:count];

        for (NSUInteger i = 0; i < count; ++i) {
            ids[i] = results[i][@"id"];
        }

        [controller inviteById:ids];

        // Exercise JMInviteController's invite:withCompletion: implementation.
        //
        // XXX Technically, only at most one of the two exercises will result in
        // an actual invitation eventually.
        JitsiMeetView *view = (JitsiMeetView *) self.view;
        JMInviteController *inviteController = view.inviteController;

        [inviteController invite:results withCompletion:nil];

        return;
    }

    // XXX Explicitly invoke endAddPeople on addPeopleController; otherwise, it
    // is going to be memory-leaked in the associated JMInviteController and no
    // subsequent InviteButton clicks/taps will be delivered.
    [controller endAddPeople];
}

- (void) inviteSettled:(NSArray<NSDictionary *> * _Nonnull)failedInvitees
  fromSearchController:(JMAddPeopleController * _Nonnull)addPeopleController {
    NSAssert(
        [NSThread isMainThread],
        @"JMAddPeopleControllerDelegate inviteSettled:fromSearchController: invoked on a non-main thread");

    // XXX Explicitly invoke endAddPeople on addPeopleController; otherwise, it
    // is going to be memory-leaked in the associated JMInviteController and no
    // subsequent InviteButton clicks/taps will be delivered. Technically,
    // endAddPeople will automatically be invoked if there are no
    // failedInviteees i.e. the invite succeeeded for all specified invitees.
    [addPeopleController endAddPeople];
}

#endif // #ifdef DEBUG

@end
