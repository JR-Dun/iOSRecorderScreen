//
//  JRAudioBuffer.h
//  JRVideDemo
//
//  Created by BoBo on 16/3/27.
//  Copyright © 2016. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol JRAudioBufferDelegate <NSObject>

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer andNowTime:(CMTime)time;

@end

@interface JRAudioBuffer : NSObject

@property (nonatomic,weak) id<JRAudioBufferDelegate> delegate;

+ (instancetype)shareAudioBuffer;

- (void)startRunning:(CFAbsoluteTime)time;

- (void)stopRunning;

@end
