//
//  INSVideoFrameExtracter.h
//  INSCoreMedia
//
//  Created by pengwx on 2017/12/13.
//  Copyright © 2017年 insta360. All rights reserved.
//

#import <UIKit/UIKit.h>

@class INSPlayerImage;
@class INSEmSegment;
@class INSSampleGroup;
@class INSCubemapConfig;

NS_ASSUME_NONNULL_BEGIN

//true:强制修改固件的reorder参数为0 default:false
extern NSString* const kdecoderPreSettingKeyLowDelayOptimize;
//true:使用同步VT default:false
extern NSString* const kdecoderPreSettingKeyPreferOfficialHwAccel;
//true:缩放分辨率 default:1.0
extern NSString* const kdecoderPreSettingKeyVideoOutputScaleFactor;

@interface INSVideoFrameExtracter : NSObject

/// 用于抽帧器中解码器的配置:kdecoderPreSettingKeyLowDelayOptimize,kdecoderPreSettingKeyPreferOfficialHwAccel
@property (nonatomic, strong) NSDictionary * decoderPreSettingDic;

/// if debug, set to YES before open.
@property (nonatomic) BOOL enableDebug;

/*
 Dash视频抽帧时使用，指定streamIdx，默认为0，高码率流
 需要在open前设置
 */
@property (nonatomic) int dashStreamIdx;
/**
 创建对象
 @param url 文件url
 @param mediaFileSize 去除文件尾的文件大小，单位：字节,,如果传入0，表示无文件尾
 @param videoTracksCount 文件的视频流个数，可用于单路双轨文件的抽帧
 @param reverseVideoTrackOrder 是否反转抽帧结果中的帧排列顺序
 @return 对象实例
 */
- (instancetype) initWithURL:(NSURL*)url mediaFileSize:(int64_t)mediaFileSize videoTracksCount:(int8_t)videoTracksCount reverseVideoTrackOrder:(BOOL)reverseVideoTrackOrder;

- (instancetype) initWithURL:(NSURL*)url CubemapConfig:(INSCubemapConfig *)config MediaFileSize:(int64_t) mediaFileSize videoTracksCount:(int8_t)videoTracksCount reverseVideoTrackOrder:(BOOL)reverseVideoTrackOrder;
/**
 创建对象
 @param urls 文件url
 @param mediaFileSize urls[0]的去除文件尾的文件大小，单位：字节，,如果传入0，表示无文件尾
 @param videoTracksCount 文件的视频流个数，可用于单路双轨文件的抽帧
 @param reverseVideoTrackOrder 是否反转抽帧结果中的帧排列顺序
 @return 创建对象
 */
- (instancetype) initWithURLs:(NSArray<NSURL*>*)urls mediaFileSize:(int64_t)mediaFileSize videoTracksCount:(int8_t)videoTracksCount reverseVideoTrackOrder:(BOOL)reverseVideoTrackOrder;

/**
 创建对象
 @param emSegments 循环录影文件列表
 @param mediaFileSize urls[0]的去除文件尾的文件大小，单位：字节，,如果传入0，表示无文件尾
 @param videoTracksCount 文件的视频流个数，可用于单路双轨文件的抽帧
 @param reverseVideoTrackOrder 是否反转抽帧结果中的帧排列顺序
 @return 创建对象
 */
- (instancetype) initWithEmSegments:(NSArray<INSEmSegment*>*)emSegments mediaFileSize:(int64_t)mediaFileSize videoTracksCount:(int8_t)videoTracksCount reverseVideoTrackOrder:(BOOL)reverseVideoTrackOrder;

/**
 对于远程连接设置网速限制，需要在open前设置。
 @param speedNetworkRate 单位Bytes / s，建议值1024 * 1024 / 8
 @param ioBufferSize 单位Bytes，建议值4096
 */
- (void) SetNetworkRate: (int64_t)speedNetworkRate AndIOBufferSize:(int64_t) ioBufferSize;

/**
 打开, 此处error后无法继续使用
 */
- (NSError*_Nullable) open;

/// 关闭，释放资源，调用此函数后，不能再调用其他任何功能函数
- (void) close;

/**
 seek
 @param srcTimeMs seek的时间点,单位ms
 @param accurate 为YES时表示seek到最近的frame，为NO时表示seek到 key frame
 @return 成功返回nil，失败返回error，error后无法继续使用
 */
- (NSError*_Nullable) seek:(double)srcTimeMs accurate:(BOOL)accurate;

/**
 not only key frame
 @param error 如果error code为100 表示文件结束，再次调用seek后可恢复使用；其他error code无法恢复
 @return 所需要的frame
 */
- (INSPlayerImage * _Nullable) nextFrame:(NSError *_Nullable*)error;

/**
 only key frame 若是seek后执行，将会返回seek position的前一个key frame
 @param error 如果error code为100 表示文件结束，再次调用seek后可恢复使用；其他error code无法恢复
 @return 所需要的key frame
 */
- (INSPlayerImage * _Nullable) nextVideoKeyFrame:(NSError *_Nullable*)error;

/**
 not only key frame
 @param error 如果error code为100 表示文件结束，再次调用seek后可恢复使用；其他error code无法恢复
 @return 所需要的frame
 */
- (INSSampleGroup* _Nullable) nextSampleGroup:(NSError *_Nullable*)error;

/**
 only key frame
 @param error 如果error code为100 表示文件结束，再次调用seek后可恢复使用；其他error code无法恢复
 @return 所需要的frame
 */
- (INSSampleGroup* _Nullable) nextKeySampleGroup:(NSError *_Nullable*)error;

@end

NS_ASSUME_NONNULL_END
