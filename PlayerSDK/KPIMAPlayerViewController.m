//
//  KPIMAPlayerViewController.m
//  KALTURAPlayerSDK
//
//  Created by Nissim Pardo on 1/26/15.
//  Copyright (c) 2015 Kaltura. All rights reserved.
//

#import "KPIMAPlayerViewController.h"
#import "NSString+Utilities.h"


@interface KPIMAPlayerViewController () <IMAWebOpenerDelegate>{
    void(^AdEventsListener)(NSDictionary *adEventParams);
    __weak UIViewController<IMAContentPlayhead> *_parentController;
}
@property (nonatomic, copy) NSMutableDictionary *adEventParams;
@end

@implementation KPIMAPlayerViewController
- (instancetype)initWithParent:(UIViewController<IMAContentPlayhead> *)parentController {
    self = [super init];
    if (self) {
        _parentController = parentController;
        [parentController addChildViewController:self];
        [parentController.view addSubview:self.view];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor clearColor];
    self.view.frame = (CGRect){0, 0, self.view.frame.size.width, self.view.frame.size.height - 50};
    
}

- (void)viewWillDisappear:(BOOL)animated {
    _parentController = nil;
    AdEventsListener = nil;
    _adEventParams = nil;
    _adsLoader = nil;
    _adDisplayContainer = nil;
    _adsRenderingSettings = nil;
    _adsManager = nil;
    _contentPlayer = nil;
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadIMAAd:(NSString *)adLink eventsListener:(void (^)(NSDictionary *))adListener {
    AdEventsListener = [adListener copy];
    
    // Load AVPlayer with path to our content.
    self.contentPlayer = [AVPlayer new];
    
    // Create a player layer for the player.
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.contentPlayer];
    
    // Size, position, and display the AVPlayer.
    playerLayer.frame = self.view.layer.bounds;
    [self.view.layer addSublayer:playerLayer];
    
    IMAAdsRequest *request = [[IMAAdsRequest alloc] initWithAdTagUrl:adLink
                                                  adDisplayContainer:self.adDisplayContainer
                                                         userContext:nil];
    
    [self.adsLoader requestAdsWithRequest:request];
}


- (NSMutableDictionary *)adEventParams {
    if (!_adEventParams) {
        _adEventParams = [NSMutableDictionary new];
    }
    return _adEventParams;
}


// Create ads rendering settings to tell the SDK to use the in-app browser.
- (IMAAdsRenderingSettings *)adsRenderingSettings {
    if (!_adsRenderingSettings) {
        _adsRenderingSettings = [IMAAdsRenderingSettings new];
        _adsRenderingSettings.webOpenerPresentingController = self;
        _adsRenderingSettings.webOpenerDelegate = self;
        _adsRenderingSettings.uiElements = @[];
    }
    return _adsRenderingSettings;
}


// Create our AdDisplayContainer. Initialize it with our videoView as the container. This
- (IMAAdDisplayContainer *)adDisplayContainer {
    if (!_adDisplayContainer) {
        _adDisplayContainer = [[IMAAdDisplayContainer alloc] initWithAdContainer:self.view
                                                                  companionSlots:nil];
    }
    return _adDisplayContainer;
}

- (IMAAdsLoader *)adsLoader {
    if (!_adsLoader) {
        _adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
        _adsLoader.delegate = self;
    }
    return _adsLoader;
}

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
    // Grab the instance of the IMAAdsManager and set ourselves as the delegate.
    self.adsManager = adsLoadedData.adsManager;
    self.adsManager.delegate = self;
    
    
    //[self createAdsRenderingSettings];
    // Create a content playhead so the SDK can track our content for VMAP and ad rules.
    //[self createContentPlayhead];
    // Initialize the ads manager.
    [self.adsManager initializeWithContentPlayhead:_parentController
                              adsRenderingSettings:self.adsRenderingSettings];
    if (AdEventsListener) {
        AdEventsListener(AdLoadedEventKey.nullVal);
    }
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    // Something went wrong loading ads. Log the error and play the content.
    NSLog(@"Error loading ads: %@", adErrorData.adError.message);
    [self.contentPlayer play];
}

