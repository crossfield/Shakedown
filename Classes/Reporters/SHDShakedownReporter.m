//
//  SHDShakedownReporter.m
//  Shakedown
//
//  Created by Max Goedjen on 4/18/13.
//  Copyright (c) 2013 Max Goedjen. All rights reserved.
//

#import "SHDShakedownReporter.h"
#import "SHDAttachment.h"

@implementation SHDShakedownReporter

- (void)reportBug:(SHDBugReport *)bugReport {
    
}

- (UIViewController *)topViewController {
    UIViewController *root = [[[[UIApplication sharedApplication] windows] objectAtIndex:0] rootViewController];
    UIViewController *presented = root;
    while (presented.presentedViewController) {
        presented = presented.presentedViewController;
    }
    return presented;
}

#pragma mark - Attachments processing

- (NSArray *)attachmentsForScreenshots:(NSArray *)screenshots {
    NSMutableArray* attachments = [NSMutableArray arrayWithCapacity:screenshots.count];
    NSUInteger count = 1;
    for (UIImage *screenshot in screenshots) {
        [attachments addObject:[SHDAttachment attachmentWithName:@"screenshot" fileName:[NSString stringWithFormat:@"Screenshot_%d.png", count]
                                                        mimeType:@"image/png" data:UIImagePNGRepresentation(screenshot)]];
        count++;
    }
    
    return [NSArray arrayWithArray:attachments];
}

- (SHDAttachment *)attachmentForLog:(NSString *)log {
    if (!log.length) {
        return nil;
    }
    
    return [SHDAttachment attachmentWithName:@"log" fileName:@"Log.txt"
                                    mimeType:@"text/plain" data:[log dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSArray *)allAttachmentsForBugReport:(SHDBugReport*)bugReport {
    NSMutableArray* attachments = [NSMutableArray array];
    
    // Screenshots
    [attachments addObjectsFromArray:[self attachmentsForScreenshots:bugReport.screenshots]];
    
    // Log
    SHDAttachment* logAttachment = [self attachmentForLog:bugReport.log];
    if (logAttachment) {
        [attachments addObject:logAttachment];
    }
    
    // Other attachments
    [attachments addObjectsFromArray:bugReport.attachments];
    
    return [NSArray arrayWithArray:attachments];
}

#pragma mark - HTTP multipart encoding

- (NSData *)httpBodyDataForDictionary:(NSDictionary *)dictionary attachments:(NSArray *)attachments boundary:(NSString *)boundary {
    
    NSMutableData *body = [NSMutableData data];
    
    NSData *initialBoundary = [[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encapsulationBoundary = [[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding];
    
    for (NSString *key in dictionary) {
        id value = dictionary[key];
        if ([value isKindOfClass:[NSString class]]) {
            NSString *stringValue = (NSString *)value;
            [body appendData:(initialBoundary ? initialBoundary : encapsulationBoundary)];
            initialBoundary = nil;
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"%@", stringValue] dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            NSLog(@"SHDShakedownRepoter: cannot post type %@ (value for key %@", [value class], key);
        }
    }
    
    for (id obj in attachments) {
        if ([obj isKindOfClass:[SHDAttachment class]]) {
            SHDAttachment *attachment = (SHDAttachment *)obj;
            [body appendData:(initialBoundary ? initialBoundary : encapsulationBoundary)];
            initialBoundary = nil;
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", attachment.name, attachment.fileName] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", attachment.mimeType] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:attachment.data];
        } else {
            NSLog(@"SHDShakedownRepoter: cannot post attachment type %@", obj);
        }
    }
    
    // Final boundary
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return body;

}

@end
