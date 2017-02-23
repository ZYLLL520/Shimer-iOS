//
//  XMPPManager.m
//  Shimer <https://github.com/ZYLLL520/Shimer-iOS>
//
//  Created by 郑玉林 on 16/6/27.
//  Copyright © 2016年 Shimer.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "XMPPManager.h"

#import <XMPPFramework/XMPPAutoPing.h>
#import <XMPPFramework/XMPPReconnect.h>
#import <XMPPFramework/XMPPFramework.h>
#import <XMPPFramework/XMPPvCardTempModule.h>
#import <XMPPFramework/XMPPMessageArchiving.h>
#import <XMPPFramework/XMPPStreamManagementMemoryStorage.h>


@interface XMPPManager () <XMPPStreamDelegate>

@property (nonatomic, strong) dispatch_queue_t delegateQueue;

/**
 *  数据流组件
 */
@property (nonatomic, strong) XMPPStream *xmppStream;

/**
 *  流管理模块
 */
@property (nonatomic, strong) XMPPStreamManagement *xmppStreamManagement;

@property (nonatomic, strong, readwrite) XMPPLoginManager *loginManager;

@property (nonatomic, strong, readwrite) XMPPChatManager *chatManager;

@property (nonatomic, strong, readwrite) XMPPUserManager *userManager;

@property (nonatomic, strong, readwrite) XMPPSessionManager *sessionManager;

@end

@implementation XMPPManager

- (void)dealloc {
    
    [self teardownStream];
}

#pragma mark - Public Methods

+ (instancetype)sharedManager {
    static XMPPManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
        
    });
    return manager;
}

- (void)connect {
    
    // MARK: 先判断本地账号是否登录
    if (![MyAccount defaultAccount].isLogon) {
        return;
    }
    
    // 登录成功且为同一账户时
    if ([XMPPJID compareJIDWithFirstString:self.loginManager.currentAccount
                                lastString:[MyAccount defaultAccount].chatName]) {
        return;
    }
    
    // 先下线
    [self disconnect];
    
    // 开始登录
    [self.loginManager loginWithAccount:[MyAccount defaultAccount].chatName
                               password:[MyAccount defaultAccount].chatPassword
                             completion:^(NSError * _Nullable error) {
                      if (!error) { // 登录成功
                          dispatch_async_on_main_queue(^{
                              // 发送上线状态
                              
                          });
                      }
    }];
}

- (void)disconnect {
    [self.loginManager disconnect];
}

- (void)clearCache {
    // 清除会话列表的缓存
    [self.sessionManager clearCache];
}

#pragma mark - XMPPStreamDelegate

/**
 * 将要与服务器连接
 **/
- (void)xmppStreamWillConnect:(XMPPStream *)sender {
    NSLog(@"将要与服务器连接...");
}

// 当tcp socket已经与远程主机连接上时会回调此代理方法
// 若App要求在后台运行，需要设置XMPPStream's enableBackgroundingOnSocket属性
- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket {
    NSLog(@"当tcp socket已经与远程主机连接上时会回调此代理方法");
}

/**
 * 当TCP与服务器建立连接后会回调此代理方法
 **/
- (void)xmppStreamDidStartNegotiation:(XMPPStream *)sender {
    NSLog(@"当TCP与服务器建立连接后会回调此代理方法");
}

// TLS传输层协议在将要验证安全设置时会回调
// 参数settings会被传到startTLS
// 此方法可以不实现的，若选择实现它，可以可以在
// 若服务端使用自签名的证书，需要在settings中添加GCDAsyncSocketManuallyEvaluateTrust=YES
// - (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings;

// 上面的方法执行后，下一步就会执行这个代理回调
// 用于在TCP握手时手动验证是否受信任
// - (void)xmppStream:(XMPPStream *)sender didReceiveTrust:(SecTrustRef)trust
//  completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
//     
//     dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//     dispatch_async(bgQueue, ^{
//         
//         SecTrustResultType result = kSecTrustResultDeny;
//         OSStatus status = SecTrustEvaluate(trust, &result);
//         
//         if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
//             completionHandler(YES);
//         }
//         else {
//             completionHandler(NO);
//         }
//     });
//}



// 当stream通过了SSL/TLS的安全验证时，会回调此代理方法
// - (void)xmppStreamDidSecure:(XMPPStream *)sender;

// 当XML流已经完全打开时（也就是与服务器的连接完成时）会回调此代理方法。此时可以安全地与服务器通信了。
- (void)xmppStreamDidConnect:(XMPPStream *)sender {
    NSLog(@"已经连接上服务器, 开始校验密码");
}

// 注册新用户成功时的回调
// - (void)xmppStreamDidRegister:(XMPPStream *)sender;

