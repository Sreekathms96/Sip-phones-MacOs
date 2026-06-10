#import "PJSIPBridge.h"
#import <pjsua-lib/pjsua.h>

static NSString * const PJSIPBridgeErrorDomain = @"com.sipphones.softphone.pjsip";

@implementation PJSIPAudioDevice
- (instancetype)initWithDeviceId:(int)deviceId name:(NSString *)name inputChannels:(int)inputChannels outputChannels:(int)outputChannels {
    self = [super init];
    if (self) {
        _deviceId = deviceId;
        _name = [name copy];
        _inputChannels = inputChannels;
        _outputChannels = outputChannels;
    }
    return self;
}
@end

@interface PJSIPBridge ()
@property(nonatomic) BOOL started;
@property(nonatomic) pjsua_acc_id accountId;
@property(nonatomic) pjsua_conf_port_id capturePort;
@property(nonatomic) pjsua_conf_port_id playbackPort;
@end

@implementation PJSIPBridge

+ (instancetype)shared {
    static PJSIPBridge *bridge;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bridge = [[PJSIPBridge alloc] init];
    });
    return bridge;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _accountId = PJSUA_INVALID_ID;
        _capturePort = PJSUA_INVALID_ID;
        _playbackPort = PJSUA_INVALID_ID;
    }
    return self;
}

static PJSIPBridge *CurrentBridge(void) {
    return [PJSIPBridge shared];
}

static NSError *BridgeError(pj_status_t status, NSString *context) {
    char buffer[PJ_ERR_MSG_SIZE];
    pj_strerror(status, buffer, sizeof(buffer));
    NSString *message = [NSString stringWithFormat:@"%@: %s", context, buffer];
    return [NSError errorWithDomain:PJSIPBridgeErrorDomain code:status userInfo:@{NSLocalizedDescriptionKey: message}];
}

static void DispatchToDelegate(void (^block)(id<PJSIPBridgeDelegate> delegate)) {
    id<PJSIPBridgeDelegate> delegate = CurrentBridge().delegate;
    if (!delegate) { return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        id<PJSIPBridgeDelegate> strongDelegate = CurrentBridge().delegate;
        if (strongDelegate) { block(strongDelegate); }
    });
}

static NSString *StringFromPJ(const pj_str_t *string) {
    if (!string || !string->ptr || string->slen <= 0) { return @""; }
    return [[NSString alloc] initWithBytes:string->ptr length:(NSUInteger)string->slen encoding:NSUTF8StringEncoding] ?: @"";
}

static void on_reg_state(pjsua_acc_id acc_id) {
    pjsua_acc_info info;
    if (pjsua_acc_get_info(acc_id, &info) != PJ_SUCCESS) { return; }
    NSString *reason = StringFromPJ(&info.status_text);
    BOOL registered = info.status == PJSIP_SC_OK;
    DispatchToDelegate(^(id<PJSIPBridgeDelegate> delegate) {
        [delegate pjsipRegistrationChanged:registered statusCode:info.status reason:reason];
    });
}

static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata) {
    PJ_UNUSED_ARG(acc_id);
    PJ_UNUSED_ARG(rdata);
    pjsua_call_info info;
    if (pjsua_call_get_info(call_id, &info) != PJ_SUCCESS) { return; }
    NSString *remoteURI = StringFromPJ(&info.remote_info);
    NSString *displayName = StringFromPJ(&info.remote_contact);
    DispatchToDelegate(^(id<PJSIPBridgeDelegate> delegate) {
        [delegate pjsipIncomingCall:call_id remoteURI:remoteURI displayName:displayName.length ? displayName : remoteURI];
    });
}

static NSString *CallStateName(pjsip_inv_state state) {
    switch (state) {
        case PJSIP_INV_STATE_NULL: return @"idle";
        case PJSIP_INV_STATE_CALLING: return @"calling";
        case PJSIP_INV_STATE_INCOMING: return @"incoming";
        case PJSIP_INV_STATE_EARLY: return @"ringing";
        case PJSIP_INV_STATE_CONNECTING: return @"connecting";
        case PJSIP_INV_STATE_CONFIRMED: return @"connected";
        case PJSIP_INV_STATE_DISCONNECTED: return @"ended";
    }
    return @"failed";
}

static void on_call_state(pjsua_call_id call_id, pjsip_event *event) {
    PJ_UNUSED_ARG(event);
    pjsua_call_info info;
    if (pjsua_call_get_info(call_id, &info) != PJ_SUCCESS) { return; }
    NSString *reason = StringFromPJ(&info.last_status_text);
    NSString *state = CallStateName(info.state);
    DispatchToDelegate(^(id<PJSIPBridgeDelegate> delegate) {
        [delegate pjsipCallStateChanged:call_id state:state statusCode:info.last_status reason:reason];
    });
}

