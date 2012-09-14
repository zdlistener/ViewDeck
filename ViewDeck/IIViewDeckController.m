//
//  IIViewDeckController.m
//  IIViewDeck
//
//  Copyright (C) 2011, Tom Adriaenssen
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to do
//  so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

// define some LLVM3 macros if the code is compiled with a different compiler (ie LLVMGCC42)
#ifndef __has_feature
#define __has_feature(x) 0
#endif
#ifndef __has_extension
#define __has_extension __has_feature // Compatibility with pre-3.0 compilers.
#endif

#if __has_feature(objc_arc) && __clang_major__ >= 3
#define II_ARC_ENABLED 1
#endif // __has_feature(objc_arc)

#if II_ARC_ENABLED
#define II_RETAIN(xx)  ((void)(0))
#define II_RELEASE(xx)  ((void)(0))
#define II_AUTORELEASE(xx)  (xx)
#else
#define II_RETAIN(xx)           [xx retain]
#define II_RELEASE(xx)          [xx release]
#define II_AUTORELEASE(xx)      [xx autorelease]
#endif

#define II_FLOAT_EQUAL(x, y) (((x) - (y)) == 0.0f)
#define II_STRING_EQUAL(a, b) ((a == nil && b == nil) || (a != nil && [a isEqualToString:b]))

#define II_CGRectOffsetRightAndShrink(rect, offset)         \
({                                                        \
__typeof__(rect) __r = (rect);                          \
__typeof__(offset) __o = (offset);                      \
(CGRect) {  { __r.origin.x, __r.origin.y },            \
{ __r.size.width - __o, __r.size.height }  \
};                                            \
})
#define II_CGRectOffsetTopAndShrink(rect, offset)           \
({                                                        \
__typeof__(rect) __r = (rect);                          \
__typeof__(offset) __o = (offset);                      \
(CGRect) { { __r.origin.x,   __r.origin.y    + __o },   \
{ __r.size.width, __r.size.height - __o }    \
};                                             \
})
#define II_CGRectOffsetBottomAndShrink(rect, offset)        \
({                                                        \
__typeof__(rect) __r = (rect);                          \
__typeof__(offset) __o = (offset);                      \
(CGRect) { { __r.origin.x, __r.origin.y },              \
{ __r.size.width, __r.size.height - __o}     \
};                                             \
})
#define II_CGRectShrink(rect, w, h)                             \
({                                                            \
__typeof__(rect) __r = (rect);                              \
__typeof__(w) __w = (w);                                    \
__typeof__(h) __h = (h);                                    \
(CGRect) {  __r.origin,                                     \
{ __r.size.width - __w, __r.size.height - __h}   \
};                                                 \
})

#import "IIViewDeckController.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import "WrapController.h"

#define DURATION_FAST 0.3
#define DURATION_SLOW 0.3
#define SLIDE_DURATION(animated,duration) ((animated) ? (duration) : 0)
#define OPEN_SLIDE_DURATION(animated) SLIDE_DURATION(animated,DURATION_FAST)
#define CLOSE_SLIDE_DURATION(animated) SLIDE_DURATION(animated,DURATION_SLOW)

enum {
    IIViewDeckNoSide = 0,
    IIViewDeckCenterSide = 5,
};

enum {
    IIViewDeckNoOrientation = 0,
};

inline NSString* NSStringFromIIViewDeckSide(IIViewDeckSide side) {
    switch (side) {
        case IIViewDeckLeftSide:
            return @"left";
            
        case IIViewDeckRightSide:
            return @"right";

        case IIViewDeckTopSide:
            return @"top";

        case IIViewDeckBottomSide:
            return @"bottom";

        case IIViewDeckNoSide:
            return @"no";

        default:
            return @"unknown";
    }
}

inline IIViewDeckOffsetOrientation IIViewDeckOffsetOrientationFromIIViewDeckSide(IIViewDeckSide side) {
    switch (side) {
        case IIViewDeckLeftSide:
        case IIViewDeckRightSide:
            return IIViewDeckHorizontalOrientation;
            
        case IIViewDeckTopSide:
        case IIViewDeckBottomSide:
            return IIViewDeckVerticalOrientation;
            
        default:
            return IIViewDeckNoOrientation;
    }
}

@interface IIViewDeckController () <UIGestureRecognizerDelegate>

@property (nonatomic, retain) UIView* referenceView;
@property (nonatomic, readonly) CGRect referenceBounds;
@property (nonatomic, readonly) CGRect centerViewBounds;
@property (nonatomic, readonly) CGRect sideViewBounds;
@property (nonatomic, retain) NSMutableArray* panners;
@property (nonatomic, assign) CGFloat originalShadowRadius;
@property (nonatomic, assign) CGFloat originalShadowOpacity;
@property (nonatomic, retain) UIColor* originalShadowColor;
@property (nonatomic, assign) CGSize originalShadowOffset;
@property (nonatomic, retain) UIBezierPath* originalShadowPath;
@property (nonatomic, retain) UIButton* centerTapper;
@property (nonatomic, retain) UIView* centerView;
@property (nonatomic, readonly) UIView* slidingControllerView;

- (void)cleanup;

- (CGRect)slidingRectForOffset:(CGFloat)offset forOrientation:(IIViewDeckOffsetOrientation)orientation;
- (CGSize)slidingSizeForOffset:(CGFloat)offset forOrientation:(IIViewDeckOffsetOrientation)orientation;
- (void)setSlidingFrameForOffset:(CGFloat)frame forOrientation:(IIViewDeckOffsetOrientation)orientation;
- (void)setSlidingFrameForOffset:(CGFloat)offset limit:(BOOL)limit forOrientation:(IIViewDeckOffsetOrientation)orientation;
- (void)setSlidingFrameForOffset:(CGFloat)offset limit:(BOOL)limit panning:(BOOL)panning forOrientation:(IIViewDeckOffsetOrientation)orientation;
- (void)panToSlidingFrameForOffset:(CGFloat)frame forOrientation:(IIViewDeckOffsetOrientation)orientation;
- (void)hideAppropriateSideViews;

- (BOOL)setSlidingAndReferenceViews;
- (void)applyShadowToSlidingView;
- (void)restoreShadowToSlidingView;
- (void)arrangeViewsAfterRotation;
- (CGFloat)relativeStatusBarHeight;

- (void)centerViewVisible;
- (void)centerViewHidden;
- (void)centerTapped;

- (void)addPanners;
- (void)removePanners;


- (BOOL)checkCanOpenSide:(IIViewDeckSide)viewDeckSide;
- (BOOL)checkCanCloseSide:(IIViewDeckSide)viewDeckSide;
- (void)notifyWillOpenSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated;
- (void)notifyDidOpenSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated;
- (void)notifyWillCloseSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated;
- (void)notifyDidCloseSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated;
- (void)notifyDidChangeOffset:(CGFloat)offset orientation:(IIViewDeckOffsetOrientation)orientation panning:(BOOL)panning;

- (BOOL)checkDelegate:(SEL)selector side:(IIViewDeckSide)viewDeckSize;
- (void)performDelegate:(SEL)selector side:(IIViewDeckSide)viewDeckSize animated:(BOOL)animated;
- (void)performDelegate:(SEL)selector side:(IIViewDeckSide)viewDeckSize controller:(UIViewController*)controller;
- (void)performDelegate:(SEL)selector offset:(CGFloat)offset orientation:(IIViewDeckOffsetOrientation)orientation panning:(BOOL)panning;

- (void)relayRotationMethod:(void(^)(UIViewController* controller))relay;

@end 


@interface UIViewController (UIViewDeckItem_Internal) 

// internal setter for the viewDeckController property on UIViewController
- (void)setViewDeckController:(IIViewDeckController*)viewDeckController;

@end

@interface UIViewController (UIViewDeckController_ViewContainmentEmulation) 

- (void)addChildViewController:(UIViewController *)childController;
- (void)removeFromParentViewController;
- (void)willMoveToParentViewController:(UIViewController *)parent;
- (void)didMoveToParentViewController:(UIViewController *)parent;

@end


@implementation IIViewDeckController

@synthesize panningMode = _panningMode;
@synthesize panners = _panners;
@synthesize referenceView = _referenceView;
@synthesize slidingController = _slidingController;
@synthesize centerController = _centerController;
@dynamic leftController;
@dynamic rightController;
@dynamic topController;
@dynamic bottomController;
@synthesize resizesCenterView = _resizesCenterView;
@synthesize originalShadowOpacity = _originalShadowOpacity;
@synthesize originalShadowPath = _originalShadowPath;
@synthesize originalShadowRadius = _originalShadowRadius;
@synthesize originalShadowColor = _originalShadowColor;
@synthesize originalShadowOffset = _originalShadowOffset;
@synthesize delegate = _delegate;
@synthesize delegateMode = _delegateMode;
@synthesize navigationControllerBehavior = _navigationControllerBehavior;
@synthesize panningView = _panningView; 
@synthesize centerhiddenInteractivity = _centerhiddenInteractivity;
@synthesize centerTapper = _centerTapper;
@synthesize centerView = _centerView;
@synthesize sizeMode = _sizeMode;
@synthesize enabled = _enabled;
@synthesize elastic = _elastic;
@synthesize automaticallyUpdateTabBarItems = _automaticallyUpdateTabBarItems;
@synthesize panningGestureDelegate = _panningGestureDelegate;
@synthesize bounceDurationFactor = _bounceDurationFactor;

#pragma mark - Initalisation and deallocation

- (id)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithCenterViewController:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithCenterViewController:nil];
}

- (id)initWithCenterViewController:(UIViewController*)centerController {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _elastic = YES;
        _panningMode = IIViewDeckFullViewPanning;
        _navigationControllerBehavior = IIViewDeckNavigationControllerContained;
        _centerhiddenInteractivity = IIViewDeckCenterHiddenUserInteractive;
        _sizeMode = IIViewDeckLedgeSizeMode;
        _viewAppeared = 0;
        _viewFirstAppeared = NO;
        _resizesCenterView = NO;
        _automaticallyUpdateTabBarItems = NO;
        self.panners = [NSMutableArray array];
        self.enabled = YES;
        _offset = 0;
        _bounceDurationFactor = 0.3;
        _offsetOrientation = IIViewDeckHorizontalOrientation;
        
        _delegate = nil;
        _delegateMode = IIViewDeckDelegateOnly;
        
        self.originalShadowRadius = 0;
        self.originalShadowOffset = CGSizeZero;
        self.originalShadowColor = nil;
        self.originalShadowOpacity = 0;
        self.originalShadowPath = nil;
        
        _slidingController = nil;
        self.centerController = centerController;
        self.leftController = nil;
        self.rightController = nil;
        self.topController = nil;
        self.bottomController = nil;

        _ledge[IIViewDeckLeftSide] = _ledge[IIViewDeckRightSide] = _ledge[IIViewDeckTopSide] = _ledge[IIViewDeckBottomSide] = 44;
    }
    return self;
}

- (id)initWithCenterViewController:(UIViewController*)centerController leftViewController:(UIViewController*)leftController {
    if ((self = [self initWithCenterViewController:centerController])) {
        self.leftController = leftController;
    }
    return self;
}

- (id)initWithCenterViewController:(UIViewController*)centerController rightViewController:(UIViewController*)rightController {
    if ((self = [self initWithCenterViewController:centerController])) {
        self.rightController = rightController;
    }
    return self;
}

- (id)initWithCenterViewController:(UIViewController*)centerController leftViewController:(UIViewController*)leftController rightViewController:(UIViewController*)rightController {
    if ((self = [self initWithCenterViewController:centerController])) {
        self.leftController = leftController;
        self.rightController = rightController;
    }
    return self;
}

- (id)initWithCenterViewController:(UIViewController*)centerController topViewController:(UIViewController*)topController {
    if ((self = [self initWithCenterViewController:centerController])) {
        self.topController = topController;
    }
    return self;
}

