//
//  INSExtraEditorData.h
//  INSCoreMedia
//
//  Created by 谷瑾之 on 2023/4/17.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//typedef NS_ENUM(NSInteger, INSEditorV3Module) {
//    EDITOR_V3_ANIMAL = 0,  // 动物检测
//    EDITOR_V3_BABY,  // 婴儿检测
//    EDITOR_V3_MOTION,  // 人脸检测
//    EDITOR_V3_EMOTION,  // 表情识别
//    EDITOR_V3_FACE, // 人脸检测
//    EDITOR_V3_HIGHLIGHT,  // highlight
//    EDITOR_V3_OCCLUSION,  // 遮挡分类
//    EDITOR_V3_PERSON,  // 人体检测
//    EDITOR_V3_RELIC,  // 美学评估
//    EDITOR_V3_DOING,  // 动作识别
//    EDITOR_V3_POV, // 姿态识别
//    EDITOR_V3_PLACES,  // 场景识别
//    EDITOR_V3_VAD, // 音频识别
//    EDITOR_V3_DEDUP_FEATURE,  // 特征值
//    EDITOR_V3_MODULE_NUM = 14,
//};
//
//#pragma mark - 自动剪辑字段对应的结构体
@class INSForwardData;
@class INSStabilizer;


struct VideoInfo {
    int frame_count;
    float fps;
    int width;
    int height;
};
typedef NS_ENUM(NSInteger, INSAutoClipAnalyseMode) {
    INSAutoClipAnalyseModeNORMAL = 0,
    INSAutoClipAnalyseModeLOOP = 1,       //循环录影
    INSAutoClipAnalyseModePRE = 2,        //预录
};

@interface INSExtraEditorData : NSObject

@property (nonatomic) struct VideoInfo videoInfo;

@property (nonatomic, nullable, strong) NSData* editorData;

@property (nonatomic, assign) NSInteger editorSize;

@property (nonatomic, assign) NSInteger seqDiff;

@property (nonatomic) INSAutoClipAnalyseMode autoClipAnalyseMode;

@property (nonatomic) NSString* videoName;

/**
 * 全景剪辑参数
 */

@property (nonatomic) NSString* timeInfo;
@property (nonatomic) INSForwardData* forwardData;
@property (nonatomic) INSStabilizer* stabilize;

@property (nonatomic) BOOL isDebug;
@property (nonatomic) NSString * debugPath;

- (instancetype) initWithEditorData:(NSData*)editorData editorSize:(NSInteger)editorSize;
- (instancetype) initWithEditorData:(NSData*)editorData editorSize:(NSInteger)editorSize videoInfo:(struct VideoInfo)videoInfo;
- (instancetype) initWithEditorData:(NSData*)editorData editorSize:(NSInteger)editorSize videoInfo:(struct VideoInfo)videoInfo videoName:(NSString*)videoName;
//@property (nonatomic, assign) int64_t seq;  // 帧序号
//@property (nonatomic, assign) int64_t pts;  // 帧时间戳
//@property (nonatomic, assign) NSArray<NSNumber*>* vaild;   // 各模块有效标志 int32_t
//@property (nonatomic, assign) NSArray<NSNumber*>* frame_id;   // 各模块内部帧号 int32_t
//@property (nonatomic, strong) NSArray <NSNumber*>* score;  // 各模块分数 float
//@property (nonatomic, strong, nullable) NSArray <NSNumber*>* feature;   // 特征值 float
//
//- (void)parseBufferToEditorData:(uint8_t*)transBuffer featureIdentification:(BOOL*)featureSign;

@end

NS_ASSUME_NONNULL_END