// 注册新用户失败时的回调
// - (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement *)error;

// 授权通过时的回调，也就是登录成功的回调
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    NSLog(@"--登录成功---");
}

// 授权失败时的回调，也就是登录失败时的回调
// <failure xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><account-disabled/></failure>
- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error {
    
    if ([error.name isEqualToString:@"failure"]) {
        if ([error.children.firstObject.name isEqualToString:@"account-disabled"]) {
            NSLog(@"账号禁用");
        }
    }
}

// 将要绑定JID resource时的回调，这是授权程序的标准部分，当验证JID用户名通过时，下一步就验证resource。若使用标准绑定处理，return nil或者不要实现此方法
// - (id <XMPPCustomBinding>)xmppStreamWillBind:(XMPPStream *)sender;

// 如果服务器出现resouce冲突而导致不允许resource选择时，会回调此代理方法。返回指定的resource或者返回nil让服务器自动帮助我们来选择。一般不用实现它。
// - (NSString *)xmppStream:(XMPPStream *)sender alternativeResourceForConflictingResource:(NSString *)conflictingResource;

// 将要发送IQ（消息查询）时的回调
// - (XMPPIQ *)xmppStream:(XMPPStream *)sender willReceiveIQ:(XMPPIQ *)iq;

// 将要接收到消息时的回调
- (XMPPMessage *)xmppStream:(XMPPStream *)sender willReceiveMessage:(XMPPMessage *)message {
    return message;
}

// 将要接收到用户在线状态时的回调
- (XMPPPresence *)xmppStream:(XMPPStream *)sender willReceivePresence:(XMPPPresence *)presence {
    return presence;
}

// 当xmppStream:willReceiveX:(也就是前面这三个API回调后)，过滤了stanza，会回调此代理方法。
// 通过实现此代理方法，可以知道被过滤的原因，有一定的帮助。
// - (void)xmppStreamDidFilterStanza:(XMPPStream *)sender;

// 在接收了IQ（消息查询后）会回调此代理方法
//- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
//    NSLog(@"接收到 iq --%@", iq);
//    return YES;
//}

// 在接收了消息后会回调此代理方法
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    
}

// 在接收了用户在线状态消息后会回调此代理方法
- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence {
    
}

// 在接收IQ/messag、presence出错时，会回调此代理方法
- (void)xmppStream:(XMPPStream *)sender didReceiveError:(NSXMLElement *)error {
    
    for (DDXMLNode *node in error.children) { // 被踢下线
        if ([node.name isEqualToString:@"conflict"]) {
            // TODO: 通知服务器下线....
            break;
        }
    }
}

// 将要发送IQ（消息查询时）时会回调此代理方法
// - (XMPPIQ *)xmppStream:(XMPPStream *)sender willSendIQ:(XMPPIQ *)iq;

// 在将要发送消息时，会回调此代理方法
- (XMPPMessage *)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message {
    return message;
}

// 在将要发送用户在线状态信息时，会回调此方法
- (XMPPPresence *)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence {
    return presence;
}

// 在发送IQ（消息查询）成功后会回调此代理方法
- (void)xmppStream:(XMPPStream *)sender didSendIQ:(XMPPIQ *)iq {

}
// 在发送消息成功后，会回调此代理方法
- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message {
    
}

// 在发送用户在线状态信息成功后，会回调此方法
- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence {
    
}

// 在发送IQ（消息查询）失败后会回调此代理方法
- (void)xmppStream:(XMPPStream *)sender didFailToSendIQ:(XMPPIQ *)iq error:(NSError *)error {

}

// 在发送消息失败后，会回调此代理方法
- (void)xmppStream:(XMPPStream *)sender didFailToSendMessage:(XMPPMessage *)message error:(NSError *)error {
    
}

// 在发送用户在线状态失败信息后，会回调此方法
- (void)xmppStream:(XMPPStream *)sender didFailToSendPresence:(XMPPPresence *)presence error:(NSError *)error {
    
}

// 当修改了JID信息时，会回调此代理方法
- (void)xmppStreamDidChangeMyJID:(XMPPStream *)xmppStream {
    
}

// 当Stream被告知与服务器断开连接时会回调此代理方法
- (void)xmppStreamWasToldToDisconnect:(XMPPStream *)sender {
    
}

// 当发送了</stream:stream>节点时，会回调此代理方法
- (void)xmppStreamDidSendClosingStreamStanza:(XMPPStream *)sender {
    
}

// 连接超时时会回调此代理方法
- (void)xmppStreamConnectDidTimeout:(XMPPStream *)sender {
    NSLog(@"连接超时");
}

// 当与服务器断开连接后，会回调此代理方法
- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error {
    NSLog(@"与服务器断开连接");
}

