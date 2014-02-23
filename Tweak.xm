
// ChatKit imports
#import <iOS7/PrivateFrameworks/ChatKit/CKTranscriptController.h>
#import <iOS7/PrivateFrameworks/ChatKit/CKConversationList.h>
#import <iOS7/PrivateFrameworks/ChatKit/CKConversation.h>
#import <iOS7/PrivateFrameworks/ChatKit/CKGradientReferenceView.h>
#import <iOS7/PrivateFrameworks/ChatKit/CKTranscriptCollectionView.h>

// Messages Imports
#import "MobileSMS/CKMessagesController.h"
#import "MobileSMS/SMSApplication.h"

// UIKit imports
#import <iOS7/Frameworks/UIKit/UIGestureRecognizer.h>
#import <iOS7/Frameworks/UIKit/UIView.h>
#import <iOS7/Frameworks/UIKit/_UIBackdropView.h>
#import <iOS7/Frameworks/UIKit/_UIBackdropViewSettingsUltraLight.h>

#import <objc/runtime.h>

// #import <substrate.h>





// PREFERENCES
#define PrefPath [[@"~" stringByExpandingTildeInPath] stringByAppendingPathComponent:@"Library/Preferences/com.mattcmultimedia.messageswiper7.plist"]

static BOOL globalEnable = YES;
static BOOL wrapAroundEnabled = YES;
static BOOL detectCenter = NO;
static int edgePercent = 20; //%

static BOOL didRun = NO;
static CKMessagesController *ckMessagesController = nil;
// static UIView *backPlacard = nil;
static NSMutableArray *convos = [[[NSMutableArray alloc] init] autorelease];
static int currentConvoIndex = 0;
static BOOL leftTriggered = NO;
static BOOL rightTriggered = NO;

static UILabel *leftNameLabel;
static UILabel *rightNameLabel;
static UILabel *leftMessageLabel;
static UILabel *rightMessageLabel;

/*


MS7ConvoPreview
*/
@interface MS7ConvoPreview : UIView

@property (nonatomic, retain) _UIBackdropView *fakeBar;

@end

@implementation MS7ConvoPreview

@synthesize fakeBar = _fakeBar;

- (void)baseInit {
    // self.blurredPreview = [[CKBlurView alloc] initWithFrame:self.frame];
    // self.blurredPreview.blurRadius = 10.0f;
    // self.blurredPreview.blurCroppingRect = self.blurredPreview.frame;
    [self setUserInteractionEnabled: NO];
    [self setBackgroundColor: [[UIColor whiteColor] colorWithAlphaComponent:0.1]];

    self.layer.cornerRadius = 8;
    self.layer.masksToBounds = YES;

    self.alpha = 0;

    // self.fakeBar = [[UIToolbar alloc] initWithFrame:self.bounds];
    self.fakeBar = [[_UIBackdropView alloc] initWithFrame:self.bounds settings:[[[_UIBackdropViewSettings alloc] initWithDefaultValues] autorelease]];
    self.fakeBar.autoresizingMask = self.autoresizingMask;
    // [self.fakeBar applySettingsWithBuiltInAnimatieon: [_UIBackdropView defaultSettingsClass]];
    // self.fakeBar.barStyle = UIBarStyleDefault;
    // self.fakeBar.translucent = YES;
    // [self.fakeBar setBackgroundColor: [UIColor clearColor]];
    [self insertSubview:self.fakeBar atIndex:0];
    // [self addSubview: self.fakeBar];

}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self baseInit];
    }
    return self;
}

@end

/*
END MS7ConvoPreview


*/



// @interface CKTranscriptController
// @property (nonatomic, retain) MS7ConvoPreview *leftPreview;
// @property (nonatomic, retain) MS7ConvoPreview *rightPreview;
// @property (nonatomic, retain) UIView *swipeDelegate;

// @end
// @implementation CKTranscriptController
// static char leftHash;
// static char rightHash;
// static char swipeDelegateHash;
// - (MS7ConvoPreview *)leftPreview {
//     return objc_getAssociatedObject(self, &leftHash);
// }
// - (void)setLeftPreview:(MS7ConvoPreview *)p {
//     objc_setAssociatedObject(self, &leftHash, p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
// }

// - (MS7ConvoPreview *)rightPreview {
//     return objc_getAssociatedObject(self, &rightHash);
// }
// - (void)setRightPreview:(MS7ConvoPreview *)p {
//     objc_setAssociatedObject(self, &rightHash, p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
// }

