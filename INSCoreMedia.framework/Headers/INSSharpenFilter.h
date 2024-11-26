//
//  INSSharpenFilter.h
//  INSCoreMedia
//
//  Created by pengwx on 2018/3/21.
//  Copyright © 2018年 insta360. All rights reserved.
//

#import "INSFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface INSSharpenFilter : INSFilter
{
    GLint sharpnessUniform;
    GLint imageWidthFactorUniform, imageHeightFactorUniform;
}

// Sharpness ranges from -4.0 to 4.0, with 0.0 as the normal level
@property(readwrite, nonatomic) CGFloat sharpness; 

@end

NS_ASSUME_NONNULL_END
