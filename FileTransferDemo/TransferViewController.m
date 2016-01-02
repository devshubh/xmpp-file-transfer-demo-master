//
//  TransferViewController.m
//  FileTransferDemo
//
//  Created by Jonathon Staff on 11/2/14.
//  Copyright (c) 2014 nplexity. All rights reserved.
//

#import "TransferViewController.h"
#import "AppDelegate.h"
#import "DDLog.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface TransferViewController ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *img;
@property (weak, nonatomic) IBOutlet UITextField *inputRecipient;
@property (weak, nonatomic) IBOutlet UITextField *inputFilename;
@property (weak, nonatomic) IBOutlet UILabel *txtDocumentsDir;
@property (nonatomic, strong) XMPPOutgoingFileTransfer *fileTransfer;

@end

@implementation TransferViewController
- (IBAction)getImage:(id)sender {
    
    UIImagePickerController *imgPick = [UIImagePickerController new];
    imgPick.delegate = self;
    [self presentViewController:imgPick animated:YES completion:nil];
   
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _txtDocumentsDir.text = [self documentsDirectory];
}

- (AppDelegate *)appDelegate
{
  return (AppDelegate *) [[UIApplication sharedApplication] delegate];
}

- (NSString *)documentsDirectory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask,
                                                       YES);
  return [paths lastObject];
}

- (IBAction)btnTransferClicked:(id)sender
{
    
  if (!_fileTransfer) {
    _fileTransfer = [[XMPPOutgoingFileTransfer alloc]
                                               initWithDispatchQueue:dispatch_get_main_queue()];
    [_fileTransfer activate:[self appDelegate].xmppStream];
    [_fileTransfer addDelegate:self delegateQueue:dispatch_get_main_queue()];
  }

  NSString *recipient = _inputRecipient.text;
  NSString *filename = _inputFilename.text;

  // do error checking fun stuff...

  NSString *fullPath = [[self documentsDirectory] stringByAppendingPathComponent:filename];
  NSData *data = [NSData dataWithContentsOfFile:fullPath];

  NSError *err;
  if (![_fileTransfer sendData:data
                         named:filename
                   toRecipient:[XMPPJID jidWithString:recipient]
                   description:@"Baal's Soulstone, obviously."
                         error:&err]) {
    DDLogInfo(@"You messed something up: %@", err);
  }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo NS_DEPRECATED_IOS(2_0, 3_0)
{
    _img.image = image;
    NSData *pngData = UIImagePNGRepresentation(image);
    NSString *stringToWrite = @"Hello Sir.......";

         NSString *filePath = [[self documentsDirectory] stringByAppendingPathComponent:@"text.txt"]; //Add the file name
    [stringToWrite writeToFile:filePath atomically:YES];
    [picker dismissViewControllerAnimated:YES completion:nil];//Write the fil
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


@end
