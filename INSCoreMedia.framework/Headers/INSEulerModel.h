//
//  INSEulerModel.h
//  INSCoreMedia
//
//  Created by Jormungand on 2023/3/17.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface INSEulerModel : NSObject<NSCoding, NSCopying, NSMutableCopying>

@property (nonatomic) double timestamp;
@property (nonatomic) float yFov;
@property (nonatomic) float distance;
@property (nonatomic) float pitch;
@property (nonatomic) float yaw;
@property (nonatomic) float roll;
/// 默认值为0
@property (nonatomic) int transitionMode;
@end


NS_ASSUME_NONNULL_END
