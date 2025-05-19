#import "FlutterFacebookSdkNewPlugin.h"
#if __has_include(<flutter_facebook_sdk_new/flutter_facebook_sdk_new-Swift.h>)
#import <flutter_facebook_sdk_new/flutter_facebook_sdk_new-Swift.h>
#else
#import "flutter_facebook_sdk_new-Swift.h"
#endif

@implementation FlutterFacebookSdkNewPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterFacebookSdkNewPlugin registerWithRegistrar:registrar];
}
@end
