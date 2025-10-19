#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CardDeskewer : NSObject
+ (NSString *)deskewAtPath:(NSString *)imagePath
                         x:(NSNumber *_Nullable)x
                         y:(NSNumber *_Nullable)y
                     width:(NSNumber *_Nullable)width
                    height:(NSNumber *_Nullable)height;
@end

NS_ASSUME_NONNULL_END
