//
//  INSImageFusion.h
//  INSCoreMedia
//
//  Created by fwx on 2023/8/4
//


#import <UIKit/UIKit.h>
#import "INSCoreMediaSDK.h"

NS_ASSUME_NONNULL_BEGIN

@interface INSImageFusion : NSObject

- (UIImage*) fusionImage:(UIImage*)image andMask:(UIImage*)mask;

@end

NS_ASSUME_NONNULL_END
