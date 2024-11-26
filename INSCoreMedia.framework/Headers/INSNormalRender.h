//
//  INSNormalRender.h
//  INSMediaApp
//
//  Created by pengwx on 16/7/7.
//  Copyright © 2016年 Insta360. All rights reserved.
//

#import "INSRender.h"

typedef struct {
    CGPoint center;
    CGFloat scale;
} INSNormalRenderProjection ;

typedef NS_ENUM(NSInteger, INSContentMode){
    INSContentModeScaleToFill,
    INSContentModeScaleAspectFit,
    INSContentModeScaleAspectFill,
};

typedef NS_ENUM(NSInteger, INSBackgroundMode){
    INSBackgroundModeColor,
    INSBackgroundModeBlur,
};

NS_ASSUME_NONNULL_BEGIN
@class INSCorrectResult;
@interface INSNormalRender : INSRender


/**
 默认值为INSContentModeScaleToFill
 */
@property (nonatomic) INSContentMode contentMode;

///背景填充方案，默认值INSBackgroundModeColor
@property (nonatomic) INSBackgroundMode backgroundMode;

/**
 由INSContentMode\contentWidth\contentHeight三者共同计算得出，默认 CGRectMake(0,0,renderWidth,renderHeihgt)
 如果在INSContentModeScaleAspectFit模式下，结果应该是视频主体的rect（除去蒙层，中间部分主要视频画面）
 上层通过可能需要在配置之前，获取一次这个值，而这个值应该是设置完INSContentMode\contentWidth\contentHeight才可以被确认的;
 */
@property (nonatomic, readonly) CGRect contentRect;

/**
 默认值为(0.0, 0.0, 0.0, 1.0)
 */
@property (nonatomic) GLKVector4 contentBackgroundColor;

@property (nonatomic) UIEdgeInsets contentEdgeInset;

/// 视频帧的尺寸，实际为videoFrameWidth\videoFrameHeight
@property (nonatomic) int contentWidth;
@property (nonatomic) int contentHeight;


/**
 相机的旋转方向，单位：弧度
 */
@property (nonatomic) float cameraRoll;

@property (nonatomic)INSNormalRenderProjection renderProjection;

// 默认为NO，开启后，可用projection数据调整renderProjection
@property (nonatomic) BOOL useProjectionConvertTransform;


/// 是否使用视频metadata（图片exif）中的旋转量,  默认YES
@property(nonatomic)BOOL useMetadataRotation;

/// 开启手势缩放平移，默认为false
@property(nonatomic)bool enableGesture;

/// 图片最小缩放的倍数(手势结束后，倍数小于这个值会回弹到这个值)，默认值1.0
@property(nonatomic)float minScale;

/// 图片扩展的最小缩放倍数(手势过程中，倍数不会小于这个值)，默认值0.85
@property(nonatomic)float minExpandScale;

/// 图片最大缩放的倍数(手势结束后，倍数大于这个值会回弹到这个值)，默认值5
@property(nonatomic)float maxScale;

/// 双击放大的倍数(初始状态双击)，默认值2
@property(nonatomic)float doubleClipScale;

/// 平移允许的最大黑边比例，默认0.1
@property(nonatomic)float maxEdgeRatioX;
@property(nonatomic)float maxEdgeRatioY;

/// TC2水平矫正开关
@property(nonatomic)BOOL correctSwitch;

/// 矫正旋转量
@property(nullable, nonatomic)INSCorrectResult *correctResult;

-(void) resetRenderProjection;
- (void)SetSourceTarget:(INSRenderTarget*)renderTarget;
- (void)configCorrectInfo:(BOOL)correctSwitch correctResult:(nullable INSCorrectResult*)correctResult;


@end

NS_ASSUME_NONNULL_END