static void on_call_media_state(pjsua_call_id call_id) {
    pjsua_call_info info;
    if (pjsua_call_get_info(call_id, &info) != PJ_SUCCESS) { return; }
    for (unsigned i = 0; i < info.media_cnt; i++) {
        if (info.media[i].type == PJMEDIA_TYPE_AUDIO && info.media[i].status == PJSUA_CALL_MEDIA_ACTIVE) {
            pjsua_conf_connect(info.conf_slot, 0);
            pjsua_conf_connect(0, info.conf_slot);
            DispatchToDelegate(^(id<PJSIPBridgeDelegate> delegate) {
                [delegate pjsipCallMediaActive:call_id];
            });
        }
    }
}

static void log_writer(int level, const char *data, int len) {
    NSString *message = [[NSString alloc] initWithBytes:data length:(NSUInteger)len encoding:NSUTF8StringEncoding] ?: @"";
    DispatchToDelegate(^(id<PJSIPBridgeDelegate> delegate) {
        [delegate pjsipLogMessage:[message stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] level:level];
    });
}

- (BOOL)startWithLogLevel:(int)logLevel error:(NSError **)error {
    if (self.started) { return YES; }

    pj_status_t status = pjsua_create();
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to create PJSUA"); }
        return NO;
    }

    pjsua_config config;
    pjsua_config_default(&config);
    config.cb.on_reg_state = &on_reg_state;
    config.cb.on_incoming_call = &on_incoming_call;
    config.cb.on_call_state = &on_call_state;
    config.cb.on_call_media_state = &on_call_media_state;
    config.max_calls = 8;

    pjsua_logging_config loggingConfig;
    pjsua_logging_config_default(&loggingConfig);
    loggingConfig.console_level = logLevel;
    loggingConfig.level = logLevel;
    loggingConfig.cb = &log_writer;

    pjsua_media_config mediaConfig;
    pjsua_media_config_default(&mediaConfig);
    mediaConfig.clock_rate = 48000;
    mediaConfig.snd_clock_rate = 48000;
    mediaConfig.ec_tail_len = 200;
    mediaConfig.quality = 10;

    status = pjsua_init(&config, &loggingConfig, &mediaConfig);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to initialize PJSUA"); }
        pjsua_destroy();
        return NO;
    }

    pjsua_transport_config udpConfig;
    pjsua_transport_config_default(&udpConfig);
    udpConfig.port = 0;
    status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &udpConfig, NULL);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to create UDP transport"); }
        pjsua_destroy();
        return NO;
    }

    pjsua_transport_config tcpConfig;
    pjsua_transport_config_default(&tcpConfig);
    tcpConfig.port = 0;
    status = pjsua_transport_create(PJSIP_TRANSPORT_TCP, &tcpConfig, NULL);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to create TCP transport"); }
        pjsua_destroy();
        return NO;
    }

    pjsua_transport_config tlsConfig;
    pjsua_transport_config_default(&tlsConfig);
    tlsConfig.port = 0;
    status = pjsua_transport_create(PJSIP_TRANSPORT_TLS, &tlsConfig, NULL);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to create TLS transport"); }
        pjsua_destroy();
        return NO;
    }

    status = pjsua_start();
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to start PJSUA"); }
        pjsua_destroy();
        return NO;
    }

    self.started = YES;
    return YES;
}

- (void)shutdown {
    if (!self.started) { return; }
    pjsua_destroy();
    self.started = NO;
    self.accountId = PJSUA_INVALID_ID;
}

- (BOOL)configureAccountWithUsername:(NSString *)username password:(NSString *)password domain:(NSString *)domain port:(int)port transport:(NSString *)transport error:(NSError **)error {
    if (self.accountId != PJSUA_INVALID_ID) {
        pjsua_acc_del(self.accountId);
        self.accountId = PJSUA_INVALID_ID;
    }

    NSString *transportLower = transport.lowercaseString;
    NSString *idURI = [NSString stringWithFormat:@"sip:%@@%@", username, domain];
    NSString *registrar = [NSString stringWithFormat:@"sip:%@:%d;transport=%@", domain, port, transportLower];
    NSString *proxy = [NSString stringWithFormat:@"sip:%@:%d;transport=%@", domain, port, transportLower];

    pjsua_acc_config accountConfig;
    pjsua_acc_config_default(&accountConfig);
    accountConfig.id = pj_str((char *)idURI.UTF8String);
    accountConfig.reg_uri = pj_str((char *)registrar.UTF8String);
    accountConfig.cred_count = 1;
    accountConfig.cred_info[0].realm = pj_str((char *)"*");
    accountConfig.cred_info[0].scheme = pj_str((char *)"digest");
    accountConfig.cred_info[0].username = pj_str((char *)username.UTF8String);
    accountConfig.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    accountConfig.cred_info[0].data = pj_str((char *)password.UTF8String);
    accountConfig.proxy_cnt = 1;
    accountConfig.proxy[0] = pj_str((char *)proxy.UTF8String);
    accountConfig.reg_retry_interval = 30;

    pj_status_t status = pjsua_acc_add(&accountConfig, PJ_TRUE, &_accountId);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to add SIP account"); }
        return NO;
    }
    return YES;
}

