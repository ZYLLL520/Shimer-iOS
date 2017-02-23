//
//  XMPPManager.h
//  Shimer <https://github.com/ZYLLL520/Shimer-iOS>
//
//  Created by 郑玉林 on 16/6/27.
//  Copyright © 2016年 Shimer.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "XMPPManagerHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMPPManager : NSObject

/**
 *  获取 XMPPManager 实例
 *
 *  @return XMPPManager 实例
 */
+ (instancetype)sharedManager;

/**
 *  开始连接
 */
- (void)connect;

/**
 *  断开连接
 */
- (void)disconnect;

/**
 *  清除缓存
 */
- (void)clearCache;


//================= 如没有特殊标注，代理的回调均在主线程上 =====================


/**
 *  登录管理类 负责登录,注销和相关操作的通知收发
 */
@property (nonatomic, strong, readonly) XMPPLoginManager *loginManager;

/**
 *  聊天管理类,负责消息的收发
 */
@property (nonatomic, strong, readonly) XMPPChatManager *chatManager;

/**
 *  好友管理类 负责获取好友列表和用户信息
 */
@property (nonatomic, strong, readonly) XMPPUserManager *userManager;

/**
 *  会话管理类 负责获取会话列表和未读数等
 */
@property (nonatomic, strong, readonly) XMPPSessionManager *sessionManager;

@end

NS_ASSUME_NONNULL_END