// p2p类型相关的
// - (void)xmppStream:(XMPPStream *)sender didReceiveP2PFeatures:(NSXMLElement *)streamFeatures;
// - (void)xmppStream:(XMPPStream *)sender willSendP2PFeatures:(NSXMLElement *)streamFeatures;

#if DEBUG

// Module
- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module {
    NSLog(@"装配 -- %@", module);
}

- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module {
    NSLog(@"卸载 -- %@", module);
}

#endif

// 当发送非XMPP元素节点时，会回调此代理方法。也就是说，如果发送的element不是
// <iq>, <message> 或者 <presence>，那么就会回调此代理方法
// - (void)xmppStream:(XMPPStream *)sender didSendCustomElement:(NSXMLElement *)element;

// 当接收到非XMPP元素节点时，会回调此代理方法。也就是说，如果接收的element不是
// <iq>, <message> 或者 <presence>，那么就会回调此代理方法
// - (void)xmppStream:(XMPPStream *)sender didReceiveCustomElement:(NSXMLElement *)element;

#pragma mark - Custom Methods

- (void)teardownStream {
    
    [_xmppStream removeDelegate:self delegateQueue:_delegateQueue];
    
    [_loginManager.xmppAutoPing deactivate];
    [_loginManager.xmppReconnect deactivate];
    [_xmppStreamManagement deactivate];
    [_userManager.vCardModule deactivate];
    [_userManager.xmppRoster deactivate];
    [_sessionManager.xmppMessageArchiving deactivate];
    
    [_xmppStream disconnect];
    
    _xmppStream = nil;
    _xmppStreamManagement = nil;
    _loginManager = nil;
    _chatManager = nil;
    _userManager = nil;
    _sessionManager = nil;
}

#pragma mark - Lazy Load

- (XMPPStream *)xmppStream {
    if (_xmppStream == nil) {
        _xmppStream = [[XMPPStream alloc] init];
        [_xmppStream setHostName:kHostName];    // 设置xmpp服务器地址
        [_xmppStream setHostPort:kHostPort];    // 设置xmpp端口
        [_xmppStream setKeepAliveInterval:kAliveInterval];  // 心跳包时间
        
        [_xmppStream addDelegate:self delegateQueue:self.delegateQueue];
        
        // 启动心跳包
        [self.loginManager.xmppAutoPing activate:_xmppStream];
        
        // 接入断线重连模块
        [self.loginManager.xmppReconnect activate:_xmppStream];
        
        // 接入流管理模块
        [self.xmppStreamManagement activate:_xmppStream];
        
        // 接入用户信息模块
        [self.userManager.vCardModule activate:_xmppStream];
        
        // 接入好友关系模块
        [self.userManager.xmppRoster activate:_xmppStream];
        
        // 接入消息存储模块
        [self.sessionManager.xmppMessageArchiving activate:_xmppStream];
    }
    return _xmppStream;
}

- (XMPPStreamManagement *)xmppStreamManagement {
    if (!_xmppStreamManagement) {
        XMPPStreamManagementMemoryStorage *storage = [XMPPStreamManagementMemoryStorage new];
        _xmppStreamManagement = [[XMPPStreamManagement alloc] initWithStorage:storage];
        _xmppStreamManagement.autoResume = YES;
        [_xmppStreamManagement addDelegate:self.loginManager delegateQueue:self.delegateQueue];
    }
    return _xmppStreamManagement;
}

- (dispatch_queue_t)delegateQueue {
    if (_delegateQueue == nil) {
        _delegateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    return _delegateQueue;
}

- (XMPPLoginManager *)loginManager {
    if (_loginManager == nil) {
        _loginManager = [[XMPPLoginManager alloc] initWithXMPPStream:self.xmppStream];
        [_xmppStream addDelegate:_loginManager delegateQueue:self.delegateQueue];
    }
    return _loginManager;
}

- (XMPPChatManager *)chatManager {
    if (_chatManager == nil) {
        _chatManager = [[XMPPChatManager alloc] initWithXMPPStream:self.xmppStream];
        [_xmppStream addDelegate:_chatManager delegateQueue:self.delegateQueue];
    }
    return _chatManager;
}

- (XMPPUserManager *)userManager {
    if (_userManager == nil) {
        _userManager = [[XMPPUserManager alloc] initWithXMPPStream:self.xmppStream];
    }
    return _userManager;
}

- (XMPPSessionManager *)sessionManager {
    if (!_sessionManager) {
        _sessionManager = [[XMPPSessionManager alloc] initWithXMPPStream:self.xmppStream];
        [_xmppStream addDelegate:_sessionManager delegateQueue:self.delegateQueue];
    }
    return _sessionManager;
}

@end
