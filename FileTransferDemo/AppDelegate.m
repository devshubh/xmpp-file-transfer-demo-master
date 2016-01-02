//
//  AppDelegate.m
//  FileTransferDemo
//
//  Created by Jonathon Staff on 11/1/14.
//  Copyright (c) 2014 nplexity. All rights reserved.
//

#import "AppDelegate.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "XMPPLogging.h"
#import "DSXMPP_AIO.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface AppDelegate ()

{
    
    DSXMPP_AIO *sharedXmpp;
}
@end

@implementation AppDelegate


#pragma mark - UIApplicationDelegate Methods

- (BOOL)          application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
//    sharedXmpp = [DSXMPP_AIO shareInstance];
//    
//    [sharedXmpp login:@"shubh@canopus-pc" password:@"123"];
//    
    
  [DDLog addLogger:[DDTTYLogger sharedInstance]
      withLogLevel:XMPP_LOG_LEVEL_VERBOSE | XMPP_LOG_FLAG_TRACE | XMPP_LOG_FLAG_SEND_RECV];
  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

- (void)dealloc
{
}


@end
