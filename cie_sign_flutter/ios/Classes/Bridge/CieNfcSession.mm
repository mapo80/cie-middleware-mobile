#import "CieNfcSession.h"

#if __has_include(<CoreNFC/CoreNFC.h>) && !TARGET_OS_SIMULATOR
#import <CoreNFC/CoreNFC.h>
#define CIE_CORENFC_AVAILABLE 1
#else
#define CIE_CORENFC_AVAILABLE 0
#endif

NSString * const CieSignNfcErrorDomain = @"it.ipzs.ciesign.nfc";

@interface CieNfcSession ()
#if CIE_CORENFC_AVAILABLE
< NFCTagReaderSessionDelegate >
@property (nonatomic, strong) NFCTagReaderSession *session;
@property (nonatomic, strong) id<NFCISO7816Tag> iso7816Tag;
@property (nonatomic, strong) dispatch_semaphore_t connectSemaphore;
@property (nonatomic, strong) dispatch_semaphore_t commandSemaphore;
@property (nonatomic, strong) NSError *lastError;
#endif
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSData *atrData;
@end

@implementation CieNfcSession

- (instancetype)initWithQueue:(dispatch_queue_t)queue {
    self = [super init];
    if (self) {
        _queue = queue ?: dispatch_get_main_queue();
        _atrData = [NSData data];
    }
    return self;
}

- (void)invalidate {
#if CIE_CORENFC_AVAILABLE
    [self.session invalidateSession];
    self.session = nil;
    self.iso7816Tag = nil;
    self.connectSemaphore = nil;
    self.commandSemaphore = nil;
    self.lastError = nil;
#endif
    self.atrData = [NSData data];
}

#if CIE_CORENFC_AVAILABLE

- (BOOL)beginSessionWithError:(NSError * _Nullable __autoreleasing *)error {
#if TARGET_OS_SIMULATOR
    if (error) {
        *error = [NSError errorWithDomain:CieSignNfcErrorDomain
                                     code:CieSignNfcErrorUnavailable
                                 userInfo:@{NSLocalizedDescriptionKey: @"CoreNFC non disponibile sul simulatore."}];
    }
    return NO;
#else
    if (!NFCTagReaderSession.readingAvailable) {
        if (error) {
            *error = [NSError errorWithDomain:CieSignNfcErrorDomain
                                         code:CieSignNfcErrorUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Il lettore NFC non è disponibile."}];
        }
        return NO;
    }

    self.connectSemaphore = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.session = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443
                                                                  delegate:self
                                                                     queue:self.queue];
        self.session.alertMessage = NSLocalizedString(@"Avvicina la CIE al lettore.", nil);
        [self.session beginSession];
    });

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(self.connectSemaphore, timeout) != 0 || self.iso7816Tag == nil) {
        NSError *reportedError = self.lastError ?: [NSError errorWithDomain:CieSignNfcErrorDomain
                                                                       code:CieSignNfcErrorTimeout
                                                                   userInfo:@{NSLocalizedDescriptionKey: @"Timeout durante l'apertura della sessione NFC."}];
        if (error) {
            *error = reportedError;
        }
        [self invalidate];
        return NO;
    }

    return YES;
#endif
}

- (BOOL)transceiveCommand:(NSData *)command
                 response:(NSMutableData * _Nullable __autoreleasing *)response
                    error:(NSError * _Nullable __autoreleasing *)error {
#if TARGET_OS_SIMULATOR
    if (error) {
        *error = [NSError errorWithDomain:CieSignNfcErrorDomain
                                     code:CieSignNfcErrorUnavailable
                                 userInfo:@{NSLocalizedDescriptionKey: @"CoreNFC non disponibile sul simulatore."}];
    }
    return NO;
#else
    if (!self.iso7816Tag) {
        if (error) {
            *error = [NSError errorWithDomain:CieSignNfcErrorDomain
                                         code:CieSignNfcErrorUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Sessione NFC non inizializzata."}];
        }
        return NO;
    }

    self.commandSemaphore = dispatch_semaphore_create(0);
    __block NSData *responseData = nil;
    __block uint8_t sw1 = 0;
    __block uint8_t sw2 = 0;
    __block NSError *commandError = nil;

    NFCISO7816APDU *apdu = [[NFCISO7816APDU alloc] initWithData:command];
    [self.iso7816Tag sendCommandAPDU:apdu
                    completionHandler:^(NSData * _Nonnull data, uint8_t sw1Resp, uint8_t sw2Resp, NSError * _Nullable errorResp) {
        responseData = data;
        sw1 = sw1Resp;
        sw2 = sw2Resp;
        commandError = errorResp;
        dispatch_semaphore_signal(self.commandSemaphore);
    }];

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(self.commandSemaphore, timeout) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:CieSignNfcErrorDomain
                                          code:CieSignNfcErrorTimeout
                                      userInfo:@{NSLocalizedDescriptionKey: @"Timeout durante la trasmissione APDU."}];
        }
        return NO;
    }

    if (commandError) {
        if (error) {
            *error = commandError;
        }
        return NO;
    }

    NSMutableData *mutable = responseData ? [responseData mutableCopy] : [NSMutableData data];
    uint8_t sw[] = { sw1, sw2 };
    [mutable appendBytes:sw length:sizeof(sw)];
    if (response) {
        *response = mutable;
    }
    return YES;