- (id)initWithCenterViewController:(UIViewController*)centerController bottomViewController:(UIViewController*)bottomController {
    if ((self = [self initWithCenterViewController:centerController])) {
        self.bottomController = bottomController;
    }
    return self;
}

- (id)initWithCenterViewController:(UIViewController*)centerController topViewController:(UIViewController*)topController bottomViewController:(UIViewController*)bottomController {
    if ((self = [self initWithCenterViewController:centerController])) {
        self.topController = topController;
        self.bottomController = bottomController;
    }
    return self;
}

- (id)initWithCenterViewController:(UIViewController*)centerController leftViewController:(UIViewController*)leftController rightViewController:(UIViewController*)rightController topViewController:(UIViewController*)topController bottomViewController:(UIViewController*)bottomController {
    if ((self = [self initWithCenterViewController:centerController])) {
        self.leftController = leftController;
        self.rightController = rightController;
        self.topController = topController;
        self.bottomController = bottomController;
    }
    return self;
}




- (void)cleanup {
    self.originalShadowRadius = 0;
    self.originalShadowOpacity = 0;
    self.originalShadowColor = nil;
    self.originalShadowOffset = CGSizeZero;
    self.originalShadowPath = nil;
    
    _slidingController = nil;
    self.referenceView = nil;
    self.centerView = nil;
    self.centerTapper = nil;
}

- (void)dealloc {
    [self cleanup];
    
    self.centerController.viewDeckController = nil;
    self.centerController = nil;
    self.leftController.viewDeckController = nil;
    self.leftController = nil;
    self.rightController.viewDeckController = nil;
    self.rightController = nil;
    self.panners = nil;
    
#if !II_ARC_ENABLED
    [super dealloc];
#endif
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    [self.centerController didReceiveMemoryWarning];
    [self.leftController didReceiveMemoryWarning];
    [self.rightController didReceiveMemoryWarning];
}

#pragma mark - Bookkeeping

- (NSArray*)controllers {
    NSMutableArray *result = [NSMutableArray array];
    if (self.centerController) [result addObject:self.centerController];
    if (self.leftController) [result addObject:self.leftController];
    if (self.rightController) [result addObject:self.rightController];
    return [NSArray arrayWithArray:result];
}

- (CGRect)referenceBounds {
    return self.referenceView.bounds;
}

- (CGFloat)relativeStatusBarHeight {
    if (![self.referenceView isKindOfClass:[UIWindow class]]) 
        return 0;
    
    return [self statusBarHeight];
}

- (CGFloat)statusBarHeight {
    return UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) 
    ? [UIApplication sharedApplication].statusBarFrame.size.width 
    : [UIApplication sharedApplication].statusBarFrame.size.height;
}

- (CGRect)centerViewBounds {
    if (self.navigationControllerBehavior == IIViewDeckNavigationControllerContained)
        return self.referenceBounds;
    
    return II_CGRectShrink(self.referenceBounds, 0, [self relativeStatusBarHeight] + (self.navigationController.navigationBarHidden ? 0 : self.navigationController.navigationBar.frame.size.height));
}

- (CGRect)sideViewBounds {
    if (self.navigationControllerBehavior == IIViewDeckNavigationControllerContained)
        return self.referenceBounds;
    
    return II_CGRectOffsetTopAndShrink(self.referenceBounds, [self relativeStatusBarHeight]);
}

- (CGFloat)limitOffset:(CGFloat)offset forOrientation:(IIViewDeckOffsetOrientation)orientation {
    if (orientation == IIViewDeckHorizontalOrientation) {
        if (self.leftController && self.rightController) return offset;

        if (self.leftController && _maxLedge > 0) {
            CGFloat left = self.referenceBounds.size.width - _maxLedge;
            offset = MIN(offset, left);
        }
        else if (self.rightController && _maxLedge > 0) {
            CGFloat right = _maxLedge - self.referenceBounds.size.width;
            offset = MAX(offset, right);
        }
        
        return offset;
    }
    else {
        if (self.topController && self.bottomController) return offset;
        
        if (self.topController && _maxLedge > 0) {
            CGFloat top = self.referenceBounds.size.height - _maxLedge;
            offset = MIN(offset, top);
        }
        else if (self.bottomController && _maxLedge > 0) {
            CGFloat bottom = _maxLedge - self.referenceBounds.size.height;
            offset = MAX(offset, bottom);
        }
        
        return offset;
    }
    
}

- (CGRect)slidingRectForOffset:(CGFloat)offset forOrientation:(IIViewDeckOffsetOrientation)orientation {
    offset = [self limitOffset:offset forOrientation:orientation];
    if (orientation == IIViewDeckHorizontalOrientation) {
        return (CGRect) { {self.resizesCenterView && offset < 0 ? 0 : offset, 0}, [self slidingSizeForOffset:offset forOrientation:orientation] };
    }
    else {
        return (CGRect) { {0, self.resizesCenterView && offset < 0 ? 0 : offset}, [self slidingSizeForOffset:offset forOrientation:orientation] };
    }
}

- (CGSize)slidingSizeForOffset:(CGFloat)offset forOrientation:(IIViewDeckOffsetOrientation)orientation {
    if (!self.resizesCenterView) return self.referenceBounds.size;
    
    offset = [self limitOffset:offset forOrientation:orientation];
    if (orientation == IIViewDeckHorizontalOrientation) {
        return (CGSize) { self.centerViewBounds.size.width - ABS(offset), self.centerViewBounds.size.height };
    }
    else {
        return (CGSize) { self.centerViewBounds.size.width, self.centerViewBounds.size.height - ABS(offset) };
    }
}

-(void)setSlidingFrameForOffset:(CGFloat)offset forOrientation:(IIViewDeckOffsetOrientation)orientation {
    [self setSlidingFrameForOffset:offset limit:YES panning:NO forOrientation:orientation];
}

-(void)panToSlidingFrameForOffset:(CGFloat)offset forOrientation:(IIViewDeckOffsetOrientation)orientation {
    [self setSlidingFrameForOffset:offset limit:YES panning:YES forOrientation:orientation];
}

-(void)setSlidingFrameForOffset:(CGFloat)offset limit:(BOOL)limit forOrientation:(IIViewDeckOffsetOrientation)orientation {
    [self setSlidingFrameForOffset:offset limit:limit panning:NO forOrientation:orientation];
}

-(void)setSlidingFrameForOffset:(CGFloat)offset limit:(BOOL)limit panning:(BOOL)panning forOrientation:(IIViewDeckOffsetOrientation)orientation {
    CGFloat beforeOffset = _offset;
    if (limit)
        offset = [self limitOffset:offset forOrientation:orientation];
    _offset = offset;
    _offsetOrientation = orientation;
    self.slidingControllerView.frame = [self slidingRectForOffset:_offset forOrientation:orientation];
    if (beforeOffset != _offset)
        [self notifyDidChangeOffset:_offset orientation:orientation panning:panning];
}

- (void)hideAppropriateSideViews {
    self.leftController.view.hidden = CGRectGetMinX(self.slidingControllerView.frame) <= 0;
    self.rightController.view.hidden = CGRectGetMaxX(self.slidingControllerView.frame) >= self.referenceBounds.size.width;
    self.topController.view.hidden = CGRectGetMinY(self.slidingControllerView.frame) <= 0;
    self.bottomController.view.hidden = CGRectGetMaxY(self.slidingControllerView.frame) >= self.referenceBounds.size.height;
}

#pragma mark - ledges

- (void)setSize:(CGFloat)size forSide:(IIViewDeckSide)side completion:(void(^)(BOOL finished))completion {
    // we store ledge sizes internally but allow size to be specified depending on size mode.
    CGFloat ledge = [self sizeAsLedge:size];
    
    // Compute the final ledge in two steps. This prevents a strange bug where
    // nesting MAX(X, MIN(Y, Z)) with miniscule referenceBounds returns a bogus near-zero value.
    CGFloat minLedge;
    CGFloat(^offsetter)(CGFloat ledge);
   
    switch (side) {
        case IIViewDeckLeftSide: {
            minLedge = MIN(self.referenceBounds.size.width, ledge);
            offsetter = ^CGFloat(CGFloat l) { return  self.referenceBounds.size.width - l; };
            break;
        }

        case IIViewDeckRightSide: {
            minLedge = MIN(self.referenceBounds.size.width, ledge);
            offsetter = ^CGFloat(CGFloat l) { return l - self.referenceBounds.size.width; };
            break;
        }

        case IIViewDeckTopSide: {
            minLedge = MIN(self.referenceBounds.size.width, ledge);
            offsetter = ^CGFloat(CGFloat l) { return  self.referenceBounds.size.height - l; };
            break;
        }

        case IIViewDeckBottomSide: {
            minLedge = MIN(self.referenceBounds.size.width, ledge);
            offsetter = ^CGFloat(CGFloat l) { return l - self.referenceBounds.size.height; };
            break;
        }
            
        default:
            return;
    }

    ledge = MAX(ledge, minLedge);
    if (_viewFirstAppeared && II_FLOAT_EQUAL(self.slidingControllerView.frame.origin.x, offsetter(_ledge[side]))) {
        IIViewDeckOffsetOrientation orientation = IIViewDeckOffsetOrientationFromIIViewDeckSide(side);
        if (ledge < _ledge[side]) {
            [UIView animateWithDuration:CLOSE_SLIDE_DURATION(YES) animations:^{
                [self setSlidingFrameForOffset:offsetter(ledge) forOrientation:orientation];
            } completion:completion];
        }
        else if (ledge > _ledge[side]) {
            [UIView animateWithDuration:OPEN_SLIDE_DURATION(YES) animations:^{
                [self setSlidingFrameForOffset:offsetter(ledge) forOrientation:orientation];
            } completion:completion];
        }
    }
    _ledge[side] = ledge;
}

- (CGFloat)sizeForSide:(IIViewDeckSide)side {
    return [self ledgeAsSize:_ledge[side]];
}

#pragma mark left size

- (void)setLeftSize:(CGFloat)leftSize {
    [self setLeftSize:leftSize completion:nil];
}

- (void)setLeftSize:(CGFloat)leftSize completion:(void(^)(BOOL finished))completion {
    [self setSize:leftSize forSide:IIViewDeckLeftSide completion:completion];
}

- (CGFloat)leftSize {
    return [self sizeForSide:IIViewDeckLeftSide];
}

#pragma mark right size

- (void)setRightSize:(CGFloat)rightSize {
    [self setRightSize:rightSize completion:nil];
}

- (void)setRightSize:(CGFloat)rightSize completion:(void(^)(BOOL finished))completion {
    [self setSize:rightSize forSide:IIViewDeckRightSide completion:completion];
}
    
- (CGFloat)rightSize {
    return [self sizeForSide:IIViewDeckRightSide];
}

#pragma mark top size

- (void)setTopSize:(CGFloat)leftSize {
    [self setTopSize:leftSize completion:nil];
}

- (void)setTopSize:(CGFloat)topSize completion:(void(^)(BOOL finished))completion {
    [self setSize:topSize forSide:IIViewDeckTopSide completion:completion];
}

- (CGFloat)topSize {
    return [self sizeForSide:IIViewDeckTopSide];
}

#pragma mark Bottom size

- (void)setBottomSize:(CGFloat)bottomSize {
    [self setBottomSize:bottomSize completion:nil];
}

- (void)setBottomSize:(CGFloat)bottomSize completion:(void(^)(BOOL finished))completion {
    [self setSize:bottomSize forSide:IIViewDeckBottomSide completion:completion];
}

- (CGFloat)bottomSize {
    return [self sizeForSide:IIViewDeckBottomSide];
}

#pragma mark max size

- (void)setMaxSize:(CGFloat)maxSize {
    [self setMaxSize:maxSize completion:nil];
}

- (void)setMaxSize:(CGFloat)maxSize completion:(void(^)(BOOL finished))completion {
    int count = (self.leftController ? 1 : 0) + (self.rightController ? 1 : 0) + (self.topController ? 1 : 0) + (self.bottomController ? 1 : 0);
    
    if (count > 1) {
        NSLog(@"IIViewDeckController: warning: setting maxLedge with more than one side controllers. Value will be ignored.");
        return;
    }
    
    [self doForControllers:^(UIViewController* controller, IIViewDeckSide side) {
        if (controller) {
            if (_ledge[side] > _maxLedge)
                [self setSize:maxSize forSide:side completion:completion];
            [self setSlidingFrameForOffset:_offset forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(side)]; // should be animated
        }
    }];
}

