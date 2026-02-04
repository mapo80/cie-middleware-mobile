#import "CieSignFlutterPlugin.h"
#import <TargetConditionals.h>
#import "Bridge/CieSignMobileBridge.h"

// PoDoFo test
extern void podofo_test_set_pdf_data(const char* data, size_t length);
extern int podofo_run_all_tests(void);

@interface CieSignFlutterPlugin ()
@property(nonatomic, strong) CieSignMobileBridge *mockBridge;
@property(nonatomic, strong, nullable) CieSignMobileBridge *nfcBridge;
@property(nonatomic, strong) dispatch_queue_t signingQueue;
@property(nonatomic, copy, nullable) FlutterResult pendingNfcResult;
@property(nonatomic, strong) FlutterEventChannel *eventChannel;
@property(nonatomic, copy, nullable) FlutterEventSink eventSink;
@end

@implementation CieSignFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"cie_sign_flutter"
                                     binaryMessenger:[registrar messenger]];
    CieSignFlutterPlugin* instance = [[CieSignFlutterPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];

    FlutterEventChannel* eventChannel = [FlutterEventChannel
                                         eventChannelWithName:@"cie_sign_flutter/nfc_events"
                                         binaryMessenger:[registrar messenger]];
    [eventChannel setStreamHandler:instance];
    instance.eventChannel = eventChannel;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _signingQueue = dispatch_queue_create("it.ipzs.ciesign.flutter.signing", DISPATCH_QUEUE_SERIAL);
        __weak typeof(self) weakSelf = self;
        _mockBridge = [[CieSignMobileBridge alloc] initWithMockTransportAndLogger:^(NSString *message) {
            NSLog(@"[CieSignFlutter] %@", message);
            #pragma unused(weakSelf)
        }];
#if TARGET_OS_SIMULATOR
        _nfcBridge = nil;
#else
        CieNfcSession *session = [[CieNfcSession alloc] initWithQueue:dispatch_get_main_queue()];
        _nfcBridge = [[CieSignMobileBridge alloc] initWithSession:session logger:^(NSString *message) {
            NSLog(@"[CieSignFlutter] %@", message);
            #pragma unused(weakSelf)
        }];
#endif
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"mockSignPdf"]) {
        [self handleMockSignCall:call result:result];
    } else if ([call.method isEqualToString:@"signPdfWithNfc"]) {
        [self handleSignWithNfcCall:call result:result];
    } else if ([call.method isEqualToString:@"verifyPinWithNfc"]) {
        [self handleVerifyPinCall:call result:result];
    } else if ([call.method isEqualToString:@"cancelNfcSigning"]) {
        [self handleCancelNfcCall:result];
    } else if ([call.method isEqualToString:@"testPodofo"]) {
        [self handleTestPodofoCall:call result:result];
    } else if ([call.method isEqualToString:@"extractSignatureFields"]) {
        [self handleExtractSignatureFieldsCall:call result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)handleTestPodofoCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary *args = call.arguments;
    NSData *pdfData = [self dataFromArgument:args[@"pdf"]];

    dispatch_async(self.signingQueue, ^{
        NSLog(@"[CieSignFlutter] Running PoDoFo tests with PDF size: %lu bytes", (unsigned long)pdfData.length);

        // Pass PDF data to the test
        if (pdfData.length > 0) {
            podofo_test_set_pdf_data((const char*)pdfData.bytes, pdfData.length);
        }

        int failed = podofo_run_all_tests();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (failed == 0) {
                result(@{@"success": @(YES), @"message": @"All PoDoFo tests passed"});
            } else {
                result(@{@"success": @(NO), @"message": [NSString stringWithFormat:@"%d tests failed", failed]});
            }
        });
    });
}

