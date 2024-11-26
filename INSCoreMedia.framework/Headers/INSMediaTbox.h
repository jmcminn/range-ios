//
//  INSMediaTbox.h
//  INSCoreMedia
//
//  Created by 谷瑾之 on 2023/5/6.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
//extern static const int kExtraTboxDataFrameLen;

static const int kExtraTboxDataFrameLen = 36;
static const int kExtraTboxDatatimestampsLen = 8;
static const int kExtraTboxDatatimestampmsLen = 2;
static const int kExtraTboxDataDashSpeedLen = 1;
static const int kExtraTboxDataEngineSpeedLen = 8;
static const int kExtraTboxDataGearPositionLen = 1;
static const int kExtraTboxDataVehicleTypeLen = 1;
static const int kExtraTboxDataBrakeStatusLen = 1;
static const int kExtraTboxDataAaccelerateLen = 1;
static const int kExtraTboxDataDaccelerateLen = 1;
static const int kExtraTboxDataVehicleBendingLen = 1;
static const int kExtraTboxDataThrottleLen = 8;
static const int kExtraTboxDataAngle_cLen = 1;
static const int kExtraTboxDataAngle_lLen = 2;

@interface INSMediaTbox : NSObject

@property (nonatomic) int64_t timestamp_s;
@property (nonatomic) uint16_t timestamp_ms;
@property (nonatomic) uint8_t dash_speed;
@property (nonatomic) double engine_speed;
@property (nonatomic) uint8_t gear_position;
@property (nonatomic) uint8_t vehicle_type;
@property (nonatomic) uint8_t brake_status;   //制动
@property (nonatomic) uint8_t accelerate;     //急加
@property (nonatomic) uint8_t dccelerate;     //急减
@property (nonatomic) uint8_t vehicle_bending;    //压弯
@property (nonatomic) double throttle;
@property (nonatomic) int8_t angle_c;
@property (nonatomic) int16_t angle_l;

- (instancetype)initWithData:(NSData *)tboxData;

NS_ASSUME_NONNULL_END

@end