- (CGFloat)maxSize {
    return [self ledgeAsSize:_maxLedge];
}

- (CGFloat)sizeAsLedge:(CGFloat)size {
    if (_sizeMode == IIViewDeckLedgeSizeMode)
        return size;
    else
        return self.referenceBounds.size.width - size;
}

- (CGFloat)ledgeAsSize:(CGFloat)ledge {
    if (_sizeMode == IIViewDeckLedgeSizeMode)
        return ledge;
    else
        return self.referenceBounds.size.width - ledge;
}

#pragma mark - View lifecycle

- (void)loadView
{
    _offset = 0;
    _viewFirstAppeared = NO;
    _viewAppeared = 0;
    self.view = II_AUTORELEASE([[UIView alloc] init]);
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
    self.view.clipsToBounds = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.centerView = II_AUTORELEASE([[UIView alloc] init]);
    self.centerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.centerView.autoresizesSubviews = YES;
    self.centerView.clipsToBounds = YES;
    [self.view addSubview:self.centerView];
    
    self.originalShadowRadius = 0;
    self.originalShadowOpacity = 0;
    self.originalShadowColor = nil;
    self.originalShadowOffset = CGSizeZero;
    self.originalShadowPath = nil;
}

- (void)viewDidUnload
{
    [self cleanup];
    [super viewDidUnload];
}

#pragma mark - View Containment

- (BOOL)shouldAutomaticallyForwardRotationMethods {
    return YES;
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return NO;
}

- (BOOL)automaticallyForwardAppearanceAndRotationMethodsToChildViewControllers {
    return NO;
}

#pragma mark - Appearance

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.view addObserver:self forKeyPath:@"bounds" options:NSKeyValueChangeSetting context:nil];

    if (!_viewFirstAppeared) {
        _viewFirstAppeared = YES;
        
        void(^applyViews)(void) = ^{
            [self.centerController.view removeFromSuperview];
            [self.centerView addSubview:self.centerController.view];
            
            [self doForControllers:^(UIViewController* controller, IIViewDeckSide side) {
                [controller.view removeFromSuperview];
                [self.referenceView insertSubview:controller.view belowSubview:self.slidingControllerView];
            }];
            
            [self setSlidingFrameForOffset:_offset forOrientation:_offsetOrientation];
            self.slidingControllerView.hidden = NO;
            
            self.centerView.frame = self.centerViewBounds;
            self.centerController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            self.centerController.view.frame = self.centerView.bounds;
            [self doForControllers:^(UIViewController* controller, IIViewDeckSide side) {
                controller.view.frame = self.sideViewBounds;
                controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            }];
            
            [self applyShadowToSlidingView];
        };
        
        if ([self setSlidingAndReferenceViews]) {
            applyViews();
            applyViews = nil;
        }
        
        // after 0.01 sec, since in certain cases the sliding view is reset.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.001 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
            if (applyViews) applyViews();
            [self setSlidingFrameForOffset:_offset forOrientation:_offsetOrientation];
            [self hideAppropriateSideViews];
        });
        
        [self addPanners];
        
        if ([self isSideClosed:IIViewDeckLeftSide] && [self isSideClosed:IIViewDeckRightSide] && [self isSideClosed:IIViewDeckTopSide] && [self isSideClosed:IIViewDeckBottomSide])
            [self centerViewVisible];
        else
            [self centerViewHidden];
    }
    
    [self.centerController viewWillAppear:animated];
    [self transitionAppearanceFrom:0 to:1 animated:animated];
    _viewAppeared = 1;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.centerController viewDidAppear:animated];
    [self transitionAppearanceFrom:1 to:2 animated:animated];
    _viewAppeared = 2;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.centerController viewWillDisappear:animated];
    [self transitionAppearanceFrom:2 to:1 animated:animated];
    _viewAppeared = 1;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    @try {
        [self.view removeObserver:self forKeyPath:@"bounds"];
    } @catch(id anException){
        //do nothing, obviously it wasn't attached because an exception was thrown
    }
    
    [self.centerController viewDidDisappear:animated];
    [self transitionAppearanceFrom:1 to:0 animated:animated];
    _viewAppeared = 0;
}

#pragma mark - Rotation IOS6

- (BOOL)shouldAutorotate {
    _preRotationSize = self.referenceBounds.size;
    _preRotationCenterSize = self.centerView.bounds.size;
    
    return !self.centerController || [self.centerController shouldAutorotate];
}

