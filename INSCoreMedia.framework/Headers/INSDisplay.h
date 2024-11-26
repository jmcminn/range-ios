//
//  INSDisplay.h
//  INSCoreMedia
//
//  Created by pengwx on 2019/11/22.
//  Copyright © 2019 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INSDisplayStyle){
    INSDisplayStyleSuper,
    INSDisplayStyleLinear,
    INSDisplayStyleWide,
    INSDisplayStyleNarrow,
    INSDisplayStyleTinyPlanet,
    INSDisplayStyleCustom,
    INSDisplayStyleSuperPlus,
    INSDisplayStyleSuperPerspective,
    INSDisplayStyleWidePerspective,
    INSDisplayStyleLinearPlus,
    INSDisplayStyleLinearHorizontal,
    INSDisplayStyleLinearHorizontalWider,
    INSDisplayStyleFpv,
    INSDisplayStyleMaxView,
    INSDisplayStyleLinearhorizon360,
    INSDisplayStyleDewarp,
    INSDisplayStyleMegaView,
};

typedef NS_ENUM(NSInteger, INSDisplayAspect){
    INSDisplayAspect1x1,
    INSDisplayAspect16x9,
    INSDisplayAspect9x16,
    INSDisplayAspect4x3,
    INSDisplayAspect235x100,
    INSDisplayAspect3x2,
    INSDisplayAspect2x3,
    INSDisplayAspect3x4,
    INSDisplayAspectXpan,
    INSDisplayAspect100x235,
    INSDisplayAspectYpan,
};


@interface INSDisplay : NSObject<NSCoding, NSCopying, NSMutableCopying>

@property(nonatomic)INSDisplayStyle style;
@property(nonatomic)INSDisplayAspect aspect;
/// 默认是false
/// 需求变更，去掉了display style里面custom档位
/// 需要有一个额外的字段来区分是某个档位下的自定义
/// 此字段是iOS程序员来进行维护
/// 比如 INSDisplayStyleSuper: custom，表示super下面的custom
@property(nonatomic) bool custom;
@property(nonatomic, readonly) float aspectRadio;

-(instancetype)initWithDisplayStyle:(INSDisplayStyle)style aspect:(INSDisplayAspect)aspect;

-(instancetype)initWithDisplayStyle:(INSDisplayStyle)style aspect:(INSDisplayAspect)aspect custom:(bool)custom;

-(BOOL)isEqualDisplay:(INSDisplay*)display;

+(float)transformAspect:(INSDisplayAspect)aspect;

+(INSDisplayAspect)aspectTransform:(float)aspect;

+(INSDisplayStyle) getDisplayStyle:(int)deeptrackDisplayStyle;
@end


NS_ASSUME_NONNULL_END
