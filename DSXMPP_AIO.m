//
//  DSXMPP_AIO.m
//  FileTransferDemo
//
//  Created by CANOPUS21 on 16/10/15.
//  Copyright (c) 2015 nplexity. All rights reserved.
//

#import "DSXMPP_AIO.h"
NSString *const kXMPPmyJID = @"kXMPPmyJID";
NSString *const kXMPPmyPassword = @"kXMPPmyPassword";
NSString *const kXMPPmyPostfix = @"";
NSString *const kQXMLNSDiscoItems = @"http://jabber.org/protocol/disco#items";
NSString *const kQXMLNSRoaster = @"jabber:iq:roster";


static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation DSXMPP_AIO


@synthesize xmppStream;
@synthesize xmppReconnect;
@synthesize xmppRoster;
@synthesize xmppRosterStorage;
@synthesize xmppvCardTempModule;
@synthesize xmppvCardAvatarModule;
@synthesize xmppCapabilities;
@synthesize xmppCapabilitiesStorage;
@synthesize xmppMessageArchivingModule;
@synthesize messages;
@synthesize xmppMessageArchivingDataStorage;
@synthesize xmppLastActivity;
@synthesize FriendArray,groupsArray;
@synthesize xmppIncomingFileTransfer;
@synthesize xmppMessageDelieveryReceipt;
@synthesize xmppOutGoingFileTransfer;

+(DSXMPP_AIO *)shareInstance
{
    static id sharedInstance;
    static dispatch_once_t pred = 0;
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
        
    });
    
    @synchronized(sharedInstance) {
        return sharedInstance;
    }
}