#pragma mark AdsManager Delegates

- (void)adsManager:(IMAAdsManager *)adsManager
 didReceiveAdEvent:(IMAAdEvent *)event {
    // When the SDK notified us that ads have been loaded, play them.
    NSDictionary *eventParams = nil;
    switch (event.type) {
        case kIMAAdEvent_LOADED:
            [adsManager start];
            self.adEventParams.isLinear = event.ad.isLinear;
            self.adEventParams.adID = event.ad.adId;
            self.adEventParams.adSystem = @"null";
            self.adEventParams.adPosition = event.ad.adPodInfo.adPosition;
            eventParams = self.adEventParams.toJSON.adLoaded;
            break;
        case kIMAAdEvent_STARTED:
            //            self.adEventParams.isLinear = event.ad.isLinear;
            //            self.adEventParams.adID = event.ad.adId;
            //            self.adEventParams.adSystem = @"null";
            //            self.adEventParams.adPosition = event.ad.adPodInfo.adPosition;
            //            self.adEventParams.context = @"null";
//            if (AdEventsListener) {
//                AdEventsListener(OnPlayKey.nullVal);
//            }
            self.adEventParams.duration = event.ad.duration;
            eventParams = self.adEventParams.toJSON.adStart;
            break;
        case kIMAAdEvent_COMPLETE:
            self.adEventParams.adID = event.ad.adId;
            eventParams = self.adEventParams.toJSON.adCompleted;
            break;
        case kIMAAdEvent_ALL_ADS_COMPLETED:
            eventParams = AllAdsCompletedKey.nullVal;
            break;
            //        case kIMAAdEvent_PAUSE:
            //            eventParams = ContentPauseRequestedKey.nullVal;
            //            break;
            //        case kIMAAdEvent_RESUME:
            //            eventParams = ContentResumeRequestedKey.nullVal;
            //            break;
        case kIMAAdEvent_FIRST_QUARTILE:
            eventParams = FirstQuartileKey.nullVal;
            break;
        case kIMAAdEvent_MIDPOINT:
            eventParams = MidPointKey.nullVal;
            break;
        case kIMAAdEvent_THIRD_QUARTILE:
            eventParams = ThirdQuartileKey.nullVal;
            break;
        case kIMAAdEvent_TAPPED:
            self.adEventParams.isLinear = event.ad.isLinear;
            eventParams = self.adEventParams.toJSON.adTapped;
            
            break;
        default:
            break;
    }
    self.adEventParams = nil;
    if (AdEventsListener) {
        AdEventsListener(eventParams);
    }
    if (event.type == kIMAAdEvent_ALL_ADS_COMPLETED) {
        //[self dismissViewControllerAnimated:YES completion:nil];
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }
    eventParams = nil;
}

- (void)adsManager:(IMAAdsManager *)adsManager
 didReceiveAdError:(IMAAdError *)error {
    // Something went wrong with the ads manager after ads were loaded. Log the error and play the
    // content.
    NSLog(@"AdsManager error: %@", error.message);
    [self.contentPlayer play];
}

- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    // The SDK is going to play ads, so pause the content.
    [self.contentPlayer pause];
    if (AdEventsListener) {
        AdEventsListener(ContentPauseRequestedKey.nullVal);
    }
}

- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    // The SDK is done playing ads (at least for now), so resume the content.
    [self.contentPlayer play];
    if (AdEventsListener) {
        AdEventsListener(ContentResumeRequestedKey.nullVal);
    }
}

- (void)adDidProgressToTime:(NSTimeInterval)mediaTime totalTime:(NSTimeInterval)totalTime {
    if (AdEventsListener) {
        NSMutableDictionary *timeParams = [NSMutableDictionary new];
        timeParams.time = mediaTime;
        timeParams.duration = totalTime;
        timeParams.remain = totalTime - mediaTime;
        AdEventsListener(timeParams.toJSON.adRemainingTimeChange);
        timeParams = nil;
    }
    
}

- (void)dealloc {
    
}

@end