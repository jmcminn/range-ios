//
//  INSClipConfig.h
//  INSCoreMedia
//
//  Created by HFY on 2021/1/5.
//  Copyright © 2021 insta360. All rights reserved.
//

#import "INSTimeScale.h"


typedef NS_ENUM(NSInteger, INSDifferentSourcesAudioType){
    INSDifferentSourcesAudioTypeNone,
    INSDifferentSourcesAudioTypeAudio1,
    INSDifferentSourcesAudioTypeAudio2,
};

typedef NS_ENUM(NSInteger, INSClipAudioMode){
    INSClipAudioModeNone,
    INSClipAudioModeDirectionFocus,
    INSClipAudioModeSpatialAudio360 = 3,
    INSClipAudioModeInsDirectionFocus = 7,
};