- (NSUInteger)supportedInterfaceOrientations {
    if (self.centerController)
        return [self.centerController supportedInterfaceOrientations];
    
    return [super supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    if (self.centerController)
        return [self.centerController preferredInterfaceOrientationForPresentation];
    
    return [super preferredInterfaceOrientationForPresentation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _preRotationSize = self.referenceBounds.size;
    _preRotationCenterSize = self.centerView.bounds.size;
    
    return !self.centerController || [self.centerController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [self relayRotationMethod:^(UIViewController *controller) {
        [controller willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    }];
    
    [self arrangeViewsAfterRotation];
}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self restoreShadowToSlidingView];
    
    _preRotationSize = self.referenceBounds.size;
    _preRotationCenterSize = self.centerView.bounds.size;

    [self relayRotationMethod:^(UIViewController *controller) {
        [controller willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    }];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self applyShadowToSlidingView];
    
    [self relayRotationMethod:^(UIViewController *controller) {
        [controller didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    }];
}

- (void)arrangeViewsAfterRotation {
    if (_preRotationSize.width <= 0 || _preRotationSize.height <= 0) return;
    
    // todo handle both sides
    
    CGFloat offset, max, preSize;
    if (_offsetOrientation == IIViewDeckVerticalOrientation) {
        offset = self.slidingControllerView.frame.origin.y;
        max = self.referenceBounds.size.height;
        preSize = _preRotationSize.height;
        if (self.resizesCenterView && II_FLOAT_EQUAL(offset, 0)) {
            offset = offset + (_preRotationCenterSize.height - _preRotationSize.height);
        }
    }
    else {
        offset = self.slidingControllerView.frame.origin.x;
        max = self.referenceBounds.size.width;
        preSize = _preRotationSize.width;
        if (self.resizesCenterView && II_FLOAT_EQUAL(offset, 0)) {
            offset = offset + (_preRotationCenterSize.width - _preRotationSize.width);
        }
    }
    
    if (self.sizeMode != IIViewDeckLedgeSizeMode) {
        _ledge[IIViewDeckLeftSide] = _ledge[IIViewDeckLeftSide] + self.referenceBounds.size.width - _preRotationSize.width;
        _ledge[IIViewDeckRightSide] = _ledge[IIViewDeckRightSide] + self.referenceBounds.size.width - _preRotationSize.width;
        _ledge[IIViewDeckTopSide] = _ledge[IIViewDeckTopSide] + self.referenceBounds.size.height - _preRotationSize.height;
        _ledge[IIViewDeckBottomSide] = _ledge[IIViewDeckBottomSide] + self.referenceBounds.size.height - _preRotationSize.height;
        _maxLedge = _maxLedge + max - preSize;
    }
    else {
        if (offset > 0) {
            offset = max - preSize + offset;
        }
        else if (offset < 0) {
            offset = offset + preSize - max;
        }
    }
    [self setSlidingFrameForOffset:offset forOrientation:_offsetOrientation];
    
    _preRotationSize = CGSizeZero;
}

#pragma mark - Notify

- (CGFloat)ledgeOffsetForSide:(IIViewDeckSide)viewDeckSide {
    switch (viewDeckSide) {
        case IIViewDeckLeftSide:
            return self.referenceBounds.size.width - _ledge[viewDeckSide];
            break;
            
        case IIViewDeckRightSide:
            return _ledge[viewDeckSide] - self.referenceBounds.size.width;
            break;
            
        case IIViewDeckTopSide:
            return self.referenceBounds.size.height - _ledge[viewDeckSide];
            
        case IIViewDeckBottomSide:
            return _ledge[viewDeckSide] - self.referenceBounds.size.height;
    }
    
    return 0;
}

- (void)doForControllers:(void(^)(UIViewController* controller, IIViewDeckSide side))action {
    if (!action) return;
    for (IIViewDeckSide side=IIViewDeckLeftSide; side<=IIViewDeckBottomSide; side++) {
        action(_controllers[side], side);
    }
}

- (UIViewController*)controllerForSide:(IIViewDeckSide)viewDeckSide {
    return viewDeckSide == IIViewDeckNoSide ? nil : _controllers[viewDeckSide];
}

- (IIViewDeckSide)oppositeOfSide:(IIViewDeckSide)viewDeckSide {
    switch (viewDeckSide) {
        case IIViewDeckLeftSide:
            return IIViewDeckRightSide;
            
        case IIViewDeckRightSide:
            return IIViewDeckLeftSide;
            
        case IIViewDeckTopSide:
            return IIViewDeckBottomSide;
            
        case IIViewDeckBottomSide:
            return IIViewDeckTopSide;
            
        default:
            return IIViewDeckNoSide;
    }
}

- (IIViewDeckSide)sideForController:(UIViewController*)controller {
    for (IIViewDeckSide side=IIViewDeckLeftSide; side<=IIViewDeckBottomSide; side++) {
        if (_controllers[side] == controller) return side;
    }
    
    return NSNotFound;
}




- (BOOL)checkCanOpenSide:(IIViewDeckSide)viewDeckSide {
    return ![self isSideOpen:viewDeckSide] && [self checkDelegate:@selector(viewDeckController:shouldOpenViewSide:) side:viewDeckSide];
}

- (BOOL)checkCanCloseSide:(IIViewDeckSide)viewDeckSide {
    return ![self isSideClosed:viewDeckSide] && [self checkDelegate:@selector(viewDeckController:shouldCloseViewSide:) side:viewDeckSide];
}

- (void)notifyWillOpenSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated {
    if (viewDeckSide == IIViewDeckNoSide) return;
    [self notifyAppearanceForSide:viewDeckSide animated:animated from:0 to:1];

    if ([self isSideClosed:viewDeckSide]) {
        [self performDelegate:@selector(viewDeckController:willOpenViewSide:animated:) side:viewDeckSide animated:animated];
    }
}

- (void)notifyDidOpenSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated {
    if (viewDeckSide == IIViewDeckNoSide) return;
    [self notifyAppearanceForSide:viewDeckSide animated:animated from:1 to:2];

    if ([self isSideOpen:viewDeckSide]) {
        [self performDelegate:@selector(viewDeckController:didOpenViewSide:animated:) side:viewDeckSide animated:animated];
    }
}

- (void)notifyWillCloseSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated {
    if (viewDeckSide == IIViewDeckNoSide) return;
    [self notifyAppearanceForSide:viewDeckSide animated:animated from:2 to:1];

    if (![self isSideClosed:viewDeckSide]) {
        [self performDelegate:@selector(viewDeckController:willCloseViewSide:animated:) side:viewDeckSide animated:animated];
    }
}

- (void)notifyDidCloseSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated {
    if (viewDeckSide == IIViewDeckNoSide) return;

    [self notifyAppearanceForSide:viewDeckSide animated:animated from:1 to:0];
    if ([self isSideClosed:viewDeckSide]) {
        [self performDelegate:@selector(viewDeckController:didCloseViewSide:animated:) side:viewDeckSide animated:animated];
        [self performDelegate:@selector(viewDeckController:didShowCenterViewFromSide:animated:) side:viewDeckSide animated:animated];
    }
}

- (void)notifyDidChangeOffset:(CGFloat)offset orientation:(IIViewDeckOffsetOrientation)orientation panning:(BOOL)panning {
    [self performDelegate:@selector(viewDeckController:didChangeOffset:orientation:panning:) offset:offset orientation:orientation panning:panning];
}

- (void)notifyAppearanceForSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated from:(int)from to:(int)to {
    if (viewDeckSide == IIViewDeckNoSide)
        return;
    
    if (_viewAppeared < to) {
        _sideAppeared[viewDeckSide] = to;
        return;
    }

    SEL selector = nil;
    if (from < to) {
        if (_sideAppeared[viewDeckSide] > from)
            return;
        
        if (to == 1)
            selector = @selector(viewWillAppear:);
        else if (to == 2)
            selector = @selector(viewDidAppear:);
    }
    else {
        if (_sideAppeared[viewDeckSide] < from)
            return;

        if (to == 1)
            selector = @selector(viewWillDisappear:);
        else if (to == 0)
            selector = @selector(viewDidDisappear:);
    }
    
    _sideAppeared[viewDeckSide] = to;
    
    if (selector) {
        UIViewController* controller = [self controllerForSide:viewDeckSide];
        BOOL (*objc_msgSendTyped)(id self, SEL _cmd, BOOL animated) = (void*)objc_msgSend;
        objc_msgSendTyped(controller, selector, animated);
    }
}

- (void)transitionAppearanceFrom:(int)from to:(int)to animated:(BOOL)animated {
    SEL selector = nil;
    if (from < to) {
        if (to == 1)
            selector = @selector(viewWillAppear:);
        else if (to == 2)
            selector = @selector(viewDidAppear:);
    }
    else {
        if (to == 1)
            selector = @selector(viewWillDisappear:);
        else if (to == 0)
            selector = @selector(viewDidDisappear:);
    }
    
    [self doForControllers:^(UIViewController *controller, IIViewDeckSide side) {
        if (from < to && _sideAppeared[side] <= from)
            return;
        else if (from > to && _sideAppeared[side] >= from)
            return;
        
        if (selector && controller) {
            BOOL (*objc_msgSendTyped)(id self, SEL _cmd, BOOL animated) = (void*)objc_msgSend;
            objc_msgSendTyped(controller, selector, animated);
        }
    }];
}



#pragma mark - controller state

- (BOOL)isSideClosed:(IIViewDeckSide)viewDeckSize {
    if (![self controllerForSide:viewDeckSize])
        return YES;
    
    switch (viewDeckSize) {
        case IIViewDeckLeftSide:
            return CGRectGetMinX(self.slidingControllerView.frame) <= 0;
            
        case IIViewDeckRightSide:
            return CGRectGetMaxX(self.slidingControllerView.frame) >= self.referenceBounds.size.width;
            
        case IIViewDeckTopSide:
            return CGRectGetMinY(self.slidingControllerView.frame) <= 0;
            
        case IIViewDeckBottomSide:
            return CGRectGetMaxY(self.slidingControllerView.frame) >= self.referenceBounds.size.height;
            
        default:
            return YES;
    }
}


- (BOOL)isSideOpen:(IIViewDeckSide)viewDeckSize {
    if (![self controllerForSide:viewDeckSize])
        return NO;
    
    switch (viewDeckSize) {
        case IIViewDeckLeftSide:
            return II_FLOAT_EQUAL(CGRectGetMinX(self.slidingControllerView.frame), self.referenceBounds.size.width - _ledge[IIViewDeckLeftSide]);
            
        case IIViewDeckRightSide: {
            return II_FLOAT_EQUAL(CGRectGetMaxX(self.slidingControllerView.frame), _ledge[IIViewDeckRightSide]);
        }

        case IIViewDeckTopSide:
            return II_FLOAT_EQUAL(CGRectGetMinY(self.slidingControllerView.frame), self.referenceBounds.size.height - _ledge[IIViewDeckTopSide]);

        case IIViewDeckBottomSide:
            return II_FLOAT_EQUAL(CGRectGetMaxY(self.slidingControllerView.frame), _ledge[IIViewDeckBottomSide]);

        default:
            return NO;
    }
}

- (BOOL)isSideTransitioning:(IIViewDeckSide)viewDeckSide {
    return ![self isSideClosed:viewDeckSide] && ![self isSideOpen:viewDeckSide];
}

- (BOOL)openSideView:(IIViewDeckSide)side animated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    // if there's no controller or we're already open, just run the completion and say we're done.
    if (![self controllerForSide:side] || [self isSideOpen:side]) {
        if (completed) completed(self, YES);
        return YES;
    }
    
    // check the delegate to allow opening
    if (![self checkCanOpenSide:side]) {
        if (completed) completed(self, NO);
        return NO;
    };
    
    if (![self isSideClosed:[self oppositeOfSide:side]]) {
        return [self toggleOpenViewAnimated:animated completion:completed];
    }
    
    __block UIViewAnimationOptions options = UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState;

    IIViewDeckControllerBlock finish = ^(IIViewDeckController *controller, BOOL success) {
        if (!success) {
            if (completed) completed(self, NO);
            return;
        }
        
        [UIView animateWithDuration:OPEN_SLIDE_DURATION(animated) delay:0 options:options animations:^{
            [self notifyWillOpenSide:side animated:animated];
            [self controllerForSide:side].view.hidden = NO;
            [self setSlidingFrameForOffset:[self ledgeOffsetForSide:side] forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(side)];
            [self centerViewHidden];
        } completion:^(BOOL finished) {
            if (completed) completed(self, YES);
            [self notifyDidOpenSide:side animated:animated];
        }];
    };

    if ([self isSideClosed:side]) {
        options |= UIViewAnimationOptionCurveEaseIn;
        // try to close any open view first
        return [self closeOpenViewAnimated:animated completion:finish];
    }
    else {
        finish(self, YES);
        return YES;
    }
}

- (BOOL)openSideView:(IIViewDeckSide)side bounceOffset:(CGFloat)bounceOffset targetOffset:(CGFloat)targetOffset bounced:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    BOOL animated = YES;
    
    // if there's no controller or we're already open, just run the completion and say we're done.
    if (![self controllerForSide:side] || [self isSideOpen:side]) {
        if (completed) completed(self, YES);
        return YES;
    }
    
    // check the delegate to allow opening
    if (![self checkCanOpenSide:side]) {
        if (completed) completed(self, NO);
        return NO;
    };
    
    UIViewAnimationOptions options = UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState;
    if ([self isSideClosed:side]) options |= UIViewAnimationCurveEaseIn;

    return [self closeOpenViewAnimated:animated completion:^(IIViewDeckController *controller, BOOL success) {
        if (!success) {
            if (completed) completed(self, NO);
            return;
        }
        
        CGFloat longFactor = _bounceDurationFactor ? 1-_bounceDurationFactor : 1;
        CGFloat shortFactor = _bounceDurationFactor ? _bounceDurationFactor : 1;
        
        // first open the view completely, run the block (to allow changes)
        [UIView animateWithDuration:OPEN_SLIDE_DURATION(YES)*longFactor delay:0 options:options animations:^{
            [self notifyWillOpenSide:side animated:animated];
            [self controllerForSide:side].view.hidden = NO;
            [self setSlidingFrameForOffset:bounceOffset forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(side)];
        } completion:^(BOOL finished) {
            [self centerViewHidden];
            // run block if it's defined
            if (bounced) bounced(self);
            [self performDelegate:@selector(viewDeckController:didBounceViewSide:openingController:) side:side controller:self.leftController];
            
            // now slide the view back to the ledge position
            [UIView animateWithDuration:OPEN_SLIDE_DURATION(YES)*shortFactor delay:0 options:UIViewAnimationCurveEaseInOut | UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState animations:^{
                [self setSlidingFrameForOffset:targetOffset forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(side)];
            } completion:^(BOOL finished) {
                if (completed) completed(self, YES);
                [self notifyDidOpenSide:side animated:animated];
            }];
        }];
    }];
}


- (BOOL)closeSideView:(IIViewDeckSide)side animated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    if ([self isSideClosed:side]) {
        if (completed) completed(self, YES);
        return YES;
    }
    
    // check the delegate to allow closing
    if (![self checkCanCloseSide:side]) {
        if (completed) completed(self, NO);
        return NO;
    }
    
    UIViewAnimationOptions options = UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState;
    if ([self isSideOpen:side]) options |= UIViewAnimationOptionCurveEaseIn;

    [UIView animateWithDuration:CLOSE_SLIDE_DURATION(animated) delay:0 options:options animations:^{
        [self notifyWillCloseSide:side animated:animated];
        [self setSlidingFrameForOffset:0 forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(side)];
        [self centerViewVisible];
    } completion:^(BOOL finished) {
        [self hideAppropriateSideViews];
        if (completed) completed(self, YES);
        [self notifyDidCloseSide:side animated:animated];
    }];
    
    return YES;
}


- (BOOL)closeSideView:(IIViewDeckSide)side bounceOffset:(CGFloat)bounceOffset bounced:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    if ([self isSideClosed:side]) {
        if (completed) completed(self, YES);
        return YES;
    }
    
    // check the delegate to allow closing
    if (![self checkCanCloseSide:side]) {
        if (completed) completed(self, NO);
        return NO;
    }
    
    UIViewAnimationOptions options = UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState;
    if ([self isSideOpen:side]) options |= UIViewAnimationCurveEaseIn;
    
    BOOL animated = YES;
    
    CGFloat longFactor = _bounceDurationFactor ? 1-_bounceDurationFactor : 1;
    CGFloat shortFactor = _bounceDurationFactor ? _bounceDurationFactor : 1;

    // first open the view completely, run the block (to allow changes) and close it again.
    [UIView animateWithDuration:OPEN_SLIDE_DURATION(YES)*shortFactor delay:0 options:options animations:^{
        [self notifyWillCloseSide:side animated:animated];
        [self setSlidingFrameForOffset:bounceOffset forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(side)];
    } completion:^(BOOL finished) {
        // run block if it's defined
        if (bounced) bounced(self);
        [self performDelegate:@selector(viewDeckController:didBounceViewSide:closingController:) side:side controller:self.leftController];
        
        [UIView animateWithDuration:CLOSE_SLIDE_DURATION(YES)*longFactor delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionLayoutSubviews animations:^{
            [self setSlidingFrameForOffset:0 forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(side)];
            [self centerViewVisible];
        } completion:^(BOOL finished2) {
            [self hideAppropriateSideViews];
            if (completed) completed(self, YES);
            [self notifyDidCloseSide:side animated:animated];
        }];
    }];
    
    return YES;
}


#pragma mark - Left Side

- (BOOL)toggleLeftView {
    return [self toggleLeftViewAnimated:YES];
}

- (BOOL)openLeftView {
    return [self openLeftViewAnimated:YES];
}

- (BOOL)closeLeftView {
    return [self closeLeftViewAnimated:YES];
}

- (BOOL)toggleLeftViewAnimated:(BOOL)animated {
    return [self toggleLeftViewAnimated:animated completion:nil];
}

- (BOOL)toggleLeftViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    if ([self isSideClosed:IIViewDeckLeftSide]) 
        return [self openLeftViewAnimated:animated completion:completed];
    else
        return [self closeLeftViewAnimated:animated completion:completed];
}

- (BOOL)openLeftViewAnimated:(BOOL)animated {
    return [self openLeftViewAnimated:animated completion:nil];
}

- (BOOL)openLeftViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    return [self openSideView:IIViewDeckLeftSide animated:animated completion:completed];
}

- (BOOL)openLeftViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self openLeftViewBouncing:bounced completion:nil];
}

- (BOOL)openLeftViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    return [self openSideView:IIViewDeckLeftSide bounceOffset:self.referenceBounds.size.width targetOffset:self.referenceBounds.size.width - _ledge[IIViewDeckLeftSide] bounced:bounced completion:completed];
}

- (BOOL)closeLeftViewAnimated:(BOOL)animated {
    return [self closeLeftViewAnimated:animated completion:nil];
}

- (BOOL)closeLeftViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    return [self closeSideView:IIViewDeckLeftSide animated:animated completion:completed];
}

- (BOOL)closeLeftViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self closeLeftViewBouncing:bounced completion:nil];
}

