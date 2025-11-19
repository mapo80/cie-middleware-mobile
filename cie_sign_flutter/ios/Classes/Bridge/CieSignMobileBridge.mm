#import "CieSignMobileBridge.h"

#import <memory>
#import <vector>
#import <string>

extern "C" {
#include "../../../../cie_sign_sdk/include/mobile/cie_sign.h"
}
#if __has_include("../Mock/mock_transport.h")
#include "../Mock/mock_transport.h"
#else
#include "../../../../cie_sign_sdk/tests/mock/mock_transport.h"
#endif

NSString * const CieSignMobileErrorDomain = @"it.ipzs.ciesign.bridge";

namespace {
struct IosNfcAdapterState {
    __strong CieNfcSession *session = nil;
    std::vector<uint8_t> atrBuffer;
    NSError *lastError = nil;

    explicit IosNfcAdapterState(CieNfcSession *s) : session(s) {}
};

static NSError *MakeError(NSString *domain, NSInteger code, NSString *message, NSError *underlying = nil) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (message.length > 0) {
        info[NSLocalizedDescriptionKey] = message;
    }
    if (underlying) {
        info[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:domain code:code userInfo:info];
}

static int ios_nfc_open(void *user_data, const uint8_t **atr, size_t *atr_len) {
    auto *state = static_cast<IosNfcAdapterState *>(user_data);
    if (!state || !state->session) {
        return -1;
    }
    NSError *error = nil;
    if (![state->session beginSessionWithError:&error]) {
        state->lastError = error ?: MakeError(CieSignNfcErrorDomain, CieSignNfcErrorUnavailable, @"Impossibile avviare la sessione NFC.");
        return -1;
    }
    NSData *atrData = state->session.atrData;
    if (!atrData || atrData.length == 0) {
        state->lastError = MakeError(CieSignMobileErrorDomain, CieSignMobileErrorExecution, @"ATR non disponibile.");
        return -1;
    }
    state->atrBuffer.assign((const uint8_t *)atrData.bytes,
                            (const uint8_t *)atrData.bytes + atrData.length);
    *atr = state->atrBuffer.data();
    *atr_len = state->atrBuffer.size();
    return 0;
}

static int ios_nfc_transceive(void *user_data,
                              const uint8_t *apdu,
                              uint32_t apdu_len,
                              uint8_t *resp,
                              uint32_t *resp_len) {
    auto *state = static_cast<IosNfcAdapterState *>(user_data);
    if (!state || !state->session || !resp || !resp_len) {
        return -1;
    }
    NSData *command = [NSData dataWithBytes:apdu length:apdu_len];
    NSMutableData *response = nil;
    NSError *error = nil;
    if (![state->session transceiveCommand:command response:&response error:&error]) {
        state->lastError = error ?: MakeError(CieSignNfcErrorDomain, CieSignNfcErrorTransceive, @"Errore APDU.");
        return -1;
    }
    if (response.length > *resp_len) {
        state->lastError = MakeError(CieSignMobileErrorDomain, CieSignMobileErrorOutput, @"Buffer risposta insufficiente.");
        return -1;
    }
    memcpy(resp, response.bytes, response.length);
    *resp_len = (uint32_t)response.length;
    return 0;
}

static void ios_nfc_close(void *user_data) {
    auto *state = static_cast<IosNfcAdapterState *>(user_data);
    if (!state) {
        return;
    }
    [state->session invalidate];
    state->atrBuffer.clear();
}
} // namespace

@implementation CieSignPdfParameters

- (instancetype)init {
    self = [super init];
    if (self) {
        _pageIndex = 0;
        _left = 72;
        _bottom = 72;
        _width = 180;
        _height = 40;
        _reason = @"Firma con CIE";
        _location = @"";
        _name = @"";
        _fieldIds = @[];
        _signatureImage = [NSData data];
        _signatureImageWidth = 0;
        _signatureImageHeight = 0;
    }
    return self;
}

@end

@interface CieSignMobileBridge ()
@property (nonatomic, strong) CieNfcSession *session;
@property (nonatomic, copy) void (^logger)(NSString *message);
@property (nonatomic, assign) BOOL useMockTransport;
@end

@implementation CieSignMobileBridge

- (instancetype)initWithSession:(CieNfcSession *)session
                          logger:(void (^)(NSString * _Nonnull))logger {
    self = [super init];
    if (self) {
        _session = session;
        _logger = [logger copy];
        _useMockTransport = NO;
    }
    return self;
}