// - (UIView *)swipeDelegate {
//     return objc_getAssociatedObject(self, &swipeDelegateHash);
// }
// - (void)setSwipeDelegate:(UIView *)p {
//     objc_setAssociatedObject(self, &swipeDelegateHash, p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
// }
// @end





%group Messages

// There's only one CKTranscriptController instantiated.
// It controls which CkTranscriptCollectionView is shown.
// Those CKTranscriptCollectionView s have a subview of class CKTranscriptScrollView (orsomething like that)
%hook CKTranscriptController

%new(v@:B)
-(void)resetPreviewsAnimated:(BOOL)shouldAnimate {
    int height = 70+80;
    if ([self _isGroupMessage]) {
        height = 70+80+44;
    }
    if (!shouldAnimate) {
        [self.leftPreview setCenter:CGPointMake(-60, height)];
        [self.rightPreview setCenter:CGPointMake(self.view.superview.frame.size.width+60, height)];
        self.leftPreview.alpha = 1.0;
        self.rightPreview.alpha = 1.0;

    } else {
        // animate to default positions.
        [UIView animateWithDuration:0.4
                              delay:0.0
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                            self.leftPreview.center = CGPointMake(-60, self.leftPreview.center.y);
                            self.rightPreview.center = CGPointMake(self.view.superview.frame.size.width+60, self.leftPreview.center.y);
                            self.leftPreview.alpha = 0;
                            self.rightPreview.alpha = 0;
                         }
                         completion:nil];
    }
}


%new()
-(void)MS7_handlepan:(UIPanGestureRecognizer *)recognizer
{
    NSLog(@"MS7_handlepan");
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        // reset the previews just in case they're still animating
        [self.view.superview.layer removeAllAnimations];
        [self resetPreviewsAnimated:NO];
        self.leftPreview.alpha = 1.0;
        self.rightPreview.alpha = 1.0;
        // NSLog(@"BEGAN SHIT");
        leftTriggered = NO;
        rightTriggered = NO;

        // get conversations for the previews
        // swiped to left, so -1
        int nextConvoIndex = 0;
        nextConvoIndex = currentConvoIndex - 1;
        if (currentConvoIndex == 0) {
            if (wrapAroundEnabled) {
                nextConvoIndex = [convos count] - 1 ;
            } else {
                nextConvoIndex = 0;
                //maybe show bounce animation here
            }
        }
        // NSLog(@"%i", (int)[convos count]);
        // NSLog(@"%i", nextConvoIndex);
        [self setLeftConversation: [convos objectAtIndex: nextConvoIndex]];
        nextConvoIndex = 0;
        nextConvoIndex = currentConvoIndex + 1;
        if (nextConvoIndex >= [convos count]) {
            if (wrapAroundEnabled) {
                nextConvoIndex = 0;
            } else {
                nextConvoIndex = currentConvoIndex;
                //maybe show bounce animation here
            }
        }
        [self setRightConversation: [convos objectAtIndex: nextConvoIndex]];
    }


    // now move both of the views
    int translation = [recognizer translationInView:recognizer.view].x;
    // NSLog(@"%i", translation);

    // Move both previews
    // NOTE: make sure to update preview contents when the conversation changes, not on the handle pan
    int newX = (int) -60+translation;
    [self.leftPreview setCenter:CGPointMake(MIN(60, newX), self.leftPreview.center.y)];
    leftTriggered = self.leftPreview.center.x == 60;


    newX = (int) self.view.superview.frame.size.width+60+translation;
    [self.rightPreview setCenter:CGPointMake(MAX(self.view.superview.frame.size.width-60, newX), self.rightPreview.center.y)];
    rightTriggered = self.rightPreview.center.x == self.view.superview.frame.size.width-60;


    if (recognizer.state == UIGestureRecognizerStateEnded) {
        // NSLog(@"ENDED SHIT: %@", (leftTriggered||rightTriggered)?@"YES":@"NO");
        int nextConvoIndex = 0;
        if (leftTriggered) {
            // swiped to left, so -1
            nextConvoIndex = currentConvoIndex - 1;
            if (currentConvoIndex == 0) {
                if (wrapAroundEnabled) {
                    nextConvoIndex = [convos count] - 1 ;
                } else {
                    nextConvoIndex = 0;
                    //maybe show bounce animation here
                }
            }
        }
        if (rightTriggered) {
            nextConvoIndex = currentConvoIndex + 1;
            if (nextConvoIndex >= [convos count]) {
                if (wrapAroundEnabled) {
                    nextConvoIndex = 0;
                } else {
                    nextConvoIndex = currentConvoIndex;
                    //maybe show bounce animation here
                }
            }
        }

        // now present the user with the next conversation, possibly with a nice sliding animation?
        if (leftTriggered || rightTriggered) {
            [ckMessagesController showConversation:[convos objectAtIndex:nextConvoIndex] animate:YES];
        }

        [self resetPreviewsAnimated:YES];
    }


}