- (BOOL)closeLeftViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    return [self closeSideView:IIViewDeckLeftSide bounceOffset:self.referenceBounds.size.width bounced:bounced completion:completed];
}

#pragma mark - Right Side

- (BOOL)toggleRightView {
    return [self toggleRightViewAnimated:YES];
}

- (BOOL)openRightView {
    return [self openRightViewAnimated:YES];
}

- (BOOL)closeRightView {
    return [self closeRightViewAnimated:YES];
}

- (BOOL)toggleRightViewAnimated:(BOOL)animated {
    return [self toggleRightViewAnimated:animated completion:nil];
}

- (BOOL)toggleRightViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    if ([self isSideClosed:IIViewDeckRightSide]) 
        return [self openRightViewAnimated:animated completion:completed];
    else
        return [self closeRightViewAnimated:animated completion:completed];
}

- (BOOL)openRightViewAnimated:(BOOL)animated {
    return [self openRightViewAnimated:animated completion:nil];
}

- (BOOL)openRightViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    return [self openSideView:IIViewDeckRightSide animated:animated completion:completed];
}

- (BOOL)openRightViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self openRightViewBouncing:bounced completion:nil];
}

- (BOOL)openRightViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    return [self openSideView:IIViewDeckRightSide bounceOffset:-self.referenceBounds.size.width targetOffset:_ledge[IIViewDeckRightSide] - self.referenceBounds.size.width bounced:bounced completion:completed];
}

- (BOOL)closeRightViewAnimated:(BOOL)animated {
    return [self closeRightViewAnimated:animated completion:nil];
}

- (BOOL)closeRightViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    return [self closeSideView:IIViewDeckRightSide animated:animated completion:completed];
}

- (BOOL)closeRightViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self closeRightViewBouncing:bounced completion:nil];
}

- (BOOL)closeRightViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    return [self closeSideView:IIViewDeckRightSide bounceOffset:-self.referenceBounds.size.width bounced:bounced completion:completed];
}

#pragma mark - right view, special case for navigation stuff

- (BOOL)canRightViewPushViewControllerOverCenterController {
    return [self.centerController isKindOfClass:[UINavigationController class]];
}

- (void)rightViewPushViewControllerOverCenterController:(UIViewController*)controller {
    NSAssert([self.centerController isKindOfClass:[UINavigationController class]], @"cannot rightViewPushViewControllerOverCenterView when center controller is not a navigation controller");

    UIView* view = self.view;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0.0);

    CGContextRef context = UIGraphicsGetCurrentContext();
    [view.layer renderInContext:context];
    UIImage *deckshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImageView* shotView = [[UIImageView alloc] initWithImage:deckshot];
    shotView.frame = view.frame; 
    [view.superview addSubview:shotView];
    CGRect targetFrame = view.frame; 
    view.frame = CGRectOffset(view.frame, view.frame.size.width, 0);
    
    [self closeRightViewAnimated:NO];
    UINavigationController* navController = self.centerController.navigationController ? self.centerController.navigationController :(UINavigationController*)self.centerController;
    [navController pushViewController:controller animated:NO];
    
    [UIView animateWithDuration:0.3 delay:0 options:0 animations:^{
        shotView.frame = CGRectOffset(shotView.frame, -view.frame.size.width, 0);
        view.frame = targetFrame;
    } completion:^(BOOL finished) {
        [shotView removeFromSuperview];
    }];
}

#pragma mark - Top Side

- (BOOL)toggleTopView {
    return [self toggleTopViewAnimated:YES];
}

- (BOOL)openTopView {
    return [self openTopViewAnimated:YES];
}

- (BOOL)closeTopView {
    return [self closeTopViewAnimated:YES];
}

- (BOOL)toggleTopViewAnimated:(BOOL)animated {
    return [self toggleTopViewAnimated:animated completion:nil];
}

- (BOOL)toggleTopViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    if ([self isSideClosed:IIViewDeckTopSide])
        return [self openTopViewAnimated:animated completion:completed];
    else
        return [self closeTopViewAnimated:animated completion:completed];
}

- (BOOL)openTopViewAnimated:(BOOL)animated {
    return [self openTopViewAnimated:animated completion:nil];
}

- (BOOL)openTopViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    return [self openSideView:IIViewDeckTopSide animated:animated completion:completed];
}

- (BOOL)openTopViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self openTopViewBouncing:bounced completion:nil];
}

- (BOOL)openTopViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    return [self openSideView:IIViewDeckTopSide bounceOffset:self.referenceBounds.size.height targetOffset:self.referenceBounds.size.height - _ledge[IIViewDeckTopSide] bounced:bounced completion:completed];
}

- (BOOL)closeTopViewAnimated:(BOOL)animated {
    return [self closeTopViewAnimated:animated completion:nil];
}

- (BOOL)closeTopViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    return [self closeSideView:IIViewDeckTopSide animated:animated completion:completed];
}

- (BOOL)closeTopViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self closeTopViewBouncing:bounced completion:nil];
}

- (BOOL)closeTopViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    return [self closeSideView:IIViewDeckTopSide bounceOffset:self.referenceBounds.size.height bounced:bounced completion:completed];
}


#pragma mark - Bottom Side

- (BOOL)toggleBottomView {
    return [self toggleBottomViewAnimated:YES];
}

- (BOOL)openBottomView {
    return [self openBottomViewAnimated:YES];
}

- (BOOL)closeBottomView {
    return [self closeBottomViewAnimated:YES];
}

- (BOOL)toggleBottomViewAnimated:(BOOL)animated {
    return [self toggleBottomViewAnimated:animated completion:nil];
}

- (BOOL)toggleBottomViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    if ([self isSideClosed:IIViewDeckBottomSide])
        return [self openBottomViewAnimated:animated completion:completed];
    else
        return [self closeBottomViewAnimated:animated completion:completed];
}

- (BOOL)openBottomViewAnimated:(BOOL)animated {
    return [self openBottomViewAnimated:animated completion:nil];
}

- (BOOL)openBottomViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    return [self openSideView:IIViewDeckBottomSide animated:animated completion:completed];
}

- (BOOL)openBottomViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self openBottomViewBouncing:bounced completion:nil];
}

- (BOOL)openBottomViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    return [self openSideView:IIViewDeckBottomSide bounceOffset:-self.referenceBounds.size.height targetOffset:_ledge[IIViewDeckBottomSide] - self.referenceBounds.size.height bounced:bounced completion:completed];
}

- (BOOL)closeBottomViewAnimated:(BOOL)animated {
    return [self closeBottomViewAnimated:animated completion:nil];
}

- (BOOL)closeBottomViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    return [self closeSideView:IIViewDeckBottomSide animated:animated completion:completed];
}

- (BOOL)closeBottomViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self closeBottomViewBouncing:bounced completion:nil];
}

- (BOOL)closeBottomViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    return [self closeSideView:IIViewDeckBottomSide bounceOffset:-self.referenceBounds.size.height bounced:bounced completion:completed];
}


#pragma mark - toggling open view

- (BOOL)toggleOpenView {
    return [self toggleOpenViewAnimated:YES];
}

- (BOOL)toggleOpenViewAnimated:(BOOL)animated {
    return [self toggleOpenViewAnimated:animated completion:nil];
}

- (BOOL)toggleOpenViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    IIViewDeckSide fromSide, toSide;
    CGFloat targetOffset;
    
    if ([self isSideOpen:IIViewDeckLeftSide]) {
        fromSide = IIViewDeckLeftSide;
        toSide = IIViewDeckRightSide;
        targetOffset = _ledge[IIViewDeckRightSide] - self.referenceBounds.size.width;
    }
    else if (([self isSideOpen:IIViewDeckRightSide])) {
        fromSide = IIViewDeckRightSide;
        toSide = IIViewDeckLeftSide;
        targetOffset = self.referenceBounds.size.width - _ledge[IIViewDeckLeftSide];
    }
    else if (([self isSideOpen:IIViewDeckTopSide])) {
        fromSide = IIViewDeckTopSide;
        toSide = IIViewDeckBottomSide;
        targetOffset = _ledge[IIViewDeckBottomSide] - self.referenceBounds.size.height;
    }
    else if (([self isSideOpen:IIViewDeckBottomSide])) {
        fromSide = IIViewDeckBottomSide;
        toSide = IIViewDeckTopSide;
        targetOffset = self.referenceBounds.size.height - _ledge[IIViewDeckTopSide];
    }
    else
        return NO;

    // check the delegate to allow closing and opening
    if (![self checkCanCloseSide:fromSide] && ![self checkCanOpenSide:toSide]) return NO;
    
    [UIView animateWithDuration:CLOSE_SLIDE_DURATION(animated) delay:0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionLayoutSubviews animations:^{
        [self notifyWillCloseSide:fromSide animated:animated];
        [self setSlidingFrameForOffset:0 forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(fromSide)];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:OPEN_SLIDE_DURATION(animated) delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionLayoutSubviews animations:^{
            [self notifyWillOpenSide:toSide animated:animated];
            [self setSlidingFrameForOffset:targetOffset forOrientation:IIViewDeckOffsetOrientationFromIIViewDeckSide(toSide)];
        } completion:^(BOOL finished) {
            [self notifyDidOpenSide:toSide animated:animated];
        }];
        [self hideAppropriateSideViews];
        [self notifyDidCloseSide:fromSide animated:animated];
    }];
    
    return YES;
}


- (BOOL)closeOpenView {
    return [self closeOpenViewAnimated:YES];
}

- (BOOL)closeOpenViewAnimated:(BOOL)animated {
    return [self closeOpenViewAnimated:animated completion:nil];
}

- (BOOL)closeOpenViewAnimated:(BOOL)animated completion:(IIViewDeckControllerBlock)completed {
    if (![self isSideClosed:IIViewDeckLeftSide]) {
        return [self closeLeftViewAnimated:animated completion:completed];
    }
    else if (![self isSideClosed:IIViewDeckRightSide]) {
        return [self closeRightViewAnimated:animated completion:completed];
    }
    else if (![self isSideClosed:IIViewDeckTopSide]) {
        return [self closeTopViewAnimated:animated completion:completed];
    }
    else if (![self isSideClosed:IIViewDeckBottomSide]) {
        return [self closeBottomViewAnimated:animated completion:completed];
    }
    
    if (completed) completed(self, YES);
    return YES;
}


- (BOOL)closeOpenViewBouncing:(IIViewDeckControllerBounceBlock)bounced {
    return [self closeOpenViewBouncing:bounced completion:nil];
}

- (BOOL)closeOpenViewBouncing:(IIViewDeckControllerBounceBlock)bounced completion:(IIViewDeckControllerBlock)completed {
    if ([self isSideOpen:IIViewDeckLeftSide]) {
        return [self closeLeftViewBouncing:bounced completion:completed];
    }
    else if (([self isSideOpen:IIViewDeckRightSide])) {
        return [self closeRightViewBouncing:bounced completion:completed];
    }
    else if (([self isSideOpen:IIViewDeckTopSide])) {
        return [self closeTopViewBouncing:bounced completion:completed];
    }
    else if (([self isSideOpen:IIViewDeckBottomSide])) {
        return [self closeBottomViewBouncing:bounced completion:completed];
    }
    
    if (completed) completed(self, YES);
    return YES;
}


#pragma mark - Pre iOS5 message relaying

- (void)relayRotationMethod:(void(^)(UIViewController* controller))relay {
    // first check ios6. we return yes in the method, so don't bother
    BOOL ios6 = [self respondsToSelector:@selector(shouldAutomaticallyForwardAppearanceMethods)];
    if (ios6) return;
    
    // no need to check for ios5, since we already said that we'd handle it ourselves.
    relay(self.centerController);
    relay(self.leftController);
    relay(self.rightController);
    relay(self.topController);
    relay(self.bottomController);
}

#pragma mark - center view hidden stuff