#endif
}

- (NSData *)atrData {
    if (_atrData.length == 0) {
        static NSData *fallback;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            const char bytes[] = { 'C','O','R','E','N','F','C' };
            fallback = [NSData dataWithBytes:bytes length:sizeof(bytes)];
        });
        return fallback;
    }
    return _atrData;
}

#pragma mark - NFCTagReaderSessionDelegate

- (void)readerSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {
    self.lastError = error;
    if (self.connectSemaphore) {
        dispatch_semaphore_signal(self.connectSemaphore);
    }
    if (self.commandSemaphore) {
        dispatch_semaphore_signal(self.commandSemaphore);
    }
}

- (void)readerSessionDidBecomeActive:(NFCTagReaderSession *)session {
    session.alertMessage = NSLocalizedString(@"Avvicina la CIE al lettore.", nil);
}

- (void)readerSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<NFCTag *> *)tags {
    if (tags.count > 1) {
        session.alertMessage = NSLocalizedString(@"Troppe carte rilevate. Allontanare le altre tessere.", nil);
        [session restartPolling];
        return;
    }

    NFCTag *tag = tags.firstObject;
    if (tag.type != NFCTagTypeISO7816Compatible) {
        session.alertMessage = NSLocalizedString(@"Carta non compatibile con ISO7816.", nil);
        [session restartPolling];
        return;
    }

    [session connectToTag:tag completionHandler:^(NSError * _Nullable error) {
        if (error) {
            self.lastError = error;
            dispatch_semaphore_signal(self.connectSemaphore);
            return;
        }

        if (@available(iOS 13.0, *)) {
            self.iso7816Tag = tag.asNFCISO7816Tag;
        } else {
            self.iso7816Tag = (id<NFCISO7816Tag>)tag;
        }

        self.atrData = [self buildAtrFromTag:self.iso7816Tag];
        dispatch_semaphore_signal(self.connectSemaphore);
        session.alertMessage = NSLocalizedString(@"Carta rilevata.", nil);
    }];
}

- (NSData *)buildAtrFromTag:(id<NFCISO7816Tag>)tag {
    NSMutableData *atr = [NSMutableData data];
    if (@available(iOS 13.0, *)) {
        if (tag.historicalBytes) {
            [atr appendData:tag.historicalBytes];
        }
        if (tag.applicationData) {
            [atr appendData:tag.applicationData];
        }
    }
    if ([tag respondsToSelector:@selector(identifier)] && tag.identifier.length > 0) {
        [atr appendData:tag.identifier];
    }
    if (atr.length == 0) {
        const uint8_t fallback[] = { 0x80, 0x31, 0x80, 0x65 };
        [atr appendBytes:fallback length:sizeof(fallback)];
    }
    return atr;
}

#else

- (BOOL)beginSessionWithError:(NSError * _Nullable __autoreleasing *)error {
    if (error) {
        *error = [NSError errorWithDomain:CieSignNfcErrorDomain
                                     code:CieSignNfcErrorUnavailable
                                 userInfo:@{NSLocalizedDescriptionKey: @"CoreNFC non disponibile su questa piattaforma."}];
    }
    return NO;
}

- (BOOL)transceiveCommand:(NSData *)command
                 response:(NSMutableData * _Nullable __autoreleasing *)response
                    error:(NSError * _Nullable __autoreleasing *)error {
    if (error) {
        *error = [NSError errorWithDomain:CieSignNfcErrorDomain
                                     code:CieSignNfcErrorUnavailable
                                 userInfo:@{NSLocalizedDescriptionKey: @"CoreNFC non disponibile su questa piattaforma."}];
    }
    return NO;
}

- (NSData *)atrData {
    static NSData *fallback;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char bytes[] = { 'C','O','R','E','N','F','C' };
        fallback = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    });
    return fallback;
}

#endif

@end
