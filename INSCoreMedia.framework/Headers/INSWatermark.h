//
//  INSWatermark.h
//  INSCoreMedia
//
//  Created by pengwx on 2017/8/30.
//  Copyright © 2017年 insta360. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface INSWatermark : NSObject

/// 废弃
- (instancetype) initWithImage:(UIImage*)image rect:(CGRect)rect;

- (instancetype) initWithUrl:(NSString*)url rect:(CGRect)rect;

@property (nonatomic, strong, readonly) UIImage *image;

/// 水印图片在成片画面的位置大小，与UI坐标系相同左上为(0, 0)，右：x正方向  下：y正方向.
/// 要在渲染画幅的范围内，且width height 均要求为偶数。
@property (nonatomic, readonly) CGRect rect;

@property (nonatomic, nullable) NSString *url;


@end

NS_ASSUME_NONNULL_END