- (instancetype)initWithMockTransportAndLogger:(void (^)(NSString * _Nonnull))logger {
    self = [super init];
    if (self) {
        _logger = [logger copy];
        _useMockTransport = YES;
    }
    return self;
}

- (NSData *)signPdf:(NSData *)pdf
                pin:(NSString *)pin
         appearance:(CieSignPdfParameters *)appearance
              error:(NSError * _Nullable __autoreleasing *)error {
    if (pdf.length == 0) {
        if (error) {
            *error = MakeError(CieSignMobileErrorDomain, CieSignMobileErrorExecution, @"PDF non valido.");
        }
        return nil;
    }

    if (self.useMockTransport) {
        return [self signUsingMockTransport:pdf pin:pin appearance:appearance error:error];
    }

    IosNfcAdapterState state(self.session);

    cie_platform_nfc_adapter adapter{};
    adapter.user_data = &state;
    adapter.open = ios_nfc_open;
    adapter.transceive = ios_nfc_transceive;
    adapter.close = ios_nfc_close;

    cie_platform_config config{};
    config.nfc = &adapter;

    std::unique_ptr<cie_sign_ctx, decltype(&cie_sign_ctx_destroy)> ctx(
        cie_sign_ctx_create_with_platform(&config), cie_sign_ctx_destroy);

    if (!ctx) {
        NSError *ctxError = state.lastError ?: MakeError(CieSignMobileErrorDomain, CieSignMobileErrorContext, @"Impossibile creare il contesto di firma.");
        if (error) {
            *error = ctxError;
        }
        return nil;
    }

    return [self runSigningWithContext:ctx.get()
                                   pdf:pdf
                                   pin:pin
                            appearance:appearance
                             lastError:state.lastError
                                  error:error];
}

- (NSData *)signUsingMockTransport:(NSData *)pdf
                               pin:(NSString *)pin
                        appearance:(CieSignPdfParameters *)appearance
                             error:(NSError * _Nullable __autoreleasing *)error {
    MockApduTransport transport;
    std::unique_ptr<cie_sign_ctx, decltype(&cie_sign_ctx_destroy)> ctx(
        create_mock_context(transport), cie_sign_ctx_destroy);
    if (!ctx) {
        if (error) {
            *error = MakeError(CieSignMobileErrorDomain, CieSignMobileErrorContext, @"Impossibile inizializzare il mock NFC.");
        }
        return nil;
    }

    return [self runSigningWithContext:ctx.get()
                                  pdf:pdf
                                  pin:pin
                           appearance:appearance
                            lastError:nil
                                 error:error];
}

- (BOOL)verifyPinUsingMockTransport:(NSString *)pin
                              error:(NSError * _Nullable __autoreleasing *)error {
    MockApduTransport transport;
    std::unique_ptr<cie_sign_ctx, decltype(&cie_sign_ctx_destroy)> ctx(
        create_mock_context(transport), cie_sign_ctx_destroy);
    if (!ctx) {
        if (error) {
            *error = MakeError(CieSignMobileErrorDomain, CieSignMobileErrorContext, @"Impossibile inizializzare il mock NFC.");
        }
        return NO;
    }
    return [self runPinVerificationWithContext:ctx.get()
                                            pin:pin
                                      lastError:nil
                                           error:error];
}

- (BOOL)verifyPin:(NSString *)pin error:(NSError * _Nullable __autoreleasing *)error {
    if (self.useMockTransport) {
        return [self verifyPinUsingMockTransport:pin error:error];
    }

    IosNfcAdapterState state(self.session);

    cie_platform_nfc_adapter adapter{};
    adapter.user_data = &state;
    adapter.open = ios_nfc_open;
    adapter.transceive = ios_nfc_transceive;
    adapter.close = ios_nfc_close;

    cie_platform_config config{};
    config.nfc = &adapter;

    std::unique_ptr<cie_sign_ctx, decltype(&cie_sign_ctx_destroy)> ctx(
        cie_sign_ctx_create_with_platform(&config), cie_sign_ctx_destroy);

    if (!ctx) {
        NSError *ctxError = state.lastError ?: MakeError(CieSignMobileErrorDomain, CieSignMobileErrorContext, @"Impossibile creare il contesto NFC.");
        if (error) {
            *error = ctxError;
        }
        return NO;
    }

    return [self runPinVerificationWithContext:ctx.get()
                                            pin:pin
                                      lastError:state.lastError
                                           error:error];
}