- (void)dealloc
{
    %log;
    %orig;
}

%new
- (void)initPreviews
{
    [self setLeftPreview: [[[MS7ConvoPreview alloc] initWithFrame:CGRectMake(0,70,120,160)] autorelease]];
    [self setRightPreview: [[[MS7ConvoPreview alloc] initWithFrame:CGRectMake(320,70,120,160)] autorelease]];

    // now create the labels and add them to the blurred view
    leftNameLabel = [[UILabel alloc] initWithFrame: CGRectMake(10, 10, 100, 55)];
    rightNameLabel = [[UILabel alloc] initWithFrame: CGRectMake(10, 10, 100, 55)];
    leftMessageLabel = [[UILabel alloc] initWithFrame: CGRectMake(10,10+50+10,100,80)];
    rightMessageLabel = [[UILabel alloc] initWithFrame: CGRectMake(10,10+50+10,100,80)];


    [leftNameLabel setTextColor: [UIColor blackColor]];
    [leftNameLabel setBackgroundColor:[UIColor clearColor]];
    [rightNameLabel setTextColor: [UIColor blackColor]];
    [rightNameLabel setBackgroundColor:[UIColor clearColor]];
    [leftNameLabel setFont: [UIFont systemFontOfSize: 14.0f]];
    [rightNameLabel setFont: [UIFont systemFontOfSize: 14.0f]];
    [leftNameLabel setNumberOfLines: 4];
    [rightNameLabel setNumberOfLines: 4];
    [leftNameLabel setLineBreakMode: NSLineBreakByWordWrapping];
    [rightNameLabel setLineBreakMode: NSLineBreakByWordWrapping];

    //add message label here
    [leftMessageLabel setTextColor: [UIColor blackColor]];
    [leftMessageLabel setBackgroundColor: [UIColor clearColor]];
    [rightMessageLabel setTextColor: [UIColor blackColor]];
    [rightMessageLabel setBackgroundColor: [UIColor clearColor]];
    [leftMessageLabel setFont:[UIFont systemFontOfSize: 12.0f]];
    [rightMessageLabel setFont:[UIFont systemFontOfSize: 12.0f]];
    [leftMessageLabel setNumberOfLines: 10];
    [rightMessageLabel setNumberOfLines: 10];
    [leftMessageLabel setLineBreakMode: NSLineBreakByWordWrapping];
    [rightMessageLabel setLineBreakMode: NSLineBreakByWordWrapping];

    [leftNameLabel setText: @"Unknown - Error"];
    [rightNameLabel setText: @"Unknown - Error"];
    [leftMessageLabel setText: @"Error Retrieving Message"];
    [rightMessageLabel setText: @"Error Retrieving Message"];

    [self.leftPreview addSubview: leftNameLabel];
    [self.rightPreview addSubview: rightNameLabel];
    [self.leftPreview addSubview: leftMessageLabel];
    [self.rightPreview addSubview: rightMessageLabel];
}

%new
-(void)addPreviews {
    NSLog(@"addPreviews, %@, %@, %@", self.view.superview, self.leftPreview, self.rightPreview);
    [self.view.superview addSubview: self.leftPreview];
    [self.view.superview addSubview: self.rightPreview];
    [self resetPreviewsAnimated: NO];
}

%new
- (void)setLeftConversation:(CKConversation *)convo
{
    // NSLog(@"left convo: %@", convo);
    [leftNameLabel setText: [convo name]?:@"Unknown - Error"];
    [leftMessageLabel setText: [[convo latestMessage] previewText]?:@"Error Retrieving Message"];
}
%new
- (void)setRightConversation:(CKConversation *)convo
{
    [rightNameLabel setText: [convo name]?:@"Unknown - Error"];
    [rightMessageLabel setText: [[convo latestMessage] previewText]?:@"Error Retrieving Message"];
}

//delegate methods
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    NSLog(@"shouldReceiveTouch");
    if (![self _isVisible] || !globalEnable) {
        return NO;
    }

    // Get the touch's location in the self.view.superview view
    // if between the bounds we care about, return yes, else, no
    CGPoint coord = [touch locationInView: self.view.superview];
    float w = self.view.superview.frame.size.width;
    float edgeSize = (edgePercent/100.0)*w;

    if (detectCenter && (coord.x > edgeSize) && (coord.x < w-edgeSize)) {
        // NSLog(@"ACCEPTED");
        return YES;
    }
    if (!detectCenter && ((coord.x < edgeSize) || (coord.x > w-edgeSize))) {
        // NSLog(@"ACCEPTED");
        return YES;
    }
    // NSLog(@"NOT ACCEPTED");
    return NO;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return YES;
}

