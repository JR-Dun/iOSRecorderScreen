//
//  JRVideoWriter.h
//  JRVideDemo
//
//  Created by BoBo on 16/3/26.
//  Copyright © 2016. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JRAudioBuffer.h"

typedef NS_ENUM(NSInteger, JRVideoWriterStatus) {
    kJRVideoInit,   //初始化
    kJRVideoStart,  //录制中
    kJRVideoFinish, //录制完毕
};

@interface JRVideoWriter : NSObject

typedef void(^JRFirstFrameBlock)(UIImage *firstFrameImage);
typedef void(^JRProgressBlock)(int frame);
typedef void(^JRCompleteBlock)(NSString *filePath);

@property (strong, nonatomic) JRProgressBlock       progressBlock;
@property (strong, nonatomic) JRCompleteBlock       completeBlock;
@property (strong, nonatomic) JRFirstFrameBlock     firstFrameImageBlock;
@property (assign, nonatomic) JRVideoWriterStatus   status;


- (id)initWithFilePath:(NSString *)filePath andSourceView:(UIView *)view andStartTime:(CFAbsoluteTime)startTime;
- (id)initWithFilePath:(NSString *)filePath andSourceView:(UIView *)view andStartTime:(CFAbsoluteTime)startTime andFirstFrameImageBlock:(JRFirstFrameBlock)imageBlock;

- (void)startWriterProgress:(JRProgressBlock)progress complete:(JRCompleteBlock)completeBlock;

@end
