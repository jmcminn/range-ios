//
//  INSPreviewer3.h
//  INSCoreMedia
//
//  Created by ruiwen feng on 2022/6/24.
//  Copyright © 2022 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "INSPlayerProtocol.h"
#import "INSDecoderInfo.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark- ======= Enum Define ======
/// Previewer BufferingStatus
typedef NS_ENUM(NSInteger, INSPreviewer3BufferingStatus) {
    INSPreviewer3BufferingStatusStart = 0,
    INSPreviewer3BufferingStatusUpdate  = 1,
    INSPreviewer3BufferingStatusEnd = 2,
};

/// INSPreviewer Status
typedef NS_ENUM(NSInteger, INSPreviewer3Status){
    INSPreviewer3StatusUnknown,
    INSPreviewer3StatusPrepared,
    INSPreviewer3StatusPlaying,
    INSPreviewer3StatusPaused,
};

/// INSPreviewer AudioType
typedef NS_ENUM(NSInteger, INSPreviewer3AudioType) {
    INSPreviewer3AudioTypeOriginal = 0,
    INSPreviewer3AudioTypeBgm  = 1,
};

/// INSPreviewer BeamformLevel
typedef NS_ENUM(int, INSPreviewer3AudioBeamformLevel) {
    INSPreviewer3AudioBeamformLevelNo = 0,
    INSPreviewer3AudioBeamformLevelSoft  = 1,
    INSPreviewer3AudioBeamformLevelStrong = 2,
};

#pragma mark- ======= Protocol Define ======
#pragma mark Protocol=======INSPreviewer3Delegate
@class INSPreviewer3;
@class INSAudioSample;
@protocol INSPreviewer3Delegate <NSObject>

@required
/// Prepare事件回调
/// @param previewer 当前执行的previewer
/// @param error 错误信息
- (void)previewerPrepare:(INSPreviewer3*)previewer error:(NSError* _Nullable)error;

/// Complete事件回调
/// @param previewer 当前执行的previewer
- (void)previewerComplete:(INSPreviewer3*)previewer;

/// Seek事件回调
/// @param previewer 当前执行的previewer
/// @param serialId extra
- (void)previewerSeek:(INSPreviewer3*)previewer serialId:(int)serialId;

/// 错误信息回调
/// @param previewer 当前执行的previewer
/// @param error 错误信息
- (void)previewer:(INSPreviewer3*)previewer error:(NSError*)error;

@optional
/// ReloadBegin事件回调
/// @param previewer 当前执行的previewer
- (void)previewerReloadBegin:(INSPreviewer3*)previewer;

@optional
/// 通知最近的一次副码流seek帧
/// @param previewer 当前执行的previewer
/// @param serialId extra
- (void)previewerSeekOptOutput:(INSPreviewer3*)previewer serialId:(int)serialId;

@optional
/// dash自动切码流是回调
/// @param previewer 当前执行的previewer
/// @param streamIdx 切换至的streamIdx, 0为高码率，1为低码率
- (void)previewerOnDashStreamChanged:(INSPreviewer3*)previewer streamIdx:(int) streamIdx;

/// ReloadFinish事件回调
/// @param previewer 当前执行的previewer
- (void)previewerReloadFinish:(INSPreviewer3*)previewer;

/// PREPARE_CACHE_PROGRESS 事件回调
/// @param previewer 当前执行的previewer
- (void)previewerPrepareCacheProgress:(INSPreviewer3*)previewer progress:(int)progress;

/// 预览播放的视频帧
/// @param previewer 当前执行的previewer
/// @param playerImage 视频帧
- (void)previewer:(INSPreviewer3*)previewer playerImage:(INSPlayerImage*)playerImage;

/// 预览器播放的音频帧
/// @param previewer  当前执行的previewer
/// @param sample 音频帧
- (void)previewer:(INSPreviewer3*)previewer audioSample:(INSAudioSample*)sample;

/// buffering信息
/// @param previewer 预览器
/// @param status buffering状态
/// @param progress buffering进度，0~1.0
- (void)previewer:(INSPreviewer3*)previewer bufferingStatus:(INSPreviewer3BufferingStatus)status progress:(double)progress;

@end

#pragma mark- ======= Class Define ======
#pragma mark Class=======INSPreviewer3ReloadOption
/// 重新加载配置项
@interface INSPreviewer3ReloadOption: NSObject
/// 加载完成后是否丢弃第一段视频，可能会导致使用子码流
@property (nonatomic, assign) bool discardFirstVideoSample;