- (id)initWithNavigationController:(id)arg1
{
    %log;
    [self initPreviews];
    return %orig;
}
- (id)init
{
    %log;
    [self initPreviews];
    return %orig;
}

- (void)viewDidAppear:(BOOL)arg1 {
    %orig;



    if (self.view.superview) {
        if (!didRun) {
            didRun = YES;

            self.view.superview.userInteractionEnabled = YES;
            UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(MS7_handlepan:)];
            panRecognizer.maximumNumberOfTouches = 1;
            [panRecognizer setDelegate:self];
            // [panRecognizer _setHysteresis: 50.0];
            [self.view.superview addGestureRecognizer: panRecognizer];
            [panRecognizer release];
            // now add the previews to the self.view.superview

        }

        if (self) {
            [self addPreviews];
            convos = [[[%c(CKConversationList) sharedConversationList] conversations] mutableCopy];
        }

    }
}

- (void)sendMessage:(id)arg1 {
    %log;
    convos = [[[%c(CKConversationList) sharedConversationList] conversations] mutableCopy];
    currentConvoIndex = 0;
    %orig;

}

%end






%hook CKMessagesController
- (void)_conversationLeft:(id)fp8 {

    // left a conversation? update the list
    %log;
    %orig;
    convos = [[[%c(CKConversationList) sharedConversationList] conversations] mutableCopy];
}

- (BOOL)resumeToConversation:(id)fp8 {
    %log;
    convos = [[[%c(CKConversationList) sharedConversationList] conversations] mutableCopy];
    currentConvoIndex = [convos indexOfObject:fp8];

    return %orig;
}



- (void)showConversation:(id)fp8 animate:(BOOL)fp12 {
    %log;
    convos = [[[%c(CKConversationList) sharedConversationList] conversations] mutableCopy];
    currentConvoIndex = [convos indexOfObject:fp8];
    %orig;
}
- (void)showConversation:(id)fp8 animate:(BOOL)fp12 forceToTranscript:(BOOL)fp16 {
    %log;
    convos = [[[%c(CKConversationList) sharedConversationList] conversations] mutableCopy];
    currentConvoIndex = [convos indexOfObject:fp8];
    %orig;
}

- (id)init {
    id r = %orig;

    ckMessagesController = r;

    return r;
}

%end

%hook SMSApplication
- (void)applicationDidBecomeActive:(id)fp8
{
    // NSLog(@"APPLICATION DID BECOME ACTIVE, BITCH");
    // %log;
    %orig;
}
- (void)setMessagesController:(id)fp8
{
    %log;
    %orig;
}
%end

%end

static void MS7UpdatePreferences() {
    NSDictionary *preferences = [[NSDictionary alloc] initWithContentsOfFile:PrefPath];
    globalEnable = YES;
    if (preferences) {
        //if the option exists make it that, else default
        if ([preferences valueForKey:@"globalEnable"] != nil) {
            globalEnable = [[preferences valueForKey:@"globalEnable"] boolValue];
        } else {
            globalEnable = YES;
        }
        if ([preferences valueForKey:@"wrapAroundEnabled"] != nil) {
            wrapAroundEnabled = [[preferences valueForKey:@"wrapAroundEnabled"] boolValue];
        } else {
            wrapAroundEnabled = NO;
        }
        if ([preferences valueForKey:@"edgePercent"] != nil) {
            edgePercent = [[preferences valueForKey:@"edgePercent"] intValue];
        } else {
            edgePercent = 20;
        }
        if ([preferences valueForKey:@"detectCenter"] != nil) {
            detectCenter = [[preferences valueForKey:@"detectCenter"] boolValue];
        } else {
            detectCenter = NO;
        }
    }
    [preferences release];
}

static void reloadPrefsNotification(CFNotificationCenterRef center,
                    void *observer,
                    CFStringRef name,
                    const void *object,
                    CFDictionaryRef userInfo) {
    MS7UpdatePreferences();
}

%ctor {

   //init prefs again
    MS7UpdatePreferences();
    CFNotificationCenterRef reload = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(reload, NULL, &reloadPrefsNotification,
                    CFSTR("com.mattcmultimedia.messageswiper7/reload"), NULL, 0);


    %init(Messages);
    // %init(WhatsAppStuff);

}