//
//  INSThumbNailParser.h
//  INSCoreMedia
//
//  Created by 谷瑾之 on 2023/3/29.
//  Copyright © 2023 insta360. All rights reserved.
//
#ifndef INSThumbNailParser_h
#define INSThumbNailParser_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface INSThumbNailParser : NSObject
@property (nonatomic) NSData * thumbdata;

- (instancetype) initWithThumbData: (NSData * _Nullable)thumbData;
- (CVPixelBufferRef _Nullable) ParseThumNail;
- (void) exportThumbNail;
@end
NS_ASSUME_NONNULL_END
#endif /* INSThumbNailParser_h */