-(instancetype)init
{
    self = [super init];
    FriendArray = [NSMutableArray new];
    groupsArray = [NSMutableArray new];
    return self;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (NSManagedObjectContext *)managedObjectContext_roster
{
    return [xmppRosterStorage mainThreadManagedObjectContext];
}

- (NSManagedObjectContext *)managedObjectContext_capabilities
{
    return [xmppCapabilitiesStorage mainThreadManagedObjectContext];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupStream
{
    NSString *myjid =  [[NSUserDefaults standardUserDefaults]valueForKey:@"myjid"];
    [[NSUserDefaults standardUserDefaults]setValue:myjid forKey:kXMPPmyJID];
    [[NSUserDefaults standardUserDefaults] setValue:@"123" forKey:kXMPPmyPassword];
    [[NSUserDefaults standardUserDefaults] setValue:kXMPPmyPostfix forKey:@"postfix"];
    
    _username = [[NSUserDefaults standardUserDefaults]valueForKey:@"kXMPPmyJID"];
    NSAssert(xmppStream == nil, @"Method setupStream invoked multiple times");
    _postfix = Userpostfix;
    // Setup xmpp stream
    //
    // The XMPPStream is the base class for all activity.
    // Everything else plugs into the xmppStream, such as modules/extensions and delegates.
    
    xmppStream = [[XMPPStream alloc] init];
    
#if !TARGET_IPHONE_SIMULATOR
    {
        // Want xmpp to run in the background?
        //
        // P.S. - The simulator doesn't support backgrounding yet.
        //        When you try to set the associated property on the simulator, it simply fails.
        //        And when you background an app on the simulator,
        //        it just queues network traffic til the app is foregrounded again.
        //        We are patiently waiting for a fix from Apple.
        //        If you do enableBackgroundingOnSocket on the simulator,
        //        you will simply see an error message from the xmpp stack when it fails to set the property.
        
        xmppStream.enableBackgroundingOnSocket = YES;
    }
#endif
    
    // Setup reconnect
    //
    // The XMPPReconnect module monitors for "accidental disconnections" and
    // automatically reconnects the stream for you.
    // There's a bunch more information in the XMPPReconnect header file.
    
    xmppReconnect = [[XMPPReconnect alloc] init];
    
    // Setup roster
    //
    // The XMPPRoster handles the xmpp protocol stuff related to the roster.
    // The storage for the roster is abstracted.
    // So you can use any storage mechanism you want.
    // You can store it all in memory, or use core data and store it on disk, or use core data with an in-memory store,
    // or setup your own using raw SQLite, or create your own storage mechanism.
    // You can do it however you like! It's your application.
    // But you do need to provide the roster with some storage facility.
    
    xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] init];
    xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] initWithInMemoryStore];
    
    xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:xmppRosterStorage];
    
    xmppRoster.autoFetchRoster = YES;
    xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    // Setup vCard support
    //
    // The vCard Avatar module works in conjuction with the standard vCard Temp module to download user avatars.
    // The XMPPRoster will automatically integrate with XMPPvCardAvatarModule to cache roster photos in the roster.
    
    xmppvCardStorage = [XMPPvCardCoreDataStorage sharedInstance];
    xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:xmppvCardStorage];
    
    xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:xmppvCardTempModule];
    
    // Setup capabilities
    //
    // The XMPPCapabilities module handles all the complex hashing of the caps protocol (XEP-0115).
    // Basically, when other clients broadcast their presence on the network
    // they include information about what capabilities their client supports (audio, video, file transfer, etc).
    // But as you can imagine, this list starts to get pretty big.
    // This is where the hashing stuff comes into play.
    // Most people running the same version of the same client are going to have the same list of capabilities.
    // So the protocol defines a standardized way to hash the list of capabilities.
    // Clients then broadcast the tiny hash instead of the big list.
    // The XMPPCapabilities protocol automatically handles figuring out what these hashes mean,
    // and also persistently storing the hashes so lookups aren't needed in the future.
    //
    // Similarly to the roster, the storage of the module is abstracted.
    // You are strongly encouraged to persist caps information across sessions.
    //
    // The XMPPCapabilitiesCoreDataStorage is an ideal solution.
    // It can also be shared amongst multiple streams to further reduce hash lookups.
    xmppMessageArchivingModule = [[XMPPMessageArchiving alloc] initWithMessageArchivingStorage:[XMPPMessageArchivingCoreDataStorage sharedInstance]];
    [xmppMessageArchivingModule setClientSideMessageArchivingOnly:YES];
    xmppCapabilitiesStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
    xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:xmppCapabilitiesStorage];
    
    xmppLastActivity = [[XMPPLastActivity alloc] initWithDispatchQueue:dispatch_get_main_queue()];
    
    xmppCapabilities.autoFetchHashedCapabilities = YES;
    xmppCapabilities.autoFetchNonHashedCapabilities = YES;
   
    xmppMessageDelieveryReceipt = [[XMPPMessageDeliveryReceipts alloc] initWithDispatchQueue:dispatch_get_main_queue()];
    xmppMessageDelieveryReceipt.autoSendMessageDeliveryReceipts = YES;
    xmppMessageDelieveryReceipt.autoSendMessageDeliveryRequests = YES;
    
    xmppOutGoingFileTransfer = [[XMPPOutgoingFileTransfer alloc]initWithDispatchQueue:dispatch_get_main_queue()];
    
    // Activate xmpp modules
    [xmppLastActivity activate:xmppStream];
    [xmppReconnect         activate:xmppStream];
    [xmppRoster            activate:xmppStream];
    [xmppvCardTempModule   activate:xmppStream];
    [xmppvCardAvatarModule activate:xmppStream];
    [xmppCapabilities      activate:xmppStream];
    [xmppMessageArchivingModule activate:xmppStream];
    [xmppMessageDelieveryReceipt activate:xmppStream];

    // Add ourself as a delegate to anything we may be interested in
    [xmppMessageArchivingModule addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [xmppLastActivity addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [xmppIncomingFileTransfer addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [xmppMessageDelieveryReciept addDelegate:self delegateQueue:dispatch_get_main_queue()];

    
    // Optional:
    //
    // Replace me with the proper domain and port.
    // The example below is setup for a typical google talk account.
    //
    // If you don't supply a hostName, then it will be automatically resolved using the JID (below).
    // For example, if you supply a JID like 'user@quack.com/rsrc'
    // then the xmpp framework will follow the xmpp specification, and do a SRV lookup for quack.com.
    //
    // If you don't specify a hostPort, then the default (5222) will be used.
    
    [xmppStream setHostName:HostName];
    [xmppStream setHostPort:HostPort];
    
    
    // You may need to alter these settings depending on the server you're connecting to
    customCertEvaluation = YES;
}

- (void)teardownStream
{
    [xmppStream removeDelegate:self];
    [xmppRoster removeDelegate:self];
    
    [xmppReconnect         deactivate];
    [xmppRoster            deactivate];
    [xmppvCardTempModule   deactivate];
    [xmppvCardAvatarModule deactivate];
    [xmppCapabilities      deactivate];
    [xmppLastActivity deactivate];
    [xmppStream disconnect];
    
    xmppStream = nil;
    xmppReconnect = nil;
    xmppRoster = nil;
    xmppRosterStorage = nil;
    xmppvCardStorage = nil;
    xmppvCardTempModule = nil;
    xmppvCardAvatarModule = nil;
    xmppCapabilities = nil;
    xmppCapabilitiesStorage = nil;
    xmppLastActivity = nil;
}
-(void)getLastActivityOfUser
{
    XMPPLastActivity *activity = [self xmppLastActivity];
    
    [activity sendLastActivityQueryToJID:[[NSUserDefaults standardUserDefaults]valueForKey:kXMPPmyJID]];
    
}

// It's easy to create XML elments to send and to read received XML elements.
// You have the entire NSXMLElement and NSXMLNode API's.
//
// In addition to this, the NSXMLElement+XMPP category provides some very handy methods for working with XMPP.
//
// On the iPhone, Apple chose not to include the full NSXML suite.
// No problem - we use the KissXML library as a drop in replacement.
//
// For more information on working with XML elements, see the Wiki article:
// https://github.com/robbiehanson/XMPPFramework/wiki/WorkingWithElements

- (void)goOnline
{
    XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    
      [[self xmppStream] sendElement:presence];
    [ self getListOfGroups];

}

- (void)goOffline
{
    XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
    [[self xmppStream] sendElement:presence];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connect/disconnect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)connect
{
    if (![xmppStream isDisconnected]) {
        return YES;
    }
    
    NSString *myJID = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyJID];
    NSString *myPassword = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyPassword];
    
    //
    // If you don't want to use the Settings view to set the JID,
    // uncomment the section below to hard code a JID and password.
    //
    // myJID = @"user@gmail.com/xmppframework";
    // myPassword = @"";
    
    if (myJID == nil || myPassword == nil) {
        return NO;
    }
    
    [xmppStream setMyJID:[XMPPJID jidWithString:myJID]];
    _password = myPassword;
    
    NSError *error = nil;
    if (![xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting"
                                                            message:@"See console for error details."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil];
        [alertView show];
        
        DDLogError(@"Error connecting: %@", error);
        
        return NO;
    }
    return YES;
}

