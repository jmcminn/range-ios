//
//  INSTimeScaleUtil.h
//  INSCoreMedia
//
//  Created by FrozenAil on 2023/12/19.
//  Copyright © 2023 insta360. All rights reserved.
//

#ifndef TimeScaleUtil_h
#define TimeScaleUtil_h

#import <Foundation/Foundation.h>

@interface INSTimeScaleUtil : NSObject

+ (BOOL)fpsEqual:(double)a to:(double)b;

+ (BOOL)notEqual:(double)a to:(double)b;

+ (BOOL)equal:(double)a to:(double)b;

+ (BOOL)greateEqual:(double)a to:(double)b;

+ (BOOL)greate:(double)a to:(double)b;

+ (BOOL)less:(double)a to:(double)b;

+ (BOOL)lessEqual:(double)a to:(double)b;

+ (double)exporterFpsScaleCalculate:(double)inputFps to:(double)outputFps;

@end


#endif /* TimeScaleUtil_h */