- (void)centerViewVisible {
    [self removePanners];
    if (self.centerTapper) {
        [self.centerTapper removeTarget:self action:@selector(centerTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.centerTapper removeFromSuperview];
    }
    self.centerTapper = nil;
    [self addPanners];
}

- (void)centerViewHidden {
    if (IIViewDeckCenterHiddenIsInteractive(self.centerhiddenInteractivity)) 
        return;
    
    [self removePanners];
    if (!self.centerTapper) {
        self.centerTapper = [UIButton buttonWithType:UIButtonTypeCustom];
        self.centerTapper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.centerTapper.frame = [self.centerView bounds];
        [self.centerView addSubview:self.centerTapper];
        [self.centerTapper addTarget:self action:@selector(centerTapped) forControlEvents:UIControlEventTouchUpInside];
        self.centerTapper.backgroundColor = [UIColor clearColor];
    }
    self.centerTapper.frame = [self.centerView bounds];
    [self addPanners];
}

- (void)centerTapped {
    if (IIViewDeckCenterHiddenCanTapToClose(self.centerhiddenInteractivity)) {
        if (self.leftController && CGRectGetMinX(self.slidingControllerView.frame) > 0) {
            if (self.centerhiddenInteractivity == IIViewDeckCenterHiddenNotUserInteractiveWithTapToClose) 
                [self closeLeftView];
            else
                [self closeLeftViewBouncing:nil];
        }
        if (self.rightController && CGRectGetMinX(self.slidingControllerView.frame) < 0) {
            if (self.centerhiddenInteractivity == IIViewDeckCenterHiddenNotUserInteractiveWithTapToClose) 
                [self closeRightView];
            else
                [self closeRightViewBouncing:nil];
        }
        
    }
}

#pragma mark - Panning

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)panner {
    if (self.panningGestureDelegate && [self.panningGestureDelegate respondsToSelector:@selector(gestureRecognizerShouldBegin:)]) {
        BOOL result = [self.panningGestureDelegate gestureRecognizerShouldBegin:panner];
        if (!result) return result;
    }
    
    IIViewDeckOffsetOrientation orientation;
    CGPoint velocity = [panner velocityInView:self.referenceView];
    if (ABS(velocity.x) >= ABS(velocity.y))
        orientation = IIViewDeckHorizontalOrientation;
    else
        orientation = IIViewDeckVerticalOrientation;

    CGFloat pv;
    IIViewDeckSide minSide, maxSide;
    if (orientation == IIViewDeckHorizontalOrientation) {
        minSide = IIViewDeckLeftSide;
        maxSide = IIViewDeckRightSide;
        pv = self.slidingControllerView.frame.origin.x;
    }
    else {
        minSide = IIViewDeckTopSide;
        maxSide = IIViewDeckBottomSide;
        pv = self.slidingControllerView.frame.origin.y;
    }
    
    if (pv != 0) return YES;
        
    CGFloat v = [self locationOfPanner:panner orientation:orientation];
    BOOL ok = YES;

    if (v > 0) {
        ok = [self checkCanOpenSide:minSide];
        if (!ok)
            [self closeSideView:minSide animated:NO completion:nil];
    }
    else if (v < 0) {
        ok = [self checkCanOpenSide:maxSide];
        if (!ok)
            [self closeSideView:maxSide animated:NO completion:nil];
    }
    
    return ok;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (self.panningGestureDelegate && [self.panningGestureDelegate respondsToSelector:@selector(gestureRecognizer:shouldReceiveTouch:)]) {
        BOOL result = [self.panningGestureDelegate gestureRecognizer:gestureRecognizer
                                                  shouldReceiveTouch:touch];
        if (!result) return result;
    }

    if (self.panningMode == IIViewDeckDelegatePanning && [self.delegate respondsToSelector:@selector(viewDeckController:shouldPanAtTouch:)]) {
        if (![self.delegate viewDeckController:self shouldPanAtTouch:touch])
            return NO;
    }

    if ([[touch view] isKindOfClass:[UISlider class]])
        return NO;

    _panOrigin = self.slidingControllerView.frame.origin;
    return YES;
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (self.panningGestureDelegate && [self.panningGestureDelegate respondsToSelector:@selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:)]) {
        return [self.panningGestureDelegate gestureRecognizer:gestureRecognizer
           shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
    }
    
    return NO;
}

- (CGFloat)locationOfPanner:(UIPanGestureRecognizer*)panner orientation:(IIViewDeckOffsetOrientation)orientation {
    CGPoint pan = [panner translationInView:self.referenceView];
    CGFloat ofs = orientation == IIViewDeckHorizontalOrientation ? (pan.x+_panOrigin.x) : (pan.y + _panOrigin.y);
    
    IIViewDeckSide minSide, maxSide;
    CGFloat max;
    if (orientation == IIViewDeckHorizontalOrientation) {
        minSide = IIViewDeckLeftSide;
        maxSide = IIViewDeckRightSide;
        max = self.referenceBounds.size.width;
    }
    else {
        minSide = IIViewDeckTopSide;
        maxSide = IIViewDeckBottomSide;
        max = self.referenceBounds.size.height;
    }
    if (!_controllers[minSide]) ofs = MIN(0, ofs);
    if (!_controllers[maxSide]) ofs = MAX(0, ofs);
    
    CGFloat lofs = MAX(MIN(ofs, max-_ledge[minSide]), -max+_ledge[maxSide]);
    
    if (self.elastic) {
        CGFloat dofs = ABS(ofs) - ABS(lofs);
        if (dofs > 0) {
            dofs = dofs / logf(dofs + 1) * 2;
            ofs = lofs + (ofs < 0 ? -dofs : dofs);
        }
    }
    else {
        ofs = lofs;
    }
    
    return [self limitOffset:ofs forOrientation:orientation]; 
}


- (void)panned:(UIPanGestureRecognizer*)panner {
    if (!_enabled) return;
    
    if (_offset == 0 && panner.state == UIGestureRecognizerStateBegan) {
        CGPoint velocity = [panner velocityInView:self.referenceView];
        if (ABS(velocity.x) >= ABS(velocity.y))
            [self panned:panner orientation:IIViewDeckHorizontalOrientation];
        else
            [self panned:panner orientation:IIViewDeckVerticalOrientation];
    }
    else {
        [self panned:panner orientation:_offsetOrientation];
    }
}

- (void)panned:(UIPanGestureRecognizer*)panner orientation:(IIViewDeckOffsetOrientation)orientation {
    CGFloat pv, m;
    IIViewDeckSide minSide, maxSide;
    if (orientation == IIViewDeckHorizontalOrientation) {
        pv = self.slidingControllerView.frame.origin.x;
        m = self.referenceBounds.size.width;
        minSide = IIViewDeckLeftSide;
        maxSide = IIViewDeckRightSide;
    }
    else {
        pv = self.slidingControllerView.frame.origin.y;
        m = self.referenceBounds.size.height;
        minSide = IIViewDeckTopSide;
        maxSide = IIViewDeckBottomSide;
    }
    CGFloat v = [self locationOfPanner:panner orientation:orientation];

    IIViewDeckSide closeSide = IIViewDeckNoSide;
    IIViewDeckSide openSide = IIViewDeckNoSide;
    
    // if we move over a boundary while dragging, ... 
    if (pv <= 0 && v >= 0 && pv != v) {
        // ... then we need to check if the other side can open.
        if (pv < 0) {
            if (![self checkCanCloseSide:maxSide])
                return;
            [self notifyWillCloseSide:maxSide animated:NO];
            closeSide = maxSide;
        }

        if (v > 0) {
            if (![self checkCanOpenSide:minSide]) {
                [self closeSideView:maxSide animated:NO completion:nil];
                return;
            }
            [self notifyWillOpenSide:minSide animated:NO];
            openSide = minSide;
        }
    }
    else if (pv >= 0 && v <= 0 && pv != v) {
        if (pv > 0) {
            if (![self checkCanCloseSide:minSide])
                return;
            [self notifyWillCloseSide:minSide animated:NO];
            closeSide = minSide;
        }

        if (v < 0) {
            if (![self checkCanOpenSide:maxSide]) {
                [self closeSideView:minSide animated:NO completion:nil];
                return;
            }
            [self notifyWillOpenSide:maxSide animated:NO];
            openSide = maxSide;
        }
    }
    
    [self panToSlidingFrameForOffset:v forOrientation:orientation];
    
    if (panner.state == UIGestureRecognizerStateEnded ||
        panner.state == UIGestureRecognizerStateCancelled ||
        panner.state == UIGestureRecognizerStateFailed) {
        CGFloat sv = orientation == IIViewDeckHorizontalOrientation ? self.slidingControllerView.frame.origin.x : self.slidingControllerView.frame.origin.y;
        if (II_FLOAT_EQUAL(sv, 0.0f))
            [self centerViewVisible];
        else
            [self centerViewHidden];
        
        CGFloat lm3 = (m-_ledge[minSide]) / 3.0;
        CGFloat rm3 = (m-_ledge[maxSide]) / 3.0;
        CGPoint velocity = [panner velocityInView:self.referenceView];
        CGFloat orientationVelocity = orientation == IIViewDeckHorizontalOrientation ? velocity.x : velocity.y;
        if (ABS(orientationVelocity) < 500) {
            // small velocity, no movement
            if (v >= m - _ledge[minSide] - lm3) {
                [self openSideView:minSide animated:YES completion:nil];
            }
            else if (v <= _ledge[maxSide] + rm3 - m) {
                [self openSideView:maxSide animated:YES completion:nil];
            }
            else
                [self closeOpenView];
        }
        else if (orientationVelocity < 0) {
            // swipe to the left
            if (v < 0) {
                [self openSideView:maxSide animated:YES completion:nil];
            }
            else 
                [self closeOpenView];
        }
        else if (orientationVelocity > 0) {
            // swipe to the right
            if (v > 0) {
                [self openSideView:minSide animated:YES completion:nil];
            }
            else 
                [self closeOpenView];
        }
    }
    else
        [self hideAppropriateSideViews];

    [self notifyDidCloseSide:closeSide animated:NO];
    [self notifyDidOpenSide:openSide animated:NO];
}


- (void)addPanner:(UIView*)view {
    if (!view) return;
    
    UIPanGestureRecognizer* panner = II_AUTORELEASE([[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)]);
    panner.cancelsTouchesInView = YES;
    panner.delegate = self;
    [view addGestureRecognizer:panner];
    [self.panners addObject:panner];
}


- (void)addPanners {
    [self removePanners];
    
    switch (_panningMode) {
        case IIViewDeckNoPanning: 
            break;
            
        case IIViewDeckFullViewPanning:
        case IIViewDeckDelegatePanning:
            [self addPanner:self.slidingControllerView];
            // also add to disabled center
            if (self.centerTapper)
                [self addPanner:self.centerTapper];
            // also add to navigationbar if present
            if (self.navigationController && !self.navigationController.navigationBarHidden) 
                [self addPanner:self.navigationController.navigationBar];
            break;
            
        case IIViewDeckNavigationBarPanning:
            if (self.navigationController && !self.navigationController.navigationBarHidden) {
                [self addPanner:self.navigationController.navigationBar];
            }
            
            if (self.centerController.navigationController && !self.centerController.navigationController.navigationBarHidden) {
                [self addPanner:self.centerController.navigationController.navigationBar];
            }
            
            if ([self.centerController isKindOfClass:[UINavigationController class]] && !((UINavigationController*)self.centerController).navigationBarHidden) {
                [self addPanner:((UINavigationController*)self.centerController).navigationBar];
            }
            break;
        case IIViewDeckPanningViewPanning:
            if (_panningView) {
                [self addPanner:self.panningView];
            }
            break;
    }
}


- (void)removePanners {
    for (UIGestureRecognizer* panner in self.panners) {
        [panner.view removeGestureRecognizer:panner];
    }
    [self.panners removeAllObjects];
}

#pragma mark - Delegate convenience methods

