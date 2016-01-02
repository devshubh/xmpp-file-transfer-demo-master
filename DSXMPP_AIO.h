//
//  DSXMPP_AIO.h
//  FileTransferDemo
//
//  Created by CANOPUS21 on 16/10/15.
//  Copyright (c) 2015 nplexity. All rights reserved.
//



//-----------------Message-Delegate--------------------//


@protocol UserMessageDelegate <NSObject>
@optional

- (void)newMessageReceived:(NSDictionary *)messageContent;

- (void)newFileRecieved;
@end


#define HostName @"111.118.246.34"
#define HostPort 5222
#define Userpostfix @"@canopus-pc"

//#define HostName @"localhost"
//#define HostPort 5222
//#define Userpostfix @"@barapp.local"





#import <Foundation/Foundation.h>
#import "XMPPFramework.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "XMPPLogging.h"
#import "XMLReader.h"


@interface DSXMPP_AIO : NSObject<XMPPAutoPingDelegate,XMPPIncomingFileTransferDelegate,XMPPMUCDelegate,XMPPRoomDelegate,XMPPvCardTempModuleDelegate,XMPPvCardAvatarDelegate,XMPPAutoTimeDelegate,XMPPStreamDelegate,XMPPCapabilitiesDelegate,XMPPJabberRPCModuleDelegate,XMPPRosterDelegate>

{
    XMPPLastActivity *xmppLastActivity;
    XMPPStream *xmppStream;
    XMPPReconnect *xmppReconnect;
    XMPPRoster *xmppRoster;
    XMPPRosterCoreDataStorage *xmppRosterStorage;
    XMPPvCardCoreDataStorage *xmppvCardStorage;
    XMPPvCardTempModule *xmppvCardTempModule;
    XMPPvCardAvatarModule *xmppvCardAvatarModule;
    XMPPCapabilities *xmppCapabilities;
    XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
    XMPPMessageArchiving *xmppMessageArchivingModule;
    XMPPMessageArchivingCoreDataStorage *xmppMessageArchivingDataStorage;
    XMPPIncomingFileTransfer *xmppIncomingFileTransfer;
    XMPPOutgoingFileTransfer *xmppOutGoingFileTransfer;
    XMPPMessageDeliveryReceipts *xmppMessageDelieveryReciept;
    BOOL customCertEvaluation;
    
    BOOL isXmppConnected;
}

@property (nonatomic, strong, readonly) XMPPStream *xmppStream;
@property (nonatomic, strong, readonly) XMPPReconnect *xmppReconnect;
@property (nonatomic, strong, readonly) XMPPRoster *xmppRoster;
@property (nonatomic, strong, readonly) XMPPRosterCoreDataStorage *xmppRosterStorage;
@property (nonatomic, strong, readonly) XMPPvCardTempModule *xmppvCardTempModule;
@property (nonatomic, strong, readonly) XMPPvCardAvatarModule *xmppvCardAvatarModule;
@property (nonatomic, strong, readonly) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, strong, readonly) XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
@property (nonatomic, strong, readonly) XMPPMessageArchiving *xmppMessageArchivingModule;
@property (nonatomic, strong, readonly) XMPPMessage * messages;
@property (nonatomic, strong, readonly) XMPPMessageArchivingCoreDataStorage *xmppMessageArchivingDataStorage;
@property (nonatomic, strong, readonly) XMPPLastActivity *xmppLastActivity;
@property (nonatomic, strong, readonly) XMPPIncomingFileTransfer *xmppIncomingFileTransfer;
@property (nonatomic, strong, readonly) XMPPOutgoingFileTransfer *xmppOutGoingFileTransfer;
@property (nonatomic, strong, readonly) XMPPMessageDeliveryReceipts *xmppMessageDelieveryReceipt;


@property (strong, nonatomic)NSMutableArray *FriendArray;
@property (strong, nonatomic)NSMutableArray *groupsArray;
@property (nonatomic, strong) NSString *postfix;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;

@property(nonatomic, assign) id<UserMessageDelegate>messageDelegate;

+(DSXMPP_AIO *)shareInstance;
- (void)setupStream;
- (void)teardownStream;

- (void)goOnline;
- (void)goOffline;

- (NSManagedObjectContext *)managedObjectContext_roster;
- (NSManagedObjectContext *)managedObjectContext_capabilities;

- (BOOL)connect;
- (void)disconnect;
-(void)getLastActivityOfUser;
-(void)registration:(NSString*)username password:(NSString*)password;
-(void)login:(NSString*)username password:(NSString*)password;
-(void)sendMessage:(NSString *)messageString to:(NSString *)name;


@end