- (void)disconnect
{
    [self goOffline];
    [xmppStream disconnect];
    [self teardownStream];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    NSString *expectedCertName = [xmppStream.myJID domain];
    if (expectedCertName)
    {
        [settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
    }
    
    if (customCertEvaluation)
    {
        [settings setObject:@(YES) forKey:GCDAsyncSocketManuallyEvaluateTrust];
    }
}

/**
 * Allows a delegate to hook into the TLS handshake and manually validate the peer it's connecting to.
 *
 * This is only called if the stream is secured with settings that include:
 * - GCDAsyncSocketManuallyEvaluateTrust == YES
 * That is, if a delegate implements xmppStream:willSecureWithSettings:, and plugs in that key/value pair.
 *
 * Thus this delegate method is forwarding the TLS evaluation callback from the underlying GCDAsyncSocket.
 *
 * Typically the delegate will use SecTrustEvaluate (and related functions) to properly validate the peer.
 *
 * Note from Apple's documentation:
 *   Because [SecTrustEvaluate] might look on the network for certificates in the certificate chain,
 *   [it] might block while attempting network access. You should never call it from your main thread;
 *   call it only from within a function running on a dispatch queue or on a separate thread.
 *
 * This is why this method uses a completionHandler block rather than a normal return value.
 * The idea is that you should be performing SecTrustEvaluate on a background thread.
 * The completionHandler block is thread-safe, and may be invoked from a background queue/thread.
 * It is safe to invoke the completionHandler block even if the socket has been closed.
 *
 * Keep in mind that you can do all kinds of cool stuff here.
 * For example:
 *
 * If your development server is using a self-signed certificate,
 * then you could embed info about the self-signed cert within your app, and use this callback to ensure that
 * you're actually connecting to the expected dev server.
 *
 * Also, you could present certificates that don't pass SecTrustEvaluate to the client.
 * That is, if SecTrustEvaluate comes back with problems, you could invoke the completionHandler with NO,
 * and then ask the client if the cert can be trusted. This is similar to how most browsers act.
 *
 * Generally, only one delegate should implement this method.
 * However, if multiple delegates implement this method, then the first to invoke the completionHandler "wins".
 * And subsequent invocations of the completionHandler are ignored.
 **/
- (void)xmppStream:(XMPPStream *)sender didReceiveTrust:(SecTrustRef)trust
 completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    // The delegate method should likely have code similar to this,
    // but will presumably perform some extra security code stuff.
    // For example, allowing a specific self-signed certificate that is known to the app.
    
    dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(bgQueue, ^{
        
        SecTrustResultType result = kSecTrustResultDeny;
        OSStatus status = SecTrustEvaluate(trust, &result);
        
        if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
            completionHandler(YES);
        }
        else {
            completionHandler(NO);
        }
    });
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    isXmppConnected = YES;
    
    NSError *error=nil;
    
    if (![xmppStream authenticateWithPassword:_password error:&error])
    {
        
        DDLogError(@"Error authenticating: %@", error);
    }
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    [self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    if([xmppStream registerWithPassword:_password error:nil])
    {
        // register
        
    }
    else
    {
        // error
    }
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    
    NSDictionary *results =[[NSDictionary alloc]init];
    NSString *str;
    NSError *error;
    results = [XMLReader dictionaryForXMLString:[iq XMLString] error:&error];
    str = [[iq elementForName:@"query"]xmlns];
    
    if ([str isEqualToString:kQXMLNSRoaster])
    {
       
        FriendArray = [[results[@"iq"]valueForKey:@"query"]valueForKey:@"item"];
        [self recievedFriendsList:FriendArray];
        
    }
    
    else if ([str isEqualToString:kQXMLNSDiscoItems])
    {
        
        groupsArray = [[results[@"iq"]valueForKey:@"query"]valueForKey:@"item"];
        [self receivedArrayOgGroups:groupsArray];
    
    }
    
    return YES;
}
- (void) getListOfGroups
{
    XMPPJID *servrJID = [XMPPJID jidWithString:@"hippagroup.canopus-pc"];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:servrJID];
    [iq addAttributeWithName:@"from" stringValue:[xmppStream myJID].full];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
    [query addAttributeWithName:@"xmlns" stringValue:@"http://jabber.org/protocol/disco#items"];
    [iq addChild:query];
    [[self xmppStream] sendElement:iq];
    
}
- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    DDLogVerbose(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [presence fromStr]);
    NSString *presenceType = [presence type];
    
    NSLog(@"%@",presenceType);
    
    if ([presenceType isEqualToString:@"subscribe"])
    {
        [xmppRoster acceptPresenceSubscriptionRequestFrom:presence.from andAddToRoster:YES];
    }
    
        if  ([presenceType isEqualToString:@"available"]) {
            [xmppRoster acceptPresenceSubscriptionRequestFrom:[presence from] andAddToRoster:YES];
        }
        NSString *currentPresenceType = [presence type]; // online/offline
        NSString *myUsername = [[sender myJID] user];
        NSString *presenceFromUser = [[presence from] user];
    
        if (![presenceFromUser isEqualToString:myUsername]) {
    
            if ([currentPresenceType isEqualToString:@"available"]) {
        
    
    
            } else if ([currentPresenceType isEqualToString:@"unavailable"]) {
    
    
    
            }
    
        }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    if (!isXmppConnected)
    {
        DDLogError(@"Unable to connect to server. Check xmppStream.hostName");
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRosterDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppRoster:(XMPPRoster *)sender didReceiveBuddyRequest:(XMPPPresence *)presence
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    XMPPUserCoreDataStorageObject *user = [xmppRosterStorage userForJID:[presence from]
                                                             xmppStream:xmppStream
                                                   managedObjectContext:[self managedObjectContext_roster]];
    [xmppRoster acceptPresenceSubscriptionRequestFrom:user.jid andAddToRoster:YES];
    NSString *displayName = [user displayName];
    NSString *jidStrBare = [presence fromStr];
    NSString *body = nil;
    
    if (![displayName isEqualToString:jidStrBare])
    {
        body = [NSString stringWithFormat:@"Buddy request from %@ <%@>", displayName, jidStrBare];
    }
    else
    {
        body = [NSString stringWithFormat:@"Buddy request from %@", displayName];
    }
    
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:displayName
                                                            message:body
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
    else
    {
        // We are not active, so use a local notification instead
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.alertAction = @"Not implemented";
        localNotification.alertBody = body;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    }
    
}
- (void)xmppStream:(XMPPStream *)sender didReceiveCustomElement:(NSXMLElement *)element

