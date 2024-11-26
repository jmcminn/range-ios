//
//  INSExporterInfo.h
//  INSCoreMedia
//
//  Created by pengwx on 2018/7/18.
//  Copyright © 2018年 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSSingleHDRInfo.h"



typedef NS_ENUM(NSInteger, INSExporterVideoType){
    INSExporterVideoTypeNormolMP4,      //导出正常的视频
    INSExporterVideoTypeFragmentMP4,    //可以边导出边上传
};


NS_ASSUME_NONNULL_BEGIN

@class INSMetadata;
@class INSRational;
@class INSTimeRange;
@class INSExporterLog;
@class INSBlockDenoiseDataGenerator;
@class INSChromaDenoiseParam;
@interface INSExporterInfo : NSObject

@property (nonatomic, strong) NSURL *url;
@property (nonatomic) NSInteger videoWidth;
@property (nonatomic) NSInteger videoHeight;
@property (nonatomic) NSInteger bitrate;
@property (nonatomic) NSInteger fps;

/**
 导出视频帧率，如果配置了此属性，fps属性将会失效，默认为nil
 */
@property (nonatomic, strong, nullable) INSRational *priorityFps;

/**
 默认值:INSExporterVideoTypeNormolMP4
 */
@property (nonatomic) INSExporterVideoType videoType;

/**
 配置x264编码的preset， 可以为"veryfast", "fast", 默认nil
 */
@property (nonatomic, strong, nullable) NSString *preset;

/**
 配置video profile设置, 可以为"baseline", 默认nil
 */
@property (nonatomic, strong, nullable) NSString *videoProfile;

/**
 配置video tune设置, 可以为"zerolatency", 默认nil
 */
@property (nonatomic, strong, nullable) NSString *videoTune;

/**
 视频的metadata数据
 */
@property (nonatomic, strong) INSMetadata *metadata;

/**
 配置是否使用软编码, 默认为NO
 */
@property (nonatomic, assign) BOOL useX264Encoder;


/// 使用h265编码， 默认NO
@property(nonatomic)BOOL enableH265Encoder;

/**
 兼容相册
 */
@property (nonatomic, readonly) BOOL needCompatibleAlbum;


/**
 末尾是否进行回放, 默认值NO
 */
@property (nonatomic) BOOL isTurnBack;


/// 导出视频是否为j经纬图全景
@property (nonatomic) BOOL isSpherical;


/**
 motion blur,  默认YES
 */
@property (nonatomic) BOOL enableMotionBlur;

/// 应用motionblur的时间范围，为nil时表示所有范围都应用
@property (nonatomic, strong, nullable)NSArray<INSTimeRange*> *motionBlurTimeRanges;

/**
 是否开启sequence降噪，默认NO
 */
@property (nonatomic) BOOL enableDenoise;

/**
 是否开启block降噪，默认NO
 */
@property (nonatomic) BOOL enableBlockDenoise;

@property (nullable, nonatomic, strong) INSChromaDenoiseParam *chromaDenoiseParam; //彩噪开关参数，当不开启彩噪优化时为 nil

//@property (nonatomic) BOOL enhanceChromaDenoise;

@property (nullable, nonatomic, strong) INSBlockDenoiseDataGenerator *blockDenoiseDataGenerator;

/// 降噪级别，默认3.0，，值设置范围0-15.0,   当enableDenoise为YES生效
@property (nonatomic) float denoiseLevel;

/// 是否开启super night，默认NO
@property (nonatomic) BOOL enableSuperNight;

//超级夜景降噪水平  默认值 3.0
@property (nonatomic)float superNightNoiseLevel;

/// 是否开启卡通漫画效果，默认NO
/// Deprecated at 2022.12.22,  设置无效
@property (nonatomic)BOOL enableCartoon DEPRECATED_MSG_ATTRIBUTE("Please use INSOffscreenRender.render.enableCartoon.");;

/// 是否开启水下色彩还原，默认nil
@property (nonatomic, strong, nullable)INSUnderwaterInfo *underwaterInfo;

/**
 转场的缓存数据的存储地址
 */
@property (nonatomic) NSURL *cacheBaseUrl;


/**
 水印结束时间，包括此时间点 double
 */
@property (nonatomic, strong, nullable) NSNumber *watermarkEndTime;

///设置为YES时，慢速插帧时采用复制相同帧的方式来处理, 默认值NO
@property (nonatomic) BOOL enableTimeScaleCopySameFrame;

/// 是否启用全景声, 默认NO
@property (nonatomic) BOOL enableSpatialAudio;

@property (nonatomic, strong)INSExporterLog *exporterLog;

/// 是否强制丢帧，默认NO，只要不是相机标准帧率素材都建议设置为YES（只在播放页无trim导出时生效）
@property (nonatomic) BOOL forceDiscardFrame;

@end


NS_ASSUME_NONNULL_END
