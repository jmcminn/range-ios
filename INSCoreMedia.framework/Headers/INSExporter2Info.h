//
//  INSExporter2Info.h
//  INSCoreMedia
//
//  Created by 那强 on 2023/1/5.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class INSBlockDenoiseDataGenerator;
@class INSSequenceDenoiseDataGenerator;
@class INSWatermark;
typedef NS_ENUM(NSInteger, INSExporter2VideoType) {
    INSExporter2VideoTypeNormolMP4 = 0,
    INSExporter2VideoTypeFragmentMP4 = 1,
};

typedef NS_ENUM(NSInteger, INSExporter2AudioChanelLayout) {
    INSExporter2AudioChanelLayoutMono = 0,
    INSExporter2AudioChanelLayoutStereo = 1,
};

typedef NS_ENUM(NSInteger, INSExporter2PixelFormat) {
    INSExporter2PixelFormatBGRA = 0,
    INSExporter2PixelFormatNV12 = 1,
};

typedef NS_ENUM(NSInteger, INSExporter2FileType) {
    INSExporter2FileTypeMP4 = 0,
    INSExporter2FileTypeMJPEG = 1,
};

#pragma - mark Video X264 Option
@interface INSExporter2X264EncodeConfiguration : NSObject

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
 * baseline: 41 , high: 50, default is 41
 */
@property (nonatomic) int videoLevel;

@end

#pragma - mark Video Encode Option
@interface INSExporter2VideoEncodeOption : NSObject

/**
 * output frame's pixel format default INSExporter2PixelFormatBGRA
 */
@property (nonatomic) INSExporter2PixelFormat pixelFormat;

/**
 * "mp4" or "mjpeg", default is "mp4"
 */
@property (nonatomic) INSExporter2FileType fileType;

@property (nonatomic) INSExporter2VideoType videoType;




/**
 *
 */
@property (nonatomic) NSInteger videoWidth;

/**
 *
 */
@property (nonatomic) NSInteger videoHeight;

/**
 *
 */
@property (nonatomic) NSInteger bitrate;


/**
 * 默认为-1，暂时无需设置
 */
@property (nonatomic) NSInteger videoGopSize;

/**
 * default is 0.0
 * ** 不能设置为大于原视频分辨率的值**， 如下情况单独说明
 * 1. 原视频 24\25\29.97 fps，导出30fps： 支持
 * 2. 原视频 24\25\30 fps，导出60fps：不支持
 * 3. 向下导出支持
 */
@property (nonatomic) double fps;


///avstream meta input
/**
 * default is NO
 * Or If the render you use in INSRenderExporter is kindOfClass INSFlatPanoOffscreenRender, also set this to true.
 */
@property (nonatomic) BOOL isSpherical;

/**
 * 兼容相册，目前内部使用vEncOpt.width 与 vEncOpt.height来直接给导出库赋值
 */
@property (nonatomic) BOOL needCompatibleAlbum DEPRECATED_MSG_ATTRIBUTE("A property settled by SDK itself, depending on output dimension.");

/**
 * 兼容相册，由app完全设置，ios在2k的时候也可能导入相册失败
 */
@property (nonatomic) BOOL iOS_forceCompatibleAlbum;

/**
 * 是否开启全景声, 默认为NO
 */
@property (nonatomic) BOOL enableSpatialAudio;

/**
 * muxer metadata
 */
@property (nonatomic, nullable) NSString *metadataMake;

@property (nonatomic, nullable) NSString *metadataModel;
/// sourceVideoCreateTime
@property (nonatomic, nullable) NSString *metadataComment;

/**
 * 是否开启杜比视界, 默认为NO
 */
@property (nonatomic) BOOL enableSdrToHdr10;

/**
 * set only when sw encode. 编码的配置，默认为nil，如果需要开【软】编码，则进行配置
 */
@property (nonatomic, nullable) INSExporter2X264EncodeConfiguration *x264EncodeConfiguration;

@end



@interface INSExporter2AudioEncodeOption : NSObject

/// 128 * 1000
@property (nonatomic) int audioBitrate;

/// 48000
@property (nonatomic) int sampleRate;

/// 1024
@property (nonatomic) int nbSample;

/// INSExporter2AudioChanelLayoutMono
@property (nonatomic) INSExporter2AudioChanelLayout channelLayout;

@end

typedef INSBlockDenoiseDataGenerator * _Nullable (^BlockDenoiseUpdateBlk) (const int clipIndex);

typedef INSSequenceDenoiseDataGenerator * _Nullable (^SequenceDenoiseUpdateBlk) (const int clipIndex);

