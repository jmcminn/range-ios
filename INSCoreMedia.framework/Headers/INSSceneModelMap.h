//
// Created by wenxing fan on 2023/6/16
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INSSceneType) {
    INSSceneTypeFlashingGraffiti = 0,       // 光电涂鸦小程序
    INSSceneTypeRoadFlow = 1,               // 马路延时小程序
    INSSceneTypeRacingGame = 2,             // 赛车游戏小程序
    INSSceneTypePanoSkySegmentation = 3,    // 天空分割（全景）小程序
    INSSceneTypeSimilarityCut = 4,          // 匹配转场小程序
    INSSceneTypeShadowClone = 5,            // 移动分身小程序
    INSSceneTypeFlyLapse = 6,               // 穿梭延时小程序
    INSSceneTypeCineLapse = 7,              // 穿梭延时串烧小程序
    INSSceneTypeMoveScene = 8,              // 移形换影小程序
    INSSceneTypeStopMotion = 9,             // 定格动画小程序
    INSSceneTypeStopMotionTwo = 10,         // 定格动画串烧小程序
    INSSceneTypeSplitJump = 11,             // 穿梭跳小程序
    INSSceneTypeTimeShift = 12,             // AI移动延时小程序
    INSSceneTypeStopMotionStand = 13,       // 人偶定格动画小程序
    INSSceneTypePhotoBigBoom = 100,         // 图片大爆炸
    INSSceneTypeVideoBigBoom = 101,         // 视频大爆炸
    INSSceneTypeFLOWNormal = 102,           // FLOW常规场景
    INSSceneTypeFLOWPackage = 103,          // FLOW模型包下载场景
    INSSceneTypeAutoPanoCut = 104,          // 全景自动剪辑
    INSSceneTypeAutoPanoCut_MONTAG = 105,   // montage wav
};

@interface INSSingleModel : NSObject

@property (nonatomic) unsigned int memory;                         // 内存
@property (nonatomic) NSString* name;                              // 最新模型名称
@property (nonatomic) NSString* compatibleName;                    // 兼容模型名称

@end

@interface INSModelInfo : NSObject

@property (nonatomic) int modelID;                                      // 模型 ID
@property (nonatomic, strong) INSSingleModel* __nullable mnnModel;      // mnn 模型
@property (nonatomic, strong) INSSingleModel* __nullable coremlModel;   // coreml 模型

@end

@interface INSModelIDPath : NSObject

@property (nonatomic) int modelID;                               // 模型 ID
@property (nonatomic) NSString* modelPath;                       // 模型路径，路径的格式需为绝对路径 “***/***/abc.ins”，路径的最后保证无 "/"

@end

@interface INSSceneModelMatcher : NSObject

- (NSArray<INSModelInfo*>*) getModelInfo:(INSSceneType) sceneType;

@end

NS_ASSUME_NONNULL_END



