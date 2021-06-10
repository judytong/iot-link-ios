//
//  NSObject+SwizzlingMethod.h
//  SEEXiaodianpu
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (SwizzlingMethod)

+ (void)swizzlingMethod:(SEL)method replace:(SEL)replaceMethod;

@end

NS_ASSUME_NONNULL_END