- (void)handleMockSignCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary *args = [self validatedArgumentsFromCall:call result:result];
    if (!args) {
        return;
    }
    NSData *pdfData = [self dataFromArgument:args[@"pdf"]];
    if (pdfData.length == 0) {
        result([FlutterError errorWithCode:@"invalid_pdf" message:@"Argument 'pdf' must be a non-empty Uint8List" details:nil]);
        return;
    }
    NSString *outputPath = [self sanitizedPath:args[@"outputPath"]];
    NSError *appearanceError = nil;
    CieSignPdfParameters *params = [self parametersFromAppearance:args[@"appearance"] error:&appearanceError];
    if (!params) {
        result([FlutterError errorWithCode:@"invalid_appearance" message:appearanceError.localizedDescription ?: @"Invalid appearance map" details:nil]);
        return;
    }
    [self performSigningWithBridge:self.mockBridge
                           pdfData:pdfData
                               pin:@"1234"
                        appearance:params
                        outputPath:outputPath
                         completion:^(NSData * _Nullable signedData, NSError * _Nullable error) {
        if (!signedData) {
            result([self flutterErrorFromNSError:error
                                            code:@"mock_sign_failed"
                                        fallback:@"Unable to sign PDF"]);
            return;
        }
        [self persistSignedData:signedData toPath:outputPath];
        result([FlutterStandardTypedData typedDataWithBytes:signedData]);
    }];
}

- (void)handleSignWithNfcCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (!self.nfcBridge) {
        [self emitErrorWithCode:@"nfc_unavailable" message:@"CoreNFC non disponibile su questo dispositivo."];
        result([FlutterError errorWithCode:@"nfc_unavailable"
                                   message:@"CoreNFC non disponibile su questo dispositivo."
                                   details:nil]);
        return;
    }
    if (self.pendingNfcResult) {
        [self emitErrorWithCode:@"busy" message:@"A signing request is already in progress."];
        result([FlutterError errorWithCode:@"busy"
                                   message:@"A signing request is already in progress."
                                   details:nil]);
        return;
    }
    NSDictionary *args = [self validatedArgumentsFromCall:call result:result];
    if (!args) {
        return;
    }
    NSData *pdfData = [self dataFromArgument:args[@"pdf"]];
    if (pdfData.length == 0) {
        result([FlutterError errorWithCode:@"invalid_pdf" message:@"Argument 'pdf' must be a non-empty Uint8List" details:nil]);
        return;
    }
    NSString *pin = [args[@"pin"] isKindOfClass:[NSString class]] ? [args[@"pin"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    if (pin.length == 0) {
        result([FlutterError errorWithCode:@"invalid_pin" message:@"PIN cannot be empty" details:nil]);
        return;
    }
    NSString *outputPath = [self sanitizedPath:args[@"outputPath"]];
    NSError *appearanceError = nil;
    CieSignPdfParameters *params = [self parametersFromAppearance:args[@"appearance"] error:&appearanceError];
    if (!params) {
        result([FlutterError errorWithCode:@"invalid_appearance"
                                   message:appearanceError.localizedDescription ?: @"Invalid appearance map"
                                   details:nil]);
        return;
    }

    self.pendingNfcResult = [result copy];
    [self emitEvent:@"listening" data:@{}];
    __weak typeof(self) weakSelf = self;
    [self performSigningWithBridge:self.nfcBridge
                           pdfData:pdfData
                               pin:pin
                        appearance:params
                        outputPath:outputPath
                         completion:^(NSData * _Nullable signedData, NSError * _Nullable error) {
        __strong typeof(self) strongSelf = weakSelf;
        FlutterResult pendingResult = strongSelf.pendingNfcResult;
        strongSelf.pendingNfcResult = nil;
        if (!pendingResult) {
            return; // cancellation already handled
        }
        if (!signedData) {
            [strongSelf emitErrorWithCode:@"nfc_sign_failed" message:error.localizedDescription ?: @"Impossibile completare la firma NFC."];
            pendingResult([strongSelf flutterErrorFromNSError:error
                                                         code:@"nfc_sign_failed"
                                                     fallback:@"Impossibile completare la firma NFC."]);
            return;
        }
        [strongSelf persistSignedData:signedData toPath:outputPath];
        [strongSelf emitEvent:@"completed" data:@{@"bytes": @(signedData.length)}];
        pendingResult([FlutterStandardTypedData typedDataWithBytes:signedData]);
    }];
}

- (void)handleVerifyPinCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (!self.nfcBridge) {
        [self emitErrorWithCode:@"nfc_unavailable" message:@"CoreNFC non disponibile su questo dispositivo."];
        result([FlutterError errorWithCode:@"nfc_unavailable"
                                   message:@"CoreNFC non disponibile su questo dispositivo."
                                   details:nil]);
        return;
    }
    if (self.pendingNfcResult) {
        [self emitErrorWithCode:@"busy" message:@"A NFC request is already in progress."];
        result([FlutterError errorWithCode:@"busy"
                                   message:@"A NFC request is already in progress."
                                   details:nil]);
        return;
    }
    NSDictionary *args = [self validatedArgumentsFromCall:call result:result];
    if (!args) {
        return;
    }
    NSString *pin = [args[@"pin"] isKindOfClass:[NSString class]] ? [args[@"pin"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    if (pin.length == 0) {
        result([FlutterError errorWithCode:@"invalid_pin" message:@"PIN cannot be empty" details:nil]);
        return;
    }
    self.pendingNfcResult = [result copy];
    [self emitEvent:@"listening" data:@{}];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.signingQueue, ^{
        NSError *error = nil;
        BOOL ok = [weakSelf.nfcBridge verifyPin:pin error:&error];
        __strong typeof(self) strongSelf = weakSelf;
        FlutterResult pendingResult = strongSelf.pendingNfcResult;
        strongSelf.pendingNfcResult = nil;
        if (!pendingResult) {
            return;
        }
        if (!ok) {
            [strongSelf emitErrorWithCode:@"nfc_verify_failed" message:error.localizedDescription ?: @"Impossibile verificare il PIN via NFC."];
            pendingResult([strongSelf flutterErrorFromNSError:error
                                                        code:@"nfc_verify_failed"
                                                    fallback:@"Impossibile verificare il PIN via NFC."]);
            return;
        }
        [strongSelf emitEvent:@"completed" data:@{@"verified": @(YES)}];
        pendingResult(@(YES));
    });
}

- (void)handleCancelNfcCall:(FlutterResult)result {
    FlutterResult pending = self.pendingNfcResult;
    if (!pending) {
        result(@(NO));
        return;
    }
    self.pendingNfcResult = nil;
    [self.nfcBridge cancelActiveSession];
    [self emitEvent:@"canceled" data:@{}];
    pending([FlutterError errorWithCode:@"canceled"
                               message:@"Operazione NFC annullata"
                               details:nil]);
    result(@(YES));
}

- (NSDictionary *)validatedArgumentsFromCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (![call.arguments isKindOfClass:[NSDictionary class]]) {
        result([FlutterError errorWithCode:@"invalid_args" message:@"Expected map arguments" details:nil]);
        return nil;
    }
    return (NSDictionary *)call.arguments;
}

