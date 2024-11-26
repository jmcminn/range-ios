//
//  INSAutoSeekVideoFrameExtracter.h
//  INSCoreMedia
//
//  Created by zhou on 2024/6/28.
//  Copyright © 2024 insta360. All rights reserved.
//

#ifndef INSAutoSeekVideoFrameExtracter_h
#define INSAutoSeekVideoFrameExtracter_h

#import <UIKit/UIKit.h>

@class INSPlayerImage;
@class INSEmSegment;
@class INSSampleGroup;
@class INSCubemapConfig;

NS_ASSUME_NONNULL_BEGIN

/*
 * INSAutoSeekVideoFrameExtracter，相比基类，不需要再手动seek，nextFrameToTimeMs系列接口内会判断是否需要seek
 */
@interface INSAutoSeekVideoFrameExtracter : INSVideoFrameExtracter

/// 用于抽帧器中解码器的配置:kdecoderPreSettingKeyLowDelayOptimize,kdecoderPreSettingKeyPreferOfficialHwAccel
@property (nonatomic, strong) NSDictionary * decoderPreSettingDic;

/// if debug, set to YES before open.
@property (nonatomic) BOOL enableDebug;

/*
 Dash视频抽帧时使用，指定streamIdx，默认为0，高码率流
 需要在open前设置
 */
@property (nonatomic) int dashStreamIdx;

/*
 输入的视频fps
 需要在nextFrameToTimeMs/nextVideoKeyFrameToTimeMs/nextSampleGroupToTimeMs/nextKeySampleGroupToTimeMs前设置，
 用于接口内部判断是否seek的逻辑，如不设置则默认从原视频链接中获取,无法获取默认30。
 */
@property (nonatomic) double fps;
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
 AutoSeek VideoFrameExtracter里面的策略和 基类的 seek冲突，子类不要使用，接口无法访问。
 */
- (NSError*_Nullable) seek:(double)srcTimeMs accurate:(BOOL)accurate NS_UNAVAILABLE;

/**
 not only key frame
 @param error 如果error code为100 表示文件结束，再次调用nextFrameToTimeMs系列接口后可恢复使用；其他error code无法恢复
 @return 所需要的frame
 */
- (INSPlayerImage * _Nullable) nextFrame:(NSError *_Nullable*)error;

/**
 only key frame 若是seek后执行，将会返回seek position的前一个key frame
 @param error 如果error code为100 表示文件结束，再次调用nextFrameToTimeMs系列接口后可恢复使用；其他error code无法恢复
 @return 所需要的key frame
 */
- (INSPlayerImage * _Nullable) nextVideoKeyFrame:(NSError *_Nullable*)error;

/**
 not only key frame
 @param srcTimeMs 目标时间戳，
 @param error 如果error code为100 表示文件结束，再次调用nextFrameToTimeMs系列接口后可恢复使用；其他error code无法恢复
 @return 返回第一个大于等于srcTimeMs的帧。
 输入时间为负数，则返回下一帧。
 输入时间 <= 游标，seek
 输入时间 > 游标，若差距小于(30/fps * 1000)，持续读取下一帧到大于等于srcTimeMs的帧；反之按srcTimeMs进行seek后，返回下一帧
 */
- (INSPlayerImage * _Nullable) nextFrameToTimeMs: (double)srcTimeMs error:(NSError *_Nullable*)error;

/**
only key frame
 @param srcTimeMs 目标时间戳，
 @param error 如果error code为100 表示文件结束，再次调用nextFrameToTimeMs系列接口后可恢复使用；其他error code无法恢复
 @return 返回第一个大于等于srcTimeMs的帧。
 输入时间为负数，则返回下一帧。
 输入时间 <= 游标，seek
 输入时间 > 游标，若差距小于(30/fps * 1000)，持续读取下一帧到大于等于srcTimeMs的帧；反之按srcTimeMs进行seek后，返回下一帧
 */
- (INSPlayerImage * _Nullable) nextVideoKeyFrameToTimeMs: (double)srcTimeMs error:(NSError *_Nullable*)error;

/**
 not only key frame
 @param error 如果error code为100 表示文件结束，再次调用nextFrameToTimeMs系列接口后可恢复使用；其他error code无法恢复
 @return 所需要的sampleGroup
 */
- (INSSampleGroup* _Nullable) nextSampleGroup:(NSError *_Nullable*)error;

/**
 only key frame 若是seek后执行，将会返回seek position的前一个key frame
 @param error 如果error code为100 表示文件结束，再次调用nextFrameToTimeMs系列接口后可恢复使用；其他error code无法恢复
 @return 所需要的key frame
 */
- (INSSampleGroup* _Nullable) nextKeySampleGroup:(NSError *_Nullable*)error;

/**
 not only key frame
 @param srcTimeMs 目标时间戳，
 @param error 如果error code为100 表示文件结束，再次调用nextFrameToTimeMs系列接口后可恢复使用；其他error code无法恢复
 @return 返回第一个大于等于srcTimeMs的帧。
 输入时间为负数，则返回下一帧。
 输入时间 <= 游标，seek
 输入时间 > 游标，若差距小于(30/fps * 1000)，持续读取下一帧到大于等于srcTimeMs的帧；反之按srcTimeMs进行seek后，返回下一帧
 */
- (INSSampleGroup* _Nullable) nextSampleGroupToTimeMs: (double)srcTimeMs error:(NSError *_Nullable*)error;

/**
 only key frame
 @param srcTimeMs 目标时间戳，
 @param error 如果error code为100 表示文件结束，再次调用nextFrameToTimeMs系列接口后可恢复使用；其他error code无法恢复
 @return 返回第一个大于等于srcTimeMs的帧。
 输入时间为负数，则返回下一帧。
 输入时间 <= 游标，seek
 输入时间 > 游标，若差距小于(30/fps * 1000)，持续读取下一帧到大于等于srcTimeMs的帧；反之按srcTimeMs进行seek后，返回下一帧
 */
- (INSSampleGroup* _Nullable) nextKeySampleGroupToTimeMs: (double)srcTimeMs error:(NSError *_Nullable*)error;

@end

NS_ASSUME_NONNULL_END

#endif