/// 如果缓存了，不会使用到这个值，如果缓存没有被命中，会退回到这个时刻
@property (nonatomic, assign) double fallbackMediaTimeMs;

/// 强制跳转到该时刻，优先级高于其他情况
@property (nonatomic, assign) double forceSeekMediaTimeMs;
@end

#pragma mark Class=======INSPreviewer3PwVideoStreamOption
/// 用来选择视频dash流和相机主副码流的参数
@interface INSPreviewer3PwVideoStreamOption: NSObject
/// dash流的index  (需要传入int值, 用NSNumber是为了方便判断optional)
@property (nullable, nonatomic) NSNumber *dashStreamIndex;
@property (nullable, nonatomic) NSNumber *dashStreamIndexOfPrepare;
/// 相机主副码流的选择, true表示播放副码流, (需要传入bool值, 用NSNumber是为了方便判断optional)
@property (nullable, nonatomic) NSNumber *cameraOptionalStream;
/// 表示是否立即切换dash流, 只有在没设置相机主副码流的情况下才有效. 如果设置了相机主副码流则一定会seek (需要传入bool值, 用NSNumber是为了方便判断optional)
@property (nullable, nonatomic) NSNumber *immediateSwitchDashStream;
/// 表示seek后是否先出副码流 (需要传入bool值, 用NSNumber是为了方便判断optional)
@property (nullable, nonatomic) NSNumber *outputOptionalSeekFrameFirst;

- (instancetype)initWithDashStreamIndex:(nullable NSNumber *) dashStreamIndex dashStreamIndexOfPrepare:(nullable NSNumber *)dashStreamIndexOfPrepare cameraOptionalStream:(nullable NSNumber *) cameraOptionalStream immediateSwitchDashStream:(nullable NSNumber *) immediateSwitchDashStream outputOptionalSeekFrameFirst:(nullable NSNumber *) outputOptionalSeekFrameFirst;

@end

#pragma mark Class=======INSPreviewer3
@class INSClip;
@class INSBgmSource;
@class INSPreviewer3Pos;
@class INSFileClipPos;
@interface INSPreviewer3 : NSObject
/// 用于显示的事件代理
@property (nonatomic, weak) id<INSPlayDisplay> displayDelegate;
@property (nonatomic, weak) id<INSDisplayDelegate> displayDelegate2;

/// 用于Previewer事件代理
@property (nonatomic, weak) id<INSPreviewer3Delegate> delegate;

/// 播放器当前状态
@property (nonatomic, assign, readonly) INSPreviewer3Status actionStatus;

/// 播放速率
@property (nonatomic, assign) float playRate;

/// 音量
@property (nonatomic, assign) double volume;

/// 是否将播放的音频通过回调回调出来，默认值NO
@property (nonatomic, assign) BOOL enableSendAudioSample;

/// 只解码关键帧，设置了以后可能会导致时间戳不变化，需要通过设置高帧率playRate模式来加速时钟，默认值NO
@property (nonatomic, assign) BOOL forceVideoKeyFrameOnly;

/// 播放资源视频、音频、图片、背景音乐，用于播放和导出。
@property (nonatomic, strong, readonly, nullable)NSArray<INSClip*> *videoClips;

- (long) getNetworkDataRead;
- (void) setBufferingProgressThrehold:(int) val;

/// 设置previewer3的option，函数必须在setVideoSource之后，prepareAsync之前调用
/// @param options option值， key见option key
- (void)setOptions:(NSDictionary*)options;

/// 是否开启指向收音
/// @param enable 是否使用指向收音
- (void)enableBeamFormingAlgorithm:(BOOL)enable;


/// 修改多音轨混音,第一条音轨参与混音的比值
/// @param clipindex 第几个clip的配置
/// @param weight 混音比例
- (void)setClipSourceFirstAudioTrackindex:(NSInteger)clipindex Weight:(double)weight;

///  设置播放资源
/// @param videoClips 播放资源视频
/// @param bgmSource 背景音乐资源
/// @param videoSilent 视频原声静默开关
- (void)setVideoSource:(NSArray<INSClip *> *)videoClips bgmSource:(INSBgmSource*_Nullable)bgmSource videoSilent:(BOOL)videoSilent;

///  设置播放资源
/// @param videoClips 播放资源视频
/// @param bgmSource 背景音乐资源
/// @param videoSilent 视频原声静默开关
/// @param enableBgmCache 音乐是否由下载播放转向远程播放
- (void)setVideoSource:(NSArray<INSClip *> *)videoClips bgmSource:(INSBgmSource*_Nullable)bgmSource videoSilent:(BOOL)videoSilent enableBgmCache:(BOOL)enableBgmCache;

