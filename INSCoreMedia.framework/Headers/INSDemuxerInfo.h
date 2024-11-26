//
//  INSDemuxerInfo.h
//  INSCoreMedia
//
//  Created by Moonstar on 2023/8/3.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, INSVideoAssetColorSpace) {
    INSVideoAssetColorSpaceUnknown = 0,
    INSVideoAssetColorSpaceBT601,
    INSVideoAssetColorSpaceBT709,
};

typedef NS_ENUM(NSUInteger, INSVideoAssetColorRange) {
    INSVideoAssetColorRangeUnknown = 0,
    INSVideoAssetColorRangeFull,
    INSVideoAssetColorRangeVideo,
};

typedef NS_ENUM(NSUInteger, INSVideoAssetCodecType) {
    INSVideoAssetCodecTypeUnknown = 0,
	INSVideoAssetCodecTypeH264,
	INSVideoAssetCodecTypeH265,
	INSVideoAssetCodecTypeAac,
	INSVideoAssetCodecTypeProres,
	INSVideoAssetCodecTypeMp3,
};

@interface INSDemuxerInfo : NSObject

@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;

@property (nonatomic) NSInteger audioTrackCount;
@property (nonatomic) NSInteger videoTrackCount;

@property (nonatomic) double videoDurationS;
@property (nonatomic) double videoRotation;
@property (nonatomic) double framerate;
@property (nonatomic) double realFramate;
@property (nonatomic) double bitrate;

@property (nonatomic) BOOL isExistAudio;
@property (nonatomic) BOOL isSpatialAudio;
@property (nonatomic) BOOL isSpherical;

@property (nonatomic) INSVideoAssetColorSpace colorSpace;
@property (nonatomic) INSVideoAssetColorRange colorRange;
@property (nonatomic) INSVideoAssetCodecType codecType;

@end




NS_ASSUME_NONNULL_END