{
    
    
    
}

- (void)xmppStreamDidRegister:(XMPPStream *)sender{
    
    if (![xmppStream authenticateWithPassword:_password error:nil])
    {
        
    }
}

#pragma mark - Registration

-(void)registration:(NSString*)username password:(NSString*)password;
{
    
    _username=username;
    _password=password;
    
    
    NSError *error = nil;
    
    [xmppStream setMyJID:[XMPPJID jidWithString:[_username stringByAppendingString:Userpostfix] resource:@"BarApp"]];
    [xmppStream setHostName:HostName];
    
    error = nil;
    
    if (![xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error])
    {
        
    }
    [xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement
                                                        *)error
{
    NSLog(@"Sorry the registration is failed");
    
}
#pragma mark - Login

-(void)login:(NSString*)username password:(NSString*)password;
{
    
    _username=username;
    _password=password;
    [[NSUserDefaults standardUserDefaults]setValue:_username forKey:@"myjid"];
    [self setupStream];
    [self connect];
}

#pragma mark - xmppvCardAvatarModule


- (void)xmppvCardAvatarModule:(XMPPvCardAvatarModule *)vCardTempModule
              didReceivePhoto:(UIImage *)photo
                       forJID:(XMPPJID *)jid
{
    
    
}
#pragma mark - Shared Delegate

-(void)receivedArrayOgGroups :(NSMutableArray *)groups
{
    
    
    
}
-(void)recievedFriendsList : (NSMutableArray *)friends
{
    
}

#pragma mark - SentMessage

-(void)sendMessage:(NSString *)messageString to:(NSString *)name
{
    NSData *data = [messageString dataUsingEncoding:NSNonLossyASCIIStringEncoding];
    NSString *goodValue = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:goodValue];
    NSString *messageId=[[[DSXMPP_AIO shareInstance] xmppStream] generateUUID];
    NSDate *date = [NSDate date];  //  gets current date
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* todayDate = [formatter stringFromDate:date];
    
    NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
    [message addAttributeWithName:@"to" stringValue:[name stringByAppendingString:Userpostfix]];
    [message addAttributeWithName:@"id" stringValue:messageId];
    [message addAttributeWithName:@"type" stringValue:@"chat"];
    [message addAttributeWithName:@"date" stringValue:todayDate];
    [message addAttributeWithName:@"messageType" stringValue:@"TextMessage"];
    [message addAttributeWithName:@"from" stringValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"Kxmppmyjid"]];
    [message addChild:body];
    
    [[self xmppStream] sendElement:message];
    
}
#pragma mark - ReceiveMessage


- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    if ([message isChatMessageWithBody])
    {
        NSError *parseError = nil;
        NSDictionary *xmlDictionary = [XMLReader dictionaryForXMLString:[message XMLString] error:&parseError];
        NSLog(@"%@",[xmlDictionary[@"message"] allKeys]);
        NSDictionary *MessageDict=[xmlDictionary valueForKey:@"message"];
        if ([MessageDict[@"date"] isEqualToString:@""]) {
            NSDate *date = [NSDate date];  //  gets current date
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSString* todayDate = [formatter stringFromDate:date];
            [MessageDict setValue:todayDate forKey:@"date"];
            
        }
        
        [_messageDelegate newMessageReceived:MessageDict];
        
        
        }
    if([message hasReceiptRequest])
    {
        if(xmppMessageDelieveryReciept.autoSendMessageDeliveryReceipts)
        {
            XMPPMessage *generatedReceiptResponse = [message generateReceiptResponse];
            [sender sendElement:generatedReceiptResponse];
        }
    }

    
}
#pragma mark - XMPPIncomingFileTransferDelegate Methods

- (void)xmppIncomingFileTransfer:(XMPPIncomingFileTransfer *)sender
                didFailWithError:(NSError *)error
{
    DDLogVerbose(@"%@: Incoming file transfer failed with error: %@", THIS_FILE, error);
}