/// 重新设置播放资源，在setVideoSource之后调用有效
/// @param videoClips 播放资源视频
/// @param bgmSource 背景音乐资源
/// @param videoSilent 视频原声静默开关
- (void)reloadAsyncWithVideoSource:(NSArray<INSClip *> *)videoClips bgmSource:(INSBgmSource*_Nullable)bgmSource videoSilent:(BOOL)videoSilent;

/// 重新设置播放资源，在setVideoSource之后调用有效
/// @param videoClips 播放资源视频
/// @param bgmSource 背景音乐资源
/// @param videoSilent 视频原声静默开关
/// @param enableBgmCache 音乐是否由下载播放转向远程播放
- (void)reloadAsyncWithVideoSource:(NSArray<INSClip *> *)videoClips bgmSource:(INSBgmSource*_Nullable)bgmSource videoSilent:(BOOL)videoSilent enableBgmCache:(BOOL)enableBgmCache;

/// 重新设置播放资源，在setVideoSource之后调用有效
/// @param videoClips 播放资源视频
/// @param bgmSource 背景音乐资源
/// @param videoSilent 视频原声静默开关
/// @param enableBgmCache 音乐是否由下载播放转向远程播放
/// @param reloadOption 重新加载配置项
- (void)reloadAsyncWithVideoSource:(NSArray<INSClip *> *)videoClips bgmSource:(INSBgmSource*_Nullable)bgmSource videoSilent:(BOOL)videoSilent enableBgmCache:(BOOL)enableBgmCache reloadOption:(INSPreviewer3ReloadOption*_Nullable)reloadOption;

/// 设置cache地址，函数必须在setVideoSource之后，prepareAsync之前调用
/// @param cacheURL cache地址
- (void)setCacheDirectory:(NSURL*)cacheURL;

/// 准备同步，设置媒体文件的同步时间戳，当播放的时候，完成了准备以后，会从这个时间点的一帧开始渲染，尽管你没有调用play方法
/// @param mediaTimeMs 时间戳
- (void)prepareAsync:(double)mediaTimeMs;

/// 是否正在playing中
/// @return YES为正在play
-(BOOL)isPlaying;

/// 播放
- (void)play;

/// 暂停
- (void)pause;

/// 停止播放，释放资源
-(void)shutdown;

/// 是否正在seeking中
/// @return YES为正在seek
-(BOOL)isSeeking;

/// seek
/// @param position 位置，单位：ms
/// @return seek的serialId，INSPreviewer3Delegate的seek回调会使用
- (int)seek:(double)position;

/// 播放下一帧
/// @param steps 向后播放的帧数
-(void)stepForward:(int)steps;

/// 播放前一帧
/// @param steps 向前播放的帧数
-(void)stepBack:(int)steps;

-(void)setDashStreamIndex:(int)index Immediately:(BOOL)immediately;

-(void)setAutoSwitchDashStream:(BOOL)enable;

// 支持相机素材和云素材混剪时的切流
- (int)selectVideoStream:(nullable INSPreviewer3PwVideoStreamOption *) insVideoStreamOption;

/// 是否优先播放副码流
/// @param isOptionalFirst true：优先播放副码流 false：优先播放主码流
/// @return 错误码，>=0且后续没有失败的notify通知，成功；<0，失败。
/// 接口需要在previewerPrepare或者previewerReloadFinish里面回调
/// !!!! 此接口内部会暂停播放，如果需要继续播放，需要手动调用play方法
- (int)setPlayOptionalFirst:(BOOL)isOptionalFirst;

/// 设置播放和seek 是否是主码流和副码流
/// @param isPlayOptionalFirst true: 优先播放副码流    false: 优先播放主码流
/// @param isSeekOptionalFirst true: 优先seek副码流   false: 优先seek主码流
/// @return 错误码，>=0且后续没有失败的notify通知，成功；<0，失败。 
/// 不能设置isPlayOptionalFirst为true 且 isSeekOptionalFirst为false
///
/// 接口需要在previewerPrepare或者previewerReloadFinish里面回调
///
/// !!!! 此接口内部会暂停播放，如果需要继续播放，需要手动调用play方法 
- (int)setPlayOptionalFirst:(BOOL)isPlayOptionalFirst OptionalSeekFrameFirst:(BOOL)isSeekOptionalFirst;

