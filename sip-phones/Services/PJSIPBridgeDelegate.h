#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PJSIPBridgeDelegate <NSObject>
- (void)pjsipRegistrationChanged:(BOOL)isRegistered statusCode:(NSInteger)statusCode reason:(NSString *)reason;
- (void)pjsipIncomingCall:(int)callId remoteURI:(NSString *)remoteURI displayName:(NSString *)displayName;
- (void)pjsipCallStateChanged:(int)callId state:(NSString *)state statusCode:(NSInteger)statusCode reason:(NSString *)reason;
- (void)pjsipCallMediaActive:(int)callId;
- (void)pjsipLogMessage:(NSString *)message level:(NSInteger)level;
@end

NS_ASSUME_NONNULL_END