- (BOOL)checkDelegate:(SEL)selector side:(IIViewDeckSide)viewDeckSide {
    BOOL ok = YES;
    // used typed message send to properly pass values
    BOOL (*objc_msgSendTyped)(id self, SEL _cmd, IIViewDeckController* foo, IIViewDeckSide viewDeckSide) = (void*)objc_msgSend;
    
    if (self.delegate && [self.delegate respondsToSelector:selector]) 
        ok = ok & objc_msgSendTyped(self.delegate, selector, self, viewDeckSide);
    
    if (_delegateMode != IIViewDeckDelegateOnly) {
        for (UIViewController* controller in self.controllers) {
            // check controller first
            if ([controller respondsToSelector:selector] && (id)controller != (id)self.delegate)
                ok = ok & objc_msgSendTyped(controller, selector, self, viewDeckSide);
            // if that fails, check if it's a navigation controller and use the top controller
            else if ([controller isKindOfClass:[UINavigationController class]]) {
                UIViewController* topController = ((UINavigationController*)controller).topViewController;
                if ([topController respondsToSelector:selector] && (id)topController != (id)self.delegate)
                    ok = ok & objc_msgSendTyped(topController, selector, self, viewDeckSide);
            }
        }
    }
    
    return ok;
}

- (void)performDelegate:(SEL)selector side:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated {
    // used typed message send to properly pass values
    void (*objc_msgSendTyped)(id self, SEL _cmd, IIViewDeckController* foo, IIViewDeckSide viewDeckSide, BOOL animated) = (void*)objc_msgSend;
    
    if (self.delegate && [self.delegate respondsToSelector:selector])
        objc_msgSendTyped(self.delegate, selector, self, viewDeckSide, animated);
    
    if (_delegateMode == IIViewDeckDelegateOnly)
        return;
    
    for (UIViewController* controller in self.controllers) {
        // check controller first
        if ([controller respondsToSelector:selector] && (id)controller != (id)self.delegate)
            objc_msgSendTyped(controller, selector, self, viewDeckSide, animated);
        // if that fails, check if it's a navigation controller and use the top controller
        else if ([controller isKindOfClass:[UINavigationController class]]) {
            UIViewController* topController = ((UINavigationController*)controller).topViewController;
            if ([topController respondsToSelector:selector] && (id)topController != (id)self.delegate)
                objc_msgSendTyped(topController, selector, self, viewDeckSide, animated);
        }
    }
}

- (void)performDelegate:(SEL)selector side:(IIViewDeckSide)viewDeckSide controller:(UIViewController*)controller {
    // used typed message send to properly pass values
    void (*objc_msgSendTyped)(id self, SEL _cmd, IIViewDeckController* foo, IIViewDeckSide viewDeckSide, UIViewController* controller) = (void*)objc_msgSend;
    
    if (self.delegate && [self.delegate respondsToSelector:selector])
        objc_msgSendTyped(self.delegate, selector, self, viewDeckSide, controller);
    
    if (_delegateMode == IIViewDeckDelegateOnly)
        return;
    
    for (UIViewController* controller in self.controllers) {
        // check controller first
        if ([controller respondsToSelector:selector] && (id)controller != (id)self.delegate)
            objc_msgSendTyped(controller, selector, self, viewDeckSide, controller);
        // if that fails, check if it's a navigation controller and use the top controller
        else if ([controller isKindOfClass:[UINavigationController class]]) {
            UIViewController* topController = ((UINavigationController*)controller).topViewController;
            if ([topController respondsToSelector:selector] && (id)topController != (id)self.delegate)
                objc_msgSendTyped(topController, selector, self, viewDeckSide, controller);
        }
    }
}

- (void)performDelegate:(SEL)selector offset:(CGFloat)offset orientation:(IIViewDeckOffsetOrientation)orientation panning:(BOOL)panning {
    void (*objc_msgSendTyped)(id self, SEL _cmd, IIViewDeckController* foo, CGFloat offset, IIViewDeckOffsetOrientation orientation, BOOL panning) = (void*)objc_msgSend;
    if (self.delegate && [self.delegate respondsToSelector:selector]) 
        objc_msgSendTyped(self.delegate, selector, self, offset, orientation, panning);
    
    if (_delegateMode == IIViewDeckDelegateOnly)
        return;
    
    for (UIViewController* controller in self.controllers) {
        // check controller first
        if ([controller respondsToSelector:selector] && (id)controller != (id)self.delegate) 
            objc_msgSendTyped(controller, selector, self, offset, orientation, panning);
        
        // if that fails, check if it's a navigation controller and use the top controller
        else if ([controller isKindOfClass:[UINavigationController class]]) {
            UIViewController* topController = ((UINavigationController*)controller).topViewController;
            if ([topController respondsToSelector:selector] && (id)topController != (id)self.delegate) 
                objc_msgSendTyped(topController, selector, self, offset, orientation, panning);
        }
    }
}


#pragma mark - Properties

- (void)setBounceDurationFactor:(CGFloat)bounceDurationFactor {
    _bounceDurationFactor = MIN(MAX(0, bounceDurationFactor), 0.99f);
}

- (void)setTitle:(NSString *)title {
    if (!II_STRING_EQUAL(title, self.title)) [super setTitle:title];
    if (!II_STRING_EQUAL(title, self.centerController.title)) self.centerController.title = title;
}

- (NSString*)title {
    return self.centerController.title;
}

- (void)setPanningMode:(IIViewDeckPanningMode)panningMode {
    if (_viewFirstAppeared) {
        [self removePanners];
        _panningMode = panningMode;
        [self addPanners];
    }
    else
        _panningMode = panningMode;
}

- (void)setPanningView:(UIView *)panningView {
    if (_panningView != panningView) {
        II_RELEASE(_panningView);
        _panningView = panningView;
        II_RETAIN(_panningView);
        
        if (_viewFirstAppeared && _panningMode == IIViewDeckPanningViewPanning)
            [self addPanners];
    }
}

- (void)setNavigationControllerBehavior:(IIViewDeckNavigationControllerBehavior)navigationControllerBehavior {
    if (!_viewFirstAppeared) {
        _navigationControllerBehavior = navigationControllerBehavior;
    }
    else {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot set navigationcontroller behavior when the view deck is already showing." userInfo:nil];
    }
}

- (void)setController:(UIViewController *)controller forSide:(IIViewDeckSide)side {
    UIViewController* prevController = _controllers[side];
    if (controller == prevController)
        return;

    __block IIViewDeckSide currentSide = IIViewDeckNoSide;
    [self doForControllers:^(UIViewController* sideController, IIViewDeckSide side) {
        if (controller == sideController)
            currentSide = side;
    }];
    void(^beforeBlock)() = ^{};
    void(^afterBlock)(UIViewController* controller) = ^(UIViewController* controller){};
    
    if (_viewFirstAppeared) {
        beforeBlock = ^{
            [self notifyAppearanceForSide:side animated:NO from:2 to:1];
            [[self controllerForSide:side].view removeFromSuperview];
            [self notifyAppearanceForSide:side animated:NO from:1 to:0];
        };
        afterBlock = ^(UIViewController* controller) {
            [self notifyAppearanceForSide:side animated:NO from:0 to:1];
            [self hideAppropriateSideViews];
            controller.view.frame = self.referenceBounds;
            controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            if (self.slidingController)
                [self.referenceView insertSubview:controller.view belowSubview:self.slidingControllerView];
            else
                [self.referenceView addSubview:controller.view];
            [self notifyAppearanceForSide:side animated:NO from:1 to:2];
        };
    }
    
    // start the transition
    if (prevController) {
        [prevController willMoveToParentViewController:nil];
        if (controller == self.centerController) self.centerController = nil;
        beforeBlock();
        if (currentSide != IIViewDeckNoSide) _controllers[currentSide] = nil;
        [prevController setViewDeckController:nil];
        [prevController removeFromParentViewController];
        [prevController didMoveToParentViewController:nil];
    }
    
    // make the switch
    if (prevController != controller) {
        II_RELEASE(prevController);
        _controllers[side] = controller;
        II_RETAIN(controller);
    }
    
    if (controller) {
        // and finish the transition
        UIViewController* parentController = (self.referenceView == self.view) ? self : [[self parentViewController] parentViewController];
        if (!parentController)
            parentController = self;
        
        [parentController addChildViewController:controller];
        [controller setViewDeckController:self];
        afterBlock(controller);
        [controller didMoveToParentViewController:parentController];
    }
}

- (UIViewController *)leftController {
    return [self controllerForSide:IIViewDeckLeftSide];
}

- (void)setLeftController:(UIViewController *)leftController {
    [self setController:leftController forSide:IIViewDeckLeftSide];
}

- (UIViewController *)rightController {
    return [self controllerForSide:IIViewDeckRightSide];
}

- (void)setRightController:(UIViewController *)rightController {
    [self setController:rightController forSide:IIViewDeckRightSide];
}

- (UIViewController *)topController {
    return [self controllerForSide:IIViewDeckTopSide];
}

- (void)setTopController:(UIViewController *)topController {
    [self setController:topController forSide:IIViewDeckTopSide];
}

- (UIViewController *)bottomController {
    return [self controllerForSide:IIViewDeckBottomSide];
}

- (void)setBottomController:(UIViewController *)bottomController {
    [self setController:bottomController forSide:IIViewDeckBottomSide];
}


- (void)setCenterController:(UIViewController *)centerController {
    if (_centerController == centerController) return;
    
    void(^beforeBlock)(UIViewController* controller) = ^(UIViewController* controller){};
    void(^afterBlock)(UIViewController* controller) = ^(UIViewController* controller){};
    
    __block CGRect currentFrame = self.referenceBounds;
    if (_viewFirstAppeared) {
        beforeBlock = ^(UIViewController* controller) {
            [controller viewWillDisappear:NO];
            [self restoreShadowToSlidingView];
            [self removePanners];
            [controller.view removeFromSuperview];
            [controller viewDidDisappear:NO];
            [self.centerView removeFromSuperview];
        };
        afterBlock = ^(UIViewController* controller) {
            [self.view addSubview:self.centerView];
            [controller viewWillAppear:NO];
            UINavigationController* navController = [centerController isKindOfClass:[UINavigationController class]] 
                ? (UINavigationController*)centerController 
                : nil;
            BOOL barHidden = NO;
            if (navController != nil && !navController.navigationBarHidden) {
                barHidden = YES;
                navController.navigationBarHidden = YES;
            }
            
            [self setSlidingAndReferenceViews];
            controller.view.frame = currentFrame;
            controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            controller.view.hidden = NO;
            [self.centerView addSubview:controller.view];
            
            if (barHidden) 
                navController.navigationBarHidden = NO;
            
            [self addPanners];
            [self applyShadowToSlidingView];
            [controller viewDidAppear:NO];
        };
    }
    
    // start the transition
    if (_centerController) {
        currentFrame = _centerController.view.frame;
        [_centerController willMoveToParentViewController:nil];
        if (centerController == self.leftController) self.leftController = nil;
        if (centerController == self.rightController) self.rightController = nil;
        if (centerController == self.topController) self.topController = nil;
        if (centerController == self.bottomController) self.bottomController = nil;
        beforeBlock(_centerController);
        @try {
            [_centerController removeObserver:self forKeyPath:@"title"];
            if (self.automaticallyUpdateTabBarItems) {
                [_centerController removeObserver:self forKeyPath:@"tabBarItem.title"];
                [_centerController removeObserver:self forKeyPath:@"tabBarItem.image"];
                [_centerController removeObserver:self forKeyPath:@"hidesBottomBarWhenPushed"];
            }
        }
        @catch (NSException *exception) {}
        [_centerController setViewDeckController:nil];
        [_centerController removeFromParentViewController];

        
        [_centerController didMoveToParentViewController:nil];
        II_RELEASE(_centerController);
    }
    
    // make the switch
    _centerController = centerController;
    
    if (_centerController) {
        // and finish the transition
        II_RETAIN(_centerController);
        [self addChildViewController:_centerController];
        [_centerController setViewDeckController:self];
        [_centerController addObserver:self forKeyPath:@"title" options:0 context:nil];
        self.title = _centerController.title;
        if (self.automaticallyUpdateTabBarItems) {
            [_centerController addObserver:self forKeyPath:@"tabBarItem.title" options:0 context:nil];
            [_centerController addObserver:self forKeyPath:@"tabBarItem.image" options:0 context:nil];
            [_centerController addObserver:self forKeyPath:@"hidesBottomBarWhenPushed" options:0 context:nil];
            self.tabBarItem.title = _centerController.tabBarItem.title;
            self.tabBarItem.image = _centerController.tabBarItem.image;
            self.hidesBottomBarWhenPushed = _centerController.hidesBottomBarWhenPushed;
        }
        
        afterBlock(_centerController);
        [_centerController didMoveToParentViewController:self];
    }    
}