/// 使用指定的clip动态改变音量
/// @param audioType 音轨类型original or bgm
/// @param index clip索引，当audioType为original，则为clip资源的index，当audioType为bgm，则为AddBgmClip
/// @param volume 音量大小，默认1.0
-(void)setAudioVolumeType:(INSPreviewer3AudioType)audioType clipIndex:(int)index volume:(double)volume;

/// 当前播放位置
/// @return 播放位置返回,包含时间戳、视频位置、bgm位置， 内部不使用插值接口
-(INSPreviewer3Pos*)currentPositionWithoutInterpolation;

/**
 * @param duration seconds
 * @brief this interface is used to query whether previewer was playing fluently in the passed N seconds.
 *
 * @note
 *   1. call this interface when playing and not seeking, otherwise it will return invalid value.
 *   2. lastNSeconds should be greater than zero, otherwise it will return invalid value.
 *   3. if lastNSeconds exceeded actual time passed, then the fluency of actual time passed is returned.
 *   4. return value is in range[0, 1]. when closed to 1, it means current playing is fluent. return -1 when invalid
 *   5. when replay or paused. all statistics will be reset.
 *   6. when invalid value returned, you may do nothing on this query result.
 *   7. it's suggested to invoke IsPlaying() and IsSeeking() before invoke this interface.
 */
-(double) getPlayingFluencyInLastNSeconds:(int)duration;

/// 当前播放位置
/// @return 播放位置返回,包含时间戳、视频位置、bgm位置， 默认只用带有插值的方式
-(INSPreviewer3Pos*)currentPosition;

/// 当前播放位置
/// @param interpolation whether to use progress interpolation. 当传true时，与不带参数的currentPosition效果相同
/// @return 播放位置返回,包含时间戳、视频位置、bgm位置
-(INSPreviewer3Pos*)currentPosition:(BOOL)interpolation;

/// 获取总时间
/// @return 总时间
- (double)getDurationMs;

/// 获取该index的clip的起始时间
/// @return 起始时间
- (double)getClipStartCutTimeMs:(int)index;

/// 映射播放器时间戳到文件位置
/// @param mediaTime 时间戳
/// @param fileClipPos 文件位置
/// @return 成功返回YES
- (BOOL)mapMediaTimeMs:(double)mediaTime toSrcTime:(INSFileClipPos* _Nullable *_Nonnull)fileClipPos;

/// 映射文件位置到播放器时间戳
/// @param fileClipPos 文件位置
/// @param mediaTime 时间戳
/// @return 成功返回YES
- (BOOL)mapSrcTime:(INSFileClipPos*)fileClipPos toMediaTimeMs:(double*)mediaTime;

/// 在setVideoSource之后调用，设置Muxdata初始化依赖的信息  https://arashivision.feishu.cn/wiki/EqaBw3Vf0i8shRkc2XfcwGQYn6e
/// @param softwareName app名字, 默认insta360
/// @param softwareVersion app版本, 默认unknown
/// @param playerWidth app当前播放器的宽度
/// @param playerHeight app当前播放器的高度
/// @param viewerId 可以传递用户id进来
/// @param deviceModel 手机型号, 默认unknown
/// @param osFamily 操作系统类型, 默认iOS或android
/// @param osVersion 操作系统版本, 默认unknown
/// @param deviceManufacturer 设备厂商, 默认Apple(iOS), unknown(Android)
/// @param playerId 播放器实例对应的id, 默认bmg内部生成的previewerID
/// @param envKey 需要有这个key才能上传数据到mux data看板
/// @param fullscreen 当前界面是否全屏
- (void)setPwEnvData:(NSString*)softwareName softwareVersion:(NSString*)softwareVersion playerWidth:(int)playerWidth playerHeight:(int)playerHeight viewerId:(NSString*)viewerId deviceModel:(NSString*)deviceModel osFamily:(NSString*)osFamily osVersion:(NSString*)osVersion deviceManufacturer:(NSString*)deviceManufacturer playerId:(NSString*)playerId envKey:(NSString*)envKey fullscreen:(BOOL)fullscreen;

/*
 *  注意：这个接口只有在url没被访问的时候才能调用。
 *  bmg 假定上层对于所有缓存传递的cacheDir都一样，也就是所有的缓存都在一个目录里。
 *  如果上层传递的缓存目录不一样，那么需要对每个缓存目录都掉用该接口。
 */

+ (void)removeLocalCaches:(NSString*) cacheDir urls:(NSMutableArray<NSString*>*)urls;

+ (BOOL)isRebuildPreviewerErrcode:(int)errorCode;

@end

NS_ASSUME_NONNULL_END