- (NSData *)runSigningWithContext:(cie_sign_ctx *)ctx
                              pdf:(NSData *)pdf
                              pin:(NSString *)pin
                       appearance:(CieSignPdfParameters *)appearance
                        lastError:(NSError *)lastError
                             error:(NSError * _Nullable __autoreleasing *)error {
    std::string pinUtf8(pin.UTF8String ?: "");
    std::string reason(appearance.reason.UTF8String ?: "");
    std::string location(appearance.location.UTF8String ?: "");
    std::string name(appearance.name.UTF8String ?: "");

    cie_sign_request request{};
    request.input = static_cast<const uint8_t *>(pdf.bytes);
    request.input_len = pdf.length;
    request.pin = pinUtf8.c_str();
    request.pin_len = pinUtf8.size();
    request.doc_type = CIE_DOCUMENT_PDF;
    request.detached = 0;
    request.pdf.reason = reason.c_str();
    request.pdf.location = location.c_str();
    request.pdf.name = name.c_str();
    request.pdf.page_index = (uint32_t)appearance.pageIndex;
    request.pdf.left = appearance.left;
    request.pdf.bottom = appearance.bottom;
    request.pdf.width = appearance.width;
    request.pdf.height = appearance.height;

    std::vector<std::string> fieldIdsUtf8;
    std::vector<const char *> fieldIdPtrs;
    if (appearance.fieldIds.count > 0) {
        fieldIdsUtf8.reserve(appearance.fieldIds.count);
        fieldIdPtrs.reserve(appearance.fieldIds.count);
        for (NSString *field in appearance.fieldIds) {
            if (![field isKindOfClass:[NSString class]] || field.length == 0) {
                continue;
            }
            fieldIdsUtf8.emplace_back(field.UTF8String ?: "");
        }
        for (const auto &entry : fieldIdsUtf8) {
            fieldIdPtrs.push_back(entry.c_str());
        }
        if (!fieldIdPtrs.empty()) {
            request.pdf.field_ids = fieldIdPtrs.data();
            request.pdf.field_ids_len = fieldIdPtrs.size();
        }
    }

    if (appearance.signatureImage.length > 0 &&
        appearance.signatureImageWidth > 0 &&
        appearance.signatureImageHeight > 0) {
        request.pdf.signature_image = static_cast<const uint8_t *>(appearance.signatureImage.bytes);
        request.pdf.signature_image_len = appearance.signatureImage.length;
        request.pdf.signature_image_width = (uint32_t)appearance.signatureImageWidth;
        request.pdf.signature_image_height = (uint32_t)appearance.signatureImageHeight;
    }

    size_t capacity = pdf.length + 65536;
    NSMutableData *output = [NSMutableData dataWithLength:capacity];
    cie_sign_result result{};
    result.output = static_cast<uint8_t *>(output.mutableBytes);
    result.output_capacity = output.length;

    cie_status status = cie_sign_execute(ctx, &request, &result);
    if (status != CIE_STATUS_OK) {
        NSString *message = nil;
        const char *err = cie_sign_get_last_error(ctx);
        if (err) {
            message = [NSString stringWithUTF8String:err];
        }
        if (!message.length && lastError) {
            message = lastError.localizedDescription;
        }
        if (!message.length) {
            message = @"Errore sconosciuto durante la firma.";
        }
        if (error) {
            *error = MakeError(CieSignMobileErrorDomain, CieSignMobileErrorExecution, message, lastError);
        }
        return nil;
    }

    output.length = result.output_len;
    return [output copy];
}

- (BOOL)runPinVerificationWithContext:(cie_sign_ctx *)ctx
                                  pin:(NSString *)pin
                            lastError:(NSError *)lastError
                                 error:(NSError * _Nullable __autoreleasing *)error {
    std::string pinUtf8(pin.UTF8String ?: "");
    cie_status status = cie_sign_verify_pin(ctx, pinUtf8.c_str(), pinUtf8.size());
    if (status != CIE_STATUS_OK) {
        NSString *message = nil;
        const char *err = cie_sign_get_last_error(ctx);
        if (err) {
            message = [NSString stringWithUTF8String:err];
        }
        if (!message.length && lastError) {
            message = lastError.localizedDescription;
        }
        if (!message.length) {
            message = @"Verifica PIN fallita.";
        }
        if (error) {
            *error = MakeError(CieSignMobileErrorDomain, CieSignMobileErrorExecution, message, lastError);
        }
        return NO;
    }
    return YES;
}

- (void)cancelActiveSession {
    if (self.session) {
        [self.session invalidate];
    }
}

@end
