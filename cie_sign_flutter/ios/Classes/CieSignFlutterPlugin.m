#import "CieSignFlutterPlugin.h"
#import "Bridge/CieSignMobileBridge.h"

@interface CieSignFlutterPlugin ()
@property(nonatomic, strong) CieSignMobileBridge *bridge;
@end

@implementation CieSignFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"cie_sign_flutter"
            binaryMessenger:[registrar messenger]];
  CieSignFlutterPlugin* instance = [[CieSignFlutterPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self) {
      __weak typeof(self) weakSelf = self;
      _bridge = [[CieSignMobileBridge alloc] initWithMockTransportAndLogger:^(NSString *message) {
          NSLog(@"[CieSignFlutter] %@", message);
          #pragma unused(weakSelf)
      }];
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"mockSignPdf"]) {
      [self handleMockSignCall:call result:result];
  } else {
      result(FlutterMethodNotImplemented);
  }
}

- (void)handleMockSignCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (![call.arguments isKindOfClass:[NSDictionary class]]) {
        result([FlutterError errorWithCode:@"invalid_args" message:@"Expected map arguments" details:nil]);
        return;
    }
    NSDictionary *args = (NSDictionary *)call.arguments;
    FlutterStandardTypedData *pdfData = args[@"pdf"];
    if (![pdfData isKindOfClass:[FlutterStandardTypedData class]] || pdfData.data.length == 0) {
        result([FlutterError errorWithCode:@"invalid_pdf" message:@"Argument 'pdf' must be a non-empty Uint8List" details:nil]);
        return;
    }
    NSString *outputPath = args[@"outputPath"];

    CieSignPdfParameters *params = [[CieSignPdfParameters alloc] init];
    params.pageIndex = 0;
    params.left = 72;
    params.bottom = 72;
    params.width = 170;
    params.height = 48;
    params.reason = @"Mock reason";
    params.name = @"Flutter User";

    NSError *error = nil;
    NSData *signedData = [self.bridge signPdf:pdfData.data
                                          pin:@"1234"
                                   appearance:params
                                        error:&error];
    if (!signedData) {
        result([FlutterError errorWithCode:@"mock_sign_failed"
                                   message:error.localizedDescription ?: @"Unable to sign PDF"
                                   details:nil]);
        return;
    }

    if (outputPath.length > 0) {
        NSError *writeError = nil;
        [signedData writeToFile:outputPath options:NSDataWritingAtomic error:&writeError];
        if (writeError) {
            NSLog(@"[CieSignFlutter] Unable to persist signed PDF: %@", writeError.localizedDescription);
        }
    }

    FlutterStandardTypedData *typedData = [FlutterStandardTypedData typedDataWithBytes:signedData];
    result(typedData);
}

@end