- (void)setAutomaticallyUpdateTabBarItems:(BOOL)automaticallyUpdateTabBarItems {
    if (_automaticallyUpdateTabBarItems) {
        @try {
            [_centerController removeObserver:self forKeyPath:@"tabBarItem.title"];
            [_centerController removeObserver:self forKeyPath:@"tabBarItem.image"];
            [_centerController removeObserver:self forKeyPath:@"hidesBottomBarWhenPushed"];
        }
        @catch (NSException *exception) {}
    }
    
    _automaticallyUpdateTabBarItems = automaticallyUpdateTabBarItems;

    if (_automaticallyUpdateTabBarItems) {
        [_centerController addObserver:self forKeyPath:@"tabBarItem.title" options:0 context:nil];
        [_centerController addObserver:self forKeyPath:@"tabBarItem.image" options:0 context:nil];
        [_centerController addObserver:self forKeyPath:@"hidesBottomBarWhenPushed" options:0 context:nil];
        self.tabBarItem.title = _centerController.tabBarItem.title;
        self.tabBarItem.image = _centerController.tabBarItem.image;
    }
}


- (BOOL)setSlidingAndReferenceViews {
    if (self.navigationController && self.navigationControllerBehavior == IIViewDeckNavigationControllerIntegrated) {
        if ([self.navigationController.view superview]) {
            _slidingController = self.navigationController;
            self.referenceView = [self.navigationController.view superview];
            return YES;
        }
    }
    else {
        _slidingController = self.centerController;
        self.referenceView = self.view;
        return YES;
    }
    
    return NO;
}

- (UIView*)slidingControllerView {
    if (self.navigationController && self.navigationControllerBehavior == IIViewDeckNavigationControllerIntegrated) {
        return self.slidingController.view;
    }
    else {
        return self.centerView;
    }
}

#pragma mark - observation

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _centerController) {
        if ([@"tabBarItem.title" isEqualToString:keyPath]) {
            self.tabBarItem.title = _centerController.tabBarItem.title;
            return;
        }
        
        if ([@"tabBarItem.image" isEqualToString:keyPath]) {
            self.tabBarItem.image = _centerController.tabBarItem.image;
            return;
        }

        if ([@"hidesBottomBarWhenPushed" isEqualToString:keyPath]) {
            self.hidesBottomBarWhenPushed = _centerController.hidesBottomBarWhenPushed;
            self.tabBarController.hidesBottomBarWhenPushed = _centerController.hidesBottomBarWhenPushed;
            return;
        }
    }

    if ([@"title" isEqualToString:keyPath]) {
        if (!II_STRING_EQUAL([super title], self.centerController.title)) {
            self.title = self.centerController.title;
        }
        return;
    }
    
    if ([keyPath isEqualToString:@"bounds"]) {
        [self setSlidingFrameForOffset:_offset forOrientation:_offsetOrientation];
        self.slidingControllerView.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.referenceBounds].CGPath;
        UINavigationController* navController = [self.centerController isKindOfClass:[UINavigationController class]] 
        ? (UINavigationController*)self.centerController 
        : nil;
        if (navController != nil && !navController.navigationBarHidden) {
            navController.navigationBarHidden = YES;
            navController.navigationBarHidden = NO;
        }
        return;
    }
}

#pragma mark - Shadow

- (void)restoreShadowToSlidingView {
    UIView* shadowedView = self.slidingControllerView;
    if (!shadowedView) return;
    
    shadowedView.layer.shadowRadius = self.originalShadowRadius;
    shadowedView.layer.shadowOpacity = self.originalShadowOpacity;
    shadowedView.layer.shadowColor = [self.originalShadowColor CGColor]; 
    shadowedView.layer.shadowOffset = self.originalShadowOffset;
    shadowedView.layer.shadowPath = [self.originalShadowPath CGPath];
}

- (void)applyShadowToSlidingView {
    UIView* shadowedView = self.slidingControllerView;
    if (!shadowedView) return;
    
    self.originalShadowRadius = shadowedView.layer.shadowRadius;
    self.originalShadowOpacity = shadowedView.layer.shadowOpacity;
    self.originalShadowColor = shadowedView.layer.shadowColor ? [UIColor colorWithCGColor:self.slidingControllerView.layer.shadowColor] : nil;
    self.originalShadowOffset = shadowedView.layer.shadowOffset;
    self.originalShadowPath = shadowedView.layer.shadowPath ? [UIBezierPath bezierPathWithCGPath:self.slidingControllerView.layer.shadowPath] : nil;
    
    if ([self.delegate respondsToSelector:@selector(viewDeckController:applyShadow:withBounds:)]) {
        [self.delegate viewDeckController:self applyShadow:shadowedView.layer withBounds:self.referenceBounds];
    }
    else {
        shadowedView.layer.masksToBounds = NO;
        shadowedView.layer.shadowRadius = 10;
        shadowedView.layer.shadowOpacity = 0.5;
        shadowedView.layer.shadowColor = [[UIColor blackColor] CGColor];
        shadowedView.layer.shadowOffset = CGSizeZero;
        shadowedView.layer.shadowPath = [[UIBezierPath bezierPathWithRect:shadowedView.bounds] CGPath];
    }
}


@end

#pragma mark -

@implementation UIViewController (UIViewDeckItem) 

@dynamic viewDeckController;

static const char* viewDeckControllerKey = "ViewDeckController";

- (IIViewDeckController*)viewDeckController_core {
    return objc_getAssociatedObject(self, viewDeckControllerKey);
}

- (IIViewDeckController*)viewDeckController {
    id result = [self viewDeckController_core];
    if (!result && self.navigationController) 
        result = [self.navigationController viewDeckController];
    if (!result && [self respondsToSelector:@selector(wrapController)] && self.wrapController) 
        result = [self.wrapController viewDeckController];
    
    return result;
}

- (void)setViewDeckController:(IIViewDeckController*)viewDeckController {
    objc_setAssociatedObject(self, viewDeckControllerKey, viewDeckController, OBJC_ASSOCIATION_ASSIGN);
}

- (void)vdc_presentModalViewController:(UIViewController *)modalViewController animated:(BOOL)animated {
    UIViewController* controller = self.viewDeckController && (self.viewDeckController.navigationControllerBehavior == IIViewDeckNavigationControllerIntegrated || ![self.viewDeckController.centerController isKindOfClass:[UINavigationController class]]) ? self.viewDeckController : self;
    [controller vdc_presentModalViewController:modalViewController animated:animated]; // when we get here, the vdc_ method is actually the old, real method
}

- (void)vdc_dismissModalViewControllerAnimated:(BOOL)animated {
    UIViewController* controller = self.viewDeckController ? self.viewDeckController : self;
    [controller vdc_dismissModalViewControllerAnimated:animated]; // when we get here, the vdc_ method is actually the old, real method
}

#ifdef __IPHONE_5_0

- (void)vdc_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)animated completion:(void (^)(void))completion {
    UIViewController* controller = self.viewDeckController && (self.viewDeckController.navigationControllerBehavior == IIViewDeckNavigationControllerIntegrated || ![self.viewDeckController.centerController isKindOfClass:[UINavigationController class]]) ? self.viewDeckController : self;
    [controller vdc_presentViewController:viewControllerToPresent animated:animated completion:completion]; // when we get here, the vdc_ method is actually the old, real method
}

- (void)vdc_dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    UIViewController* controller = self.viewDeckController ? self.viewDeckController : self;
    [controller vdc_dismissViewControllerAnimated:flag completion:completion]; // when we get here, the vdc_ method is actually the old, real method
}

#endif

- (UINavigationController*)vdc_navigationController {
    UIViewController* controller = self.viewDeckController_core ? self.viewDeckController_core : self;
    return [controller vdc_navigationController]; // when we get here, the vdc_ method is actually the old, real method
}

- (UINavigationItem*)vdc_navigationItem {
    UIViewController* controller = self.viewDeckController_core ? self.viewDeckController_core : self;
    return [controller vdc_navigationItem]; // when we get here, the vdc_ method is actually the old, real method
}

+ (void)vdc_swizzle {
    SEL presentModal = @selector(presentModalViewController:animated:);
    SEL vdcPresentModal = @selector(vdc_presentModalViewController:animated:);
    method_exchangeImplementations(class_getInstanceMethod(self, presentModal), class_getInstanceMethod(self, vdcPresentModal));
    
    SEL presentVC = @selector(presentViewController:animated:completion:);
    SEL vdcPresentVC = @selector(vdc_presentViewController:animated:completion:);
    method_exchangeImplementations(class_getInstanceMethod(self, presentVC), class_getInstanceMethod(self, vdcPresentVC));
    
    SEL nc = @selector(navigationController);
    SEL vdcnc = @selector(vdc_navigationController);
    method_exchangeImplementations(class_getInstanceMethod(self, nc), class_getInstanceMethod(self, vdcnc));
    
    SEL ni = @selector(navigationItem);
    SEL vdcni = @selector(vdc_navigationItem);
    method_exchangeImplementations(class_getInstanceMethod(self, ni), class_getInstanceMethod(self, vdcni));
    
    // view containment drop ins for <ios5
    SEL willMoveToPVC = @selector(willMoveToParentViewController:);
    SEL vdcWillMoveToPVC = @selector(vdc_willMoveToParentViewController:);
    if (!class_getInstanceMethod(self, willMoveToPVC)) {
        Method implementation = class_getInstanceMethod(self, vdcWillMoveToPVC);
        class_addMethod([UIViewController class], willMoveToPVC, method_getImplementation(implementation), "v@:@"); 
    }
    
    SEL didMoveToPVC = @selector(didMoveToParentViewController:);
    SEL vdcDidMoveToPVC = @selector(vdc_didMoveToParentViewController:);
    if (!class_getInstanceMethod(self, didMoveToPVC)) {
        Method implementation = class_getInstanceMethod(self, vdcDidMoveToPVC);
        class_addMethod([UIViewController class], didMoveToPVC, method_getImplementation(implementation), "v@:"); 
    }
    
    SEL removeFromPVC = @selector(removeFromParentViewController);
    SEL vdcRemoveFromPVC = @selector(vdc_removeFromParentViewController);
    if (!class_getInstanceMethod(self, removeFromPVC)) {
        Method implementation = class_getInstanceMethod(self, vdcRemoveFromPVC);
        class_addMethod([UIViewController class], removeFromPVC, method_getImplementation(implementation), "v@:"); 
    }
    
    SEL addCVC = @selector(addChildViewController:);
    SEL vdcAddCVC = @selector(vdc_addChildViewController:);
    if (!class_getInstanceMethod(self, addCVC)) {
        Method implementation = class_getInstanceMethod(self, vdcAddCVC);
        class_addMethod([UIViewController class], addCVC, method_getImplementation(implementation), "v@:@"); 
    }
}

+ (void)load {
    [super load];
    [self vdc_swizzle];
}


@end

@implementation UIViewController (UIViewDeckController_ViewContainmentEmulation_Fakes) 

- (void)vdc_addChildViewController:(UIViewController *)childController {
    // intentionally empty
}

- (void)vdc_removeFromParentViewController {
    // intentionally empty
}

- (void)vdc_willMoveToParentViewController:(UIViewController *)parent {
    // intentionally empty
}

- (void)vdc_didMoveToParentViewController:(UIViewController *)parent {
    // intentionally empty
}




@end
