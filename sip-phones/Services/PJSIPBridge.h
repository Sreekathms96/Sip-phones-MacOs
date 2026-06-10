#import <Foundation/Foundation.h>
#import "PJSIPBridgeDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface PJSIPAudioDevice : NSObject
@property(nonatomic, readonly) int deviceId;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, readonly) int inputChannels;
@property(nonatomic, readonly) int outputChannels;
- (instancetype)initWithDeviceId:(int)deviceId name:(NSString *)name inputChannels:(int)inputChannels outputChannels:(int)outputChannels;
@end

@interface PJSIPBridge : NSObject
@property(nonatomic, weak, nullable) id<PJSIPBridgeDelegate> delegate;
+ (instancetype)shared;
- (BOOL)startWithLogLevel:(int)logLevel error:(NSError **)error;
- (void)shutdown;
- (BOOL)configureAccountWithUsername:(NSString *)username password:(NSString *)password domain:(NSString *)domain port:(int)port transport:(NSString *)transport error:(NSError **)error;
- (BOOL)unregisterAccountWithError:(NSError **)error;
- (BOOL)makeCallTo:(NSString *)destination domain:(NSString *)domain port:(int)port transport:(NSString *)transport error:(NSError **)error;
- (BOOL)answerCall:(int)callId error:(NSError **)error;
- (BOOL)rejectCall:(int)callId error:(NSError **)error;
- (BOOL)hangupCall:(int)callId error:(NSError **)error;
- (BOOL)setHold:(BOOL)hold callId:(int)callId error:(NSError **)error;
- (BOOL)setMuted:(BOOL)muted callId:(int)callId error:(NSError **)error;
- (BOOL)sendDTMF:(NSString *)digits callId:(int)callId error:(NSError **)error;
- (NSArray<PJSIPAudioDevice *> *)audioDevices;
- (BOOL)setInputDevice:(int)inputDevice outputDevice:(int)outputDevice error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