- (NSData *)dataFromArgument:(id)arg {
    if ([arg isKindOfClass:[FlutterStandardTypedData class]]) {
        return ((FlutterStandardTypedData *)arg).data;
    }
    if ([arg isKindOfClass:[NSData class]]) {
        return arg;
    }
    return [NSData data];
}

- (NSString *)sanitizedPath:(id)pathValue {
    if (![pathValue isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *trimmed = [((NSString *)pathValue) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length > 0 ? trimmed : nil;
}

- (void)performSigningWithBridge:(CieSignMobileBridge *)bridge
                         pdfData:(NSData *)pdf
                             pin:(NSString *)pin
                      appearance:(CieSignPdfParameters *)appearance
                      outputPath:(NSString *)outputPath
                       completion:(void (^)(NSData * _Nullable signedData, NSError * _Nullable error))completion {
    dispatch_async(self.signingQueue, ^{
        NSError *error = nil;
        NSData *signedData = [bridge signPdf:pdf pin:pin appearance:appearance error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(signedData, error);
        });
    });
}

- (CieSignPdfParameters *)parametersFromAppearance:(NSDictionary *)map error:(NSError **)error {
    CieSignPdfParameters *params = [[CieSignPdfParameters alloc] init];
    if (![map isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[CieSignFlutter] parametersFromAppearance: map is not NSDictionary, using defaults");
        return params;
    }
    NSDictionary *dict = (NSDictionary *)map;
    NSLog(@"[CieSignFlutter] parametersFromAppearance: keys=%@", dict.allKeys);
    NSNumber *pageIndex = dict[@"pageIndex"];
    if ([pageIndex isKindOfClass:[NSNumber class]]) {
        params.pageIndex = pageIndex.unsignedIntegerValue;
    }
    NSNumber *left = dict[@"left"];
    if ([left isKindOfClass:[NSNumber class]]) {
        params.left = left.doubleValue;
    }
    NSNumber *bottom = dict[@"bottom"];
    if ([bottom isKindOfClass:[NSNumber class]]) {
        params.bottom = bottom.doubleValue;
    }
    NSNumber *width = dict[@"width"];
    if ([width isKindOfClass:[NSNumber class]]) {
        params.width = width.doubleValue;
    }
    NSNumber *height = dict[@"height"];
    if ([height isKindOfClass:[NSNumber class]]) {
        params.height = height.doubleValue;
    }
    NSLog(@"[CieSignFlutter] parametersFromAppearance: pageIndex=%lu left=%.4f bottom=%.4f width=%.4f height=%.4f",
          (unsigned long)params.pageIndex, params.left, params.bottom, params.width, params.height);
    NSString *reason = dict[@"reason"];
    if ([reason isKindOfClass:[NSString class]] && ((NSString *)reason).length > 0) {
        params.reason = reason;
    }
    NSString *location = dict[@"location"];
    if ([location isKindOfClass:[NSString class]]) {
        params.location = location;
    }
    NSString *name = dict[@"name"];
    if ([name isKindOfClass:[NSString class]]) {
        params.name = name;
    }
    NSArray *fieldIds = dict[@"fieldIds"];
    if ([fieldIds isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *cleanIds = [NSMutableArray arrayWithCapacity:[fieldIds count]];
        for (id entry in fieldIds) {
            if ([entry isKindOfClass:[NSString class]]) {
                NSString *trimmed = [(NSString *)entry stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (trimmed.length > 0) {
                    [cleanIds addObject:trimmed];
                }
            }
        }
        params.fieldIds = cleanIds;
    }
    NSData *signatureImageData = [self dataFromArgument:dict[@"signatureImage"]];
    if (signatureImageData.length > 0) {
        params.signatureImage = signatureImageData;
        params.signatureImageWidth = 0;
        params.signatureImageHeight = 0;
        NSLog(@"[CieSignFlutter] Signature image received: %lu bytes", (unsigned long)signatureImageData.length);
    } else {
        NSLog(@"[CieSignFlutter] No signature image provided");
    }
    return params;
}

- (void)persistSignedData:(NSData *)data toPath:(NSString *)path {
    if (path.length == 0) {
        return;
    }
    NSError *error = nil;
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        NSLog(@"[CieSignFlutter] Unable to persist signed PDF: %@", error.localizedDescription);
    }
}

- (FlutterError *)flutterErrorFromNSError:(NSError *)error
                                     code:(NSString *)code
                                 fallback:(NSString *)fallback {
    if (!error) {
        return [FlutterError errorWithCode:code message:fallback details:nil];
    }
    NSString *message = error.localizedDescription ?: fallback;
    return [FlutterError errorWithCode:code message:message details:error.userInfo];
}

#pragma mark - FlutterStreamHandler

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.eventSink = events;
    [self emitNfcState];
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

#pragma mark - Event Emission

- (NSString *)currentNfcStatus {
    if (self.nfcBridge == nil) {
        return @"not_supported";
    }
    return @"ready";
}

- (void)emitNfcState {
    [self emitEvent:@"state" data:@{@"status": [self currentNfcStatus]}];
}

- (void)emitEvent:(NSString *)type data:(NSDictionary *)data {
    if (!self.eventSink) {
        return;
    }
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:data ?: @{}];
    payload[@"type"] = type;
    FlutterEventSink sink = self.eventSink;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sink) {
            sink(payload);
        }
    });
}

- (void)emitErrorWithCode:(NSString *)code message:(NSString *)message {
    [self emitEvent:@"error" data:@{@"code": code ?: @"unknown", @"message": message ?: @""}];
}

#pragma mark - Signature Field Extraction

- (void)handleExtractSignatureFieldsCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *args = [self validatedArgumentsFromCall:call result:result];
    if (!args) {
        return;
    }
    NSData *pdfData = [self dataFromArgument:args[@"pdf"]];
    if (pdfData.length == 0) {
        result([FlutterError errorWithCode:@"invalid_pdf"
                                   message:@"Argument 'pdf' must be a non-empty Uint8List"
                                   details:nil]);
        return;
    }

    dispatch_async(self.signingQueue, ^{
        NSError *error = nil;
        NSArray<NSDictionary *> *fields = [self.mockBridge extractSignatureFields:pdfData error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!fields) {
                result([self flutterErrorFromNSError:error
                                                code:@"extraction_failed"
                                            fallback:@"Unable to extract signature fields"]);
                return;
            }
            result(fields);
        });
    });
}

@end
