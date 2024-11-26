//
//  INSVideoTimePicker.h
//  INSCoreMedia
//
//  Created by HFY on 2020/1/13.
//  Copyright © 2020 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@class INSTimeScale;
@class INSEmSegment;
@class INSIdxTimed;
@interface INSVideoTimePicker : NSObject

-(instancetype)init NS_UNAVAILABLE;

/// 初始化对象
/// @param url 文件URL
-(instancetype)initWithURL:(NSURL*)url;

-(instancetype) initWithEmSegments:(NSArray<INSEmSegment*>*)emSegments;

/// if you need to set the open framerate, you MUST call this BEFORE open;
/// 设置计算time序列的逻辑帧率，比如需要导出为30fps的视频，则这里设置为30;
/// NOTE: 不是只原始视频的帧率，如原始视频帧率是120fps，但是需要导出为30fps的视频，则这里设置为30
-(void)setExporterFrameRate:(double)exporterFrameRate;

/// demux操作，成功返回nil，错误返回error
-(NSError*_Nullable)open;



/// 取得视频所有帧的时间戳, double
-(NSArray<NSNumber*>*)getAllRawFrameTime;


/// 取得导出时有效的视频帧的时间戳,double
/// @param startTime 导出视频起始时间
/// @param endTime 导出视频结束时间
/// @param timeScales 加速段落
-(NSArray<NSNumber*>*)getExportRawFrameTimeWithStartTimeMs:(double)startTime endTimeMs:(double)endTime timeScales:(NSArray<INSTimeScale*>* _Nullable)timeScales DEPRECATED_MSG_ATTRIBUTE("Please use INSFrameTimePicker");

/// 取得预览时有效的视频帧的时间戳, double
/// @param startTime 导出视频起始时间
/// @param endTime 导出视频结束时间
/// @param timeScales 加速段落
-(NSArray<NSNumber*>*)getPreviewRawFrameTimeWithStartTimeMs:(double)startTime endTimeMs:(double)endTime timeScales:(NSArray<INSTimeScale*>* _Nullable)timeScales DEPRECATED_MSG_ATTRIBUTE("Please use INSFrameTimePicker");

/// @warning 这个接口没有办法很好地传输循环录影文件，使用getExporter2SegmentIdxTimeWithPath，或者使用INSFrameTimePicker中的接口
+(NSArray<NSNumber*>*)getExporter2RawFrameTimeWithURL:(NSURL *)url
                                          startTimeMs:(double)startTimeMs
                                            endTimeMs:(double)endTimeMs
                                   totalSrcDurationMs:(double)totalSrcDurationMs
                                            framerate:(double)frameRate
                                        realFramerate:(double)realFrameRate
                                      exportOutputFps:(double)exportOutputFps
                                           timeScales:(NSArray<INSTimeScale *>* _Nullable)timeScales
                                   keepMotionBlurTime:(BOOL)keepMotionBlurTime DEPRECATED_MSG_ATTRIBUTE("Please use INSFrameTimePicker");;



/// 取得预览时有效的视频帧的时间戳, double
/// @param path /// 以字符串的init方法为主，依照底层接口形式，path支持三种形态：
/// 1. 视频文件的地址
/// 2. 循环录影文件的emu json文件地址
/// 3. 循环录影文件的emu json 字符串
/// @param startTime 起始时间
/// @param endTime 结束时间
/// @param timeScales 加速段落
+(NSArray<INSIdxTimed *> *)getPreviewSegmentIdxTimeWithWithPath:(NSString *)path
                                                    startTimeMs:(double)startTime
                                                      endTimeMs:(double)endTime
                                             totalSrcDurationMs:(double)totalSrcDurationMs
                                                      framerate:(double)frameRate
                                                     timeScales:(NSArray<INSTimeScale*>* _Nullable)timeScales DEPRECATED_MSG_ATTRIBUTE("Please use INSFrameTimePicker");



+(NSArray<INSIdxTimed *> *)getExporter2SegmentIdxTimeWithPath:(NSString *)path
                                          startTimeMs:(double)startTimeMs
                                            endTimeMs:(double)endTimeMs
                                   totalSrcDurationMs:(double)totalSrcDurationMs
                                            framerate:(double)frameRate
                                        realFramerate:(double)realFrameRate
                                      exportOutputFps:(double)exportOutputFps
                                           timeScales:(NSArray<INSTimeScale *>* _Nullable)timeScales
                                   keepMotionBlurTime:(BOOL)keepMotionBlurTime DEPRECATED_MSG_ATTRIBUTE("Please use INSFrameTimePicker");


+(double)getExactExportFps:(NSArray<NSNumber *>* _Nullable)allClipFps_
                 exportFps:(int)exportFps
                 isProject:(BOOL)isProject DEPRECATED_MSG_ATTRIBUTE("Please use INSFrameTimePicker");



@end

NS_ASSUME_NONNULL_END
