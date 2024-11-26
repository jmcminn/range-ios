//
//  INSPreviewer3Pos.h
//  INSCoreMedia
//
//  Created by ruiwen feng on 2022/6/29.
//  Copyright © 2022 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class INSFileClipPos;
@interface INSPreviewer3Pos : NSObject

/// 当前进度时间点
@property (nonatomic, assign, readonly) double currentPosMs;

/// 当前视频画面时间点
@property (nonatomic, strong, readonly, nullable) INSFileClipPos *videoPos;

/// bgm时间点
@property (nonatomic, strong, readonly, nullable) INSFileClipPos *bgmPos;

/// INSPreviewer3Pos初始化
/// @param timestamp 当前进度时间点
/// @param videoPos 当前视频画面时间点
/// @param bgmPos bgm时间点
- (instancetype)initWithCurrentPosMs:(double)timestamp videoPos:(INSFileClipPos* _Nullable)videoPos bgmPos:(INSFileClipPos* _Nullable)bgmPos;

@end

NS_ASSUME_NONNULL_END
