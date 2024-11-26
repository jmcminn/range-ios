//
//  INSStitchingInfo.h
//  INSCoreMedia
//
//  Created by HFY on 2021/1/12.
//  Copyright © 2021 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, INSColdShoeMode){
    INSColdShoeModeNone = 0,
    INSColdShoeModeOpen = 1 ,
    INSColdShoeModeLeft = 2,
    INSColdShoeModeRight = 3,
};

// 拼接类型
typedef NS_ENUM(NSInteger, INSStitchType){
    INSStitchTypeNone,
    INSStitchTypeDynamic,
    INSStitchTypeDisflow,
    INSStitchTypeAiflow,
};

typedef NS_ENUM(NSInteger, INSCropMode) {
    INSCropNomalMode = 0,  //普通模式
    INSCropMeMode = 1,     //自拍模式
    INSCropTorchMode = 2,  //反向跟拍模式
};
// 0代表低精度，1代表中精度，2代表高精度，当前AI底部高精度需求仅需要1
typedef NS_ENUM(NSInteger, INSAIBottomPrecision) {
    INSAIBottomPrecisionLow = 0,
    INSAIBottomPrecisionMiddle = 1,
    INSAIBottomPrecisionHigh = 2,
};

NS_ASSUME_NONNULL_BEGIN

@interface INSStitchingInfo : NSObject


/// 冷靴模式，默认值INSColdShoeModeNone
@property(nonatomic)INSColdShoeMode coldShoeMode;

/// 竖拍电视，默认值NO
@property(nonatomic)BOOL standUpBattery;

/// X3子弹时间 默认值NO
@property(nonatomic)BOOL bulletTimeVideo;

/// X3自拍模式 默认值NO
@property(nonatomic)BOOL selfVideo4k;

/// 自拍模式
@property(nonatomic)INSCropMode cropMode;

// 独立曝光
@property(nonatomic)BOOL enableIndependentExposure;

/// 散热壳
@property(nonatomic)BOOL coolingCase;

/// 消黑边算法属性 范围限制X3 X3所有机型 设置为true
@property (nonatomic) BOOL usingFisheyeMask;

@property (nonatomic) BOOL dynamicAlphaFlag;

/// AI模型
@property (nonatomic) NSString* aiModelPath;

/// AI底部光流精度
@property (nonatomic) INSAIBottomPrecision aIBottomPrecision;

/// 近景拼缝波动优化
@property (nonatomic) BOOL expandFlowWorkRegion;

-(BOOL)isEqualInfo:(INSStitchingInfo*)info;



@end

NS_ASSUME_NONNULL_END
