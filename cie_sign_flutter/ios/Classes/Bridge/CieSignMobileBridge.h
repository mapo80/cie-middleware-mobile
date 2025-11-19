#import <Foundation/Foundation.h>
#import "CieNfcSession.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CieSignMobileErrorDomain;

typedef NS_ERROR_ENUM(CieSignMobileErrorDomain, CieSignMobileErrorCode) {
    CieSignMobileErrorContext = 1,
    CieSignMobileErrorExecution = 2,
    CieSignMobileErrorOutput = 3,
};

NS_SWIFT_NAME(CieSignPdfParameters)
@interface CieSignPdfParameters : NSObject
@property (nonatomic) NSUInteger pageIndex;
@property (nonatomic) CGFloat left;
@property (nonatomic) CGFloat bottom;
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;
@property (nonatomic, copy) NSString *reason;
@property (nonatomic, copy) NSString *location;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSArray<NSString *> *fieldIds;
@property (nonatomic, strong, nullable) NSData *signatureImage;
@property (nonatomic) NSUInteger signatureImageWidth;
@property (nonatomic) NSUInteger signatureImageHeight;
@end

NS_SWIFT_NAME(CieSignMobileBridge)
@interface CieSignMobileBridge : NSObject

- (instancetype)initWithSession:(CieNfcSession *)session
                          logger:(void (^ _Nullable)(NSString *message))logger NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithMockTransportAndLogger:(void (^ _Nullable)(NSString *message))logger NS_SWIFT_NAME(init(mockTransportWithLogger:));
- (instancetype)init NS_UNAVAILABLE;

- (NSData * _Nullable)signPdf:(NSData *)pdf
                          pin:(NSString *)pin
                   appearance:(CieSignPdfParameters *)appearance
                        error:(NSError * _Nullable * _Nullable)error NS_SWIFT_NAME(sign(pdf:pin:appearance:));

- (BOOL)verifyPin:(NSString *)pin
            error:(NSError * _Nullable * _Nullable)error NS_SWIFT_NAME(verify(pin:));

- (void)cancelActiveSession;

@end

NS_ASSUME_NONNULL_END
