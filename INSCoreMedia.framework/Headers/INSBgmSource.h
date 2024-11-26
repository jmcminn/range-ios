//
//  INSBgmSource.h
//  INSCoreMedia
//
//  Created by HFY on 2021/4/27.
//  Copyright © 2021 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface INSBgmConfig : NSObject

-(instancetype)initWithWithURL:(NSURL*)url startSrcTimeMs:(double)startSrcTimeMs endSrcTimeMs:(double)endSrcTimeMs totalSrcDurationMs:(double)totalSrcDurationMs;

/// 音频文件地址
@property(nonatomic)NSURL *url;
/// 音频相对视频开始播放起始位置, 默认-1，表示和视频头部对齐
@property(nonatomic)double positionInMediaTimeMs;
/// 音频文件中的起始时间
@property(nonatomic)double startSrcTimeMs;
/// 音频文件中的结束时间，这两个参数，相当于对原始音频文件做了截取
@property(nonatomic)double endSrcTimeMs;
///  原始音频时长
@property(nonatomic)double totalSrcDurationMs;
/// 音量,  默认值：1.0
@property(nonatomic)double volume;
/// 淡入效果时长  默认值：1000
@property(nonatomic)double afadeInDurationMs;
/// 淡出效果时长  默认值：1000
@property(nonatomic)double afadeOutDurationMs;

@end


@class INSBgmClip;
@interface INSBgmSource : NSObject

-(instancetype)initWithBgmClip:(INSBgmClip*)bgmClip;
-(instancetype)initWithBgm:(NSArray<INSBgmConfig*>*)bgms weight:(double)weight;

@property(nonatomic)double weight;
@property(nonatomic, strong, nullable)NSArray<INSBgmConfig*> *bgms;
@property(nonatomic, strong, nullable)INSBgmClip *bgmClip;

@end

NS_ASSUME_NONNULL_END
