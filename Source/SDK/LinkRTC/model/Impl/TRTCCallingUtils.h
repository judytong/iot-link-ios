//
//  TUIUtils.h
//  TXIMSDK_TUIKit_iOS
//
//

#import <Foundation/Foundation.h>
#import "TRTCCallingModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TRTCCallingUtils : NSObject

///生成随机 RoomID
+ (UInt32)generateRoomID;

+ (NSString *)loginUser;

+ (void)getCallUserModel:(NSString *)userID finished:(void(^)(CallUserModel *))finished;

+ (NSString *)dictionary2JsonStr:(NSDictionary *)dict;

+ (NSData *)dictionary2JsonData:(NSDictionary *)dict;

+ (NSDictionary *)jsonSring2Dictionary:(NSString *)jsonString;

+ (NSDictionary *)jsonData2Dictionary:(NSData *)jsonData;

@end

NS_ASSUME_NONNULL_END