@interface INSExporter2DenoiseConfiguration : NSObject

/// 不配置，则不会生效，如果两种都配置，则优先使用block Denoise
@property (nonatomic, nullable) BlockDenoiseUpdateBlk blockDenoiseUpdateBlk;

/// 不配置，则不会生效
@property (nonatomic, nullable) SequenceDenoiseUpdateBlk sequenceDenoiseUpdateBlk;

@end

@interface INSExporter2WatermarkInfo : NSObject

// 水印信息，和旧版导出在INSOffscreenRender中配置的信息一样，虽然这里设置了，但是目前仍然需要配置INSOffscreenRender.watermark
@property (nonatomic) INSWatermark *waterMark;

// 水印结束时间，media time, 默认为nil, 代表整段生效, 单位ms.
@property (nonatomic, nullable) NSNumber *endTime;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithWaterMark:(INSWatermark *)waterMark endTime:(NSNumber  * _Nullable)endTime;

@end



@interface INSExporter2Info : NSObject

/**
 * 导出视频目标地址
 */
@property (nonatomic, strong) NSURL *url;

/**
 * 转场的缓存数据的存储地址
 */
@property (nonatomic) NSURL *cacheBaseUrl;

/**
 * 暂时不支持
 */
@property (nonatomic) BOOL isTurnBack;

/**
 * Assign the same value with _enableforceFps in INSExporterInfo.
 * Meanwhile, if you use INSProjectExporter before, also set this to YES
 *
 * 1 normally isProject true , output fps is 30fps
 * 2 all clip in project 25fps and app want to export 25fps, for all clips framerate is same as export fps, we keep output 25fps even if project
 * 3 clips in project had both 25fps and 30fps, if app set export 25fps, we fix it 30fps
 */
@property (nonatomic) BOOL isProject;

/**
 * 解码阶段是否为软解，默认为NO，表示使用硬解原始视频
 */
@property (nonatomic) BOOL enableX264Decoder;

/**
 * default is 1.0
 */
@property (nonatomic) double outputAudioAfadeOutDuration;


/**
 * must be set
 */
@property (nonatomic) INSExporter2VideoEncodeOption *vEncOpt;

/**
 * set when need audio output
 */
@property (nonatomic) INSExporter2AudioEncodeOption *aEncOpt;

@property (nonatomic, assign) BOOL enhanceChromaDenoise;

//        //meaningful when you use default frame mapper {@link DefaultFrameMapper2} that you haven't set SetFrameInsertFrameMapper
//        ExMatColorType2 frameInsertColorType_ = ExMatColorType2::YUV_I420;
//        //meaningful when you use default frame mapper{@link DefaultFrameMapper2} that you haven't set SetFreezeFrameMapper
//        ExMatColorType2 freezeColorType = ExMatColorType2::YUV_I420;
//        //meaningful when you need use default frame mapper {@link DefaultFrameMapper2} that you haven't set SetBlockDenoiseMapper
//        ExMatColorType2 denoiseType = ExMatColorType2::YUV_I420;
//        struct ThreadInfo
//        {
//            int originalFrameInsertQueue = 1;
//            int originalFrameRepeatQueue = 1;
//            int videoRenderFilterQueue = 1;
//            int renderFrameInsertQueue = 1;
//            int denoiseQueue = 1;
//            int writeFilterQueue = 1;
//        };


// Just like INSWatermark info you set for INSOffscreenRender
@property (nonatomic, nullable) INSExporter2WatermarkInfo *waterMarkInfo;
        
// Just like INSOffscreenRender.edgeInsets
@property (nonatomic) UIEdgeInsets edgeInsets;

/**
 * set when need non-spherical frame insert
 */
//std::shared_ptr<EdgeInsets2> edge = nullptr;

//        ThreadInfo threadInfo_;

/**
 * true when you want to decode async with cache size. default is NO
 */
@property (nonatomic) BOOL asyncDecode;

/**
 * true when Meishe Workaround
 */
@property (nonatomic) BOOL iosMeisheWorkaround;


/**
 * Either sequenceDenoise or blockDenoise is needed, set this to YES and config detail in INSRenderExporter2SessionDelegate, default is NO.
 */
@property (nonatomic, nullable) INSExporter2DenoiseConfiguration *denoiseConfiguration;



/**
 * default is 2
 */
@property (nonatomic) int beamformLevel;


@property (nonatomic) BOOL enableDashBoardReduceFramerate;

@property (nonatomic) BOOL hasPlanePostRender;



@end





NS_ASSUME_NONNULL_END
