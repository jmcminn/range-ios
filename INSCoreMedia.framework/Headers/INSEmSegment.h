//
//  INSEmSegment.h
//  INSCoreMedia
//
//  Created by HFY on 2020/12/26.
//  Copyright © 2020 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 即，一个5.7K的循环录影文件，一个INSEmSegment足够表达单个片段的两路数据；这和bmg定义的是有区别的：bmg的文档定义，一个segment 只表示一个文件
@interface INSEmSegment : NSObject<NSCoding, NSCopying, NSMutableCopying>

-(instancetype)init NS_UNAVAILABLE;
-(instancetype)initWithUrl:(NSArray<NSURL*>*)urls totalSrcDurationMs:(double)totalSrcDurationMs isValid:(BOOL)isValid;

@property(nonatomic, strong)NSArray<NSURL*> *urls;
@property(nonatomic)double totalSrcDurationMs;
@property(nonatomic)BOOL isValid;

@end


typedef struct{
    int index;
    double srcTimeMS;
} ins_em_seg;

@interface INSEmPlayList : NSObject

-(instancetype)init NS_UNAVAILABLE;
-(instancetype)initWithEmSegments:(NSArray<INSEmSegment*>*)emSegments;

@property(nonatomic, strong)NSArray<INSEmSegment*>* emSegments;

-(BOOL)mapClipSrcTime:(double)clipSrcTimeMs toSegmentSrcTime:(ins_em_seg*)segSrcTimeMs;
-(BOOL)mapSegmentSrcTime:(ins_em_seg)segSrcTimeMs toClipSrcTime:(double*)clipSrcTimeMs;
- (ins_em_seg)getLastIdxTimes;
@end

NS_ASSUME_NONNULL_END
