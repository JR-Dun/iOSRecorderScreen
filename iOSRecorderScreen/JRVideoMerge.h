//
//  JRVideoMerge.h
//  JRVideDemo
//
//  Created by BoBo on 16/3/27.
//  Copyright © 2016. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JRVideoWriter.h"

@interface JRVideoMerge : NSObject

typedef void(^CompleteBlock)(NSString *fileOuputURL,UIImage *firstFrameImage,int length);

@property (strong, nonatomic) CompleteBlock  completeBlock;
@property (strong, nonatomic) UIView        *sourceView;
@property (retain, nonatomic) NSString      *identifier;
@property (retain, nonatomic) NSString      *name;

+ (instancetype)shareVideoMerge;

- (void)confPara:(NSString *)identifier andName:(NSString *)name;

- (void)startWithSourceView:(UIView *)view complete:(CompleteBlock)block;

- (void)stop;

- (NSString *)getFileName;
- (NSString *)fileOutputWithStatus:(BOOL)isComplete;
- (NSString *)folderPath;
- (NSString *)documentPath;


- (void)mergeVideoFile;
@end