- (BOOL)unregisterAccountWithError:(NSError **)error {
    if (self.accountId == PJSUA_INVALID_ID) { return YES; }
    pj_status_t status = pjsua_acc_set_registration(self.accountId, PJ_FALSE);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to unregister account"); }
        return NO;
    }
    return YES;
}

- (BOOL)makeCallTo:(NSString *)destination domain:(NSString *)domain port:(int)port transport:(NSString *)transport error:(NSError **)error {
    if (self.accountId == PJSUA_INVALID_ID) {
        if (error) {
            *error = [NSError errorWithDomain:PJSIPBridgeErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: @"SIP account is not registered."}];
        }
        return NO;
    }
    NSString *target = [destination containsString:@"@"] ? destination : [NSString stringWithFormat:@"%@@%@", destination, domain];
    NSString *uri = [target hasPrefix:@"sip:"] ? target : [NSString stringWithFormat:@"sip:%@", target];
    if (![uri containsString:@";transport="]) {
        uri = [uri stringByAppendingFormat:@":%d;transport=%@", port, transport.lowercaseString];
    }
    pj_str_t pjURI = pj_str((char *)uri.UTF8String);
    pjsua_call_id callId;
    pj_status_t status = pjsua_call_make_call(self.accountId, &pjURI, NULL, NULL, NULL, &callId);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to place call"); }
        return NO;
    }
    return YES;
}

- (BOOL)answerCall:(int)callId error:(NSError **)error {
    pj_status_t status = pjsua_call_answer(callId, 200, NULL, NULL);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to answer call"); }
        return NO;
    }
    return YES;
}

- (BOOL)rejectCall:(int)callId error:(NSError **)error {
    pj_status_t status = pjsua_call_answer(callId, 486, NULL, NULL);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to reject call"); }
        return NO;
    }
    return YES;
}

- (BOOL)hangupCall:(int)callId error:(NSError **)error {
    pj_status_t status = pjsua_call_hangup(callId, 0, NULL, NULL);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to hang up call"); }
        return NO;
    }
    return YES;
}

- (BOOL)setHold:(BOOL)hold callId:(int)callId error:(NSError **)error {
    pj_status_t status = hold ? pjsua_call_set_hold(callId, NULL) : pjsua_call_reinvite(callId, PJSUA_CALL_UNHOLD, NULL);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, hold ? @"Unable to hold call" : @"Unable to resume call"); }
        return NO;
    }
    return YES;
}

- (BOOL)setMuted:(BOOL)muted callId:(int)callId error:(NSError **)error {
    pjsua_call_info info;
    pj_status_t status = pjsua_call_get_info(callId, &info);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to inspect call media"); }
        return NO;
    }
    status = muted ? pjsua_conf_disconnect(0, info.conf_slot) : pjsua_conf_connect(0, info.conf_slot);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, muted ? @"Unable to mute microphone" : @"Unable to unmute microphone"); }
        return NO;
    }
    return YES;
}

- (BOOL)sendDTMF:(NSString *)digits callId:(int)callId error:(NSError **)error {
    pj_str_t pjDigits = pj_str((char *)digits.UTF8String);
    pj_status_t status = pjsua_call_dial_dtmf(callId, &pjDigits);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to send DTMF"); }
        return NO;
    }
    return YES;
}

- (NSArray<PJSIPAudioDevice *> *)audioDevices {
    unsigned count = 64;
    pjmedia_aud_dev_info devices[64];
    pj_status_t status = pjsua_enum_aud_devs(devices, &count);
    if (status != PJ_SUCCESS) { return @[]; }

    NSMutableArray<PJSIPAudioDevice *> *result = [NSMutableArray arrayWithCapacity:count];
    for (unsigned i = 0; i < count; i++) {
        NSString *name = [[NSString alloc] initWithBytes:devices[i].name length:strlen(devices[i].name) encoding:NSUTF8StringEncoding] ?: @"Audio Device";
        [result addObject:[[PJSIPAudioDevice alloc] initWithDeviceId:(int)i name:name inputChannels:devices[i].input_count outputChannels:devices[i].output_count]];
    }
    return result;
}

- (BOOL)setInputDevice:(int)inputDevice outputDevice:(int)outputDevice error:(NSError **)error {
    pj_status_t status = pjsua_set_snd_dev(inputDevice, outputDevice);
    if (status != PJ_SUCCESS) {
        if (error) { *error = BridgeError(status, @"Unable to select audio devices"); }
        return NO;
    }
    return YES;
}

@end
