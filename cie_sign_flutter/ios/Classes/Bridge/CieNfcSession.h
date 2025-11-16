#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CieSignNfcErrorDomain;

typedef NS_ERROR_ENUM(CieSignNfcErrorDomain, CieSignNfcErrorCode) {
    CieSignNfcErrorUnavailable = 1,
    CieSignNfcErrorTimeout = 2,
    CieSignNfcErrorTagInvalid = 3,
    CieSignNfcErrorTransceive = 4,
};

NS_SWIFT_NAME(CieNfcSession)
@interface CieNfcSession : NSObject

- (instancetype)initWithQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)beginSessionWithError:(NSError * _Nullable * _Nullable)error;
- (BOOL)transceiveCommand:(NSData *)command
                 response:(NSMutableData * _Nullable * _Nullable)response
                    error:(NSError * _Nullable * _Nullable)error;
- (void)invalidate;

@property (nonatomic, readonly) NSData *atrData;

@end

NS_ASSUME_NONNULL_END
