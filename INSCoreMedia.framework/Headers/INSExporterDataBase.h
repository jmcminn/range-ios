//
//  INSExporterDataBase.h
//  INSCoreMedia
//
//  Created by 那强 on 2023/1/6.
//  Copyright © 2023 insta360. All rights reserved.
//

#import "INSExporterInfo.h"
#import "INSProjectionConverter.h"
#import "INSMediaAAA.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class INSMediaAAA;
@class INSFramePtsPlayer;

@interface INSBlockDenoiseParamMapping : NSObject
@property(nonatomic) double iso;
@property(nonatomic) int refNum;
@property(nonatomic) int thresholdLum;
@property(nonatomic) int limit;
- (instancetype)initWithISO:(double)iso refNum:(int)refNum thresholdLum:(int)thresholdLum limit:(int)limit;
@end

// 彩噪优化开关参数类
@interface INSChromaDenoiseParam : NSObject

- (instancetype) initWithApplyISOValue:(float) applyISOValue andExitISOValue:(float)exitISOValue;

// 开启彩噪优化的 ISO 值
@property (nonatomic) float applyISOValue;

// 关闭彩噪优化的 ISO 值
@property (nonatomic) float exitISOValue;

@end

@interface INSBlockDenoiseDataGenerator : NSObject
// 各类视频公用参数
@property (nullable, nonatomic, strong) NSArray<INSMediaAAA *> *aaaArray;                   // 固件系统时间->ISO，可从[INSVideoInfoParser.extraInfo.aaaData.aaaArray]获取
@property (nonatomic) NSArray<INSBlockDenoiseParamMapping *> *blockDenoiseParamMappings;    // ISO->降噪参数，即产品确定的档位
// 以下参数用于延时视频（或其他固件系统时间戳与解码时间戳不匹配的视频），普通视频不必设置
@property (nullable, nonatomic, strong) INSFramePtsPlayer *framePtsPlayer;   // 解码时间戳->固件系统时间戳，可从[INSVideoInfoParser.extraInfo.highLightData.framePtsPlayer]获取

@property (nullable, nonatomic, strong) INSChromaDenoiseParam *chromaDenoiseParam; //彩噪开关参数，当不开启彩噪优化时为 nil

@end

@interface INSSequenceDenoiseDataGenerator : NSObject

@property (nonatomic) float level;

@end

@interface INSExporterDataBase : NSObject

@end

NS_ASSUME_NONNULL_END