- (void)xmppIncomingFileTransfer:(XMPPIncomingFileTransfer *)sender
               didReceiveSIOffer:(XMPPIQ *)offer
{
    DDLogVerbose(@"%@: Incoming file transfer did receive SI offer. Accepting...", THIS_FILE);
    [sender acceptSIOffer:offer];
}

- (void)xmppIncomingFileTransfer:(XMPPIncomingFileTransfer *)sender
              didSucceedWithData:(NSData *)data
                           named:(NSString *)name
{
    DDLogVerbose(@"%@: Incoming file transfer did succeed.", THIS_FILE);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask,
                                                         YES);
    NSString *fullPath = [[paths lastObject] stringByAppendingPathComponent:name];
    [data writeToFile:fullPath options:0 error:nil];
    
    DDLogVerbose(@"%@: Data was written to the path: %@", THIS_FILE, fullPath);
}

#pragma mark - XMPPOutgoingFileTransferDelegate Methods

- (void)xmppOutgoingFileTransfer:(XMPPOutgoingFileTransfer *)sender
                didFailWithError:(NSError *)error
{
    DDLogInfo(@"Outgoing file transfer failed with error: %@", error);
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:@"There was an error sending your file. See the logs."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)xmppOutgoingFileTransferDidSucceed:(XMPPOutgoingFileTransfer *)sender
{
    DDLogVerbose(@"File transfer successful.");
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success!"
                                                    message:@"Your file was sent successfully."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}


/**
 * Not really sure why you would want this information, but hey, when I get
 * information, I'm happy to share.
 */
- (void)xmppOutgoingFileTransferIBBClosed:(XMPPOutgoingFileTransfer *)sender
{
    
    
    
    
}
@end
