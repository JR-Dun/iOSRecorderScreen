//
//  JRAudioBuffer.m
//  JRVideDemo
//
//  Created by BoBo on 16/3/27.
//  Copyright © 2016. All rights reserved.
//

#import "JRAudioBuffer.h"

@interface JRAudioBuffer() <AVCaptureAudioDataOutputSampleBufferDelegate>
{
    dispatch_queue_t        _queueAudio;
    CFAbsoluteTime          _startTime;
}

@property (strong, nonatomic) AVCaptureSession                      *captureSession;

@end


@implementation JRAudioBuffer

+ (instancetype)shareAudioBuffer
{
    static dispatch_once_t once;
    static JRAudioBuffer *audioBuffer = nil;
    dispatch_once(&once, ^{
        audioBuffer = [self new];
    });
    return audioBuffer;
}

- (void)startRunning:(CFAbsoluteTime)time
{
    _startTime = time;
    _queueAudio = dispatch_queue_create([@"qfd.screen.recorder.queueAudio" cStringUsingEncoding:NSUTF8StringEncoding], 0);
    [self.captureSession startRunning];

}

- (void)stopRunning
{
    if(_captureSession)
    {
        [self.captureSession stopRunning];
    }
}

#pragma mark AVCaptureSession
- (AVCaptureSession *)captureSession
{
    if(_captureSession)
        return _captureSession;
    
    NSError *error = nil;
    //音频
    _captureSession = [[AVCaptureSession alloc] init];
    AVCaptureDevice *audioDev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDev error:&error];
    [_captureSession addInput:audioIn];
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(0, 0)];
    [_captureSession addOutput:audioOutput];
    [audioOutput connectionWithMediaType:AVMediaTypeAudio];
    
    return _captureSession;
}

#pragma mark 音频
#pragma mark <AVCaptureAudioDataOutputSampleBufferDelegate>
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CFAbsoluteTime interval = (CFAbsoluteTimeGetCurrent() - _startTime) * 30;
    CMTime currentSampleTime = CMTimeMake((int)interval, 30);
    
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    CFRetain(sampleBuffer);
    CFRetain(formatDescription);
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_queueAudio, ^{
        
        if (!CMSampleBufferDataIsReady(sampleBuffer)) {
            NSLog(@"音频流未准备好");
            CFRelease(sampleBuffer);
            CFRelease(formatDescription);
            return;
        }
        
        CMSampleBufferRef bufferToWrite = NULL;
        bufferToWrite = [weakSelf createOffsetSampleBuffer:sampleBuffer withTimeOffset:currentSampleTime];
        if (!bufferToWrite) {
            NSLog(@"音频流 null");
        }
        
        [weakSelf writeSampleBuffer:bufferToWrite ofType:AVMediaTypeAudio andNowTime:currentSampleTime];
        CFRelease(bufferToWrite);
        CFRelease(sampleBuffer);
        CFRelease(formatDescription);
    });
}

// CMSampleBufferRef流处理
- (CMSampleBufferRef)createOffsetSampleBuffer:(CMSampleBufferRef)sampleBuffer withTimeOffset:(CMTime)timeOffset
{
    CMItemCount itemCount;
    
    OSStatus status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, NULL, &itemCount);
    if (status) {
        NSLog(@"couldn't determine the timing info count");
        return NULL;
    }
    
    CMSampleTimingInfo *timingInfo = (CMSampleTimingInfo *)malloc(sizeof(CMSampleTimingInfo) * (unsigned long)itemCount);
    if (!timingInfo) {
        NSLog(@"couldn't allocate timing info");
        return NULL;
    }
    
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, itemCount, timingInfo, &itemCount);
    if (status) {
        free(timingInfo);
        timingInfo = NULL;
        NSLog(@"failure getting sample timing info array");
        return NULL;
    }
    
    for (CMItemCount i = 0; i < itemCount; i++) {
        timingInfo[i].presentationTimeStamp = timeOffset;//CMTimeSubtract(timingInfo[i].presentationTimeStamp, timeOffset);
        timingInfo[i].decodeTimeStamp = timeOffset;//CMTimeSubtract(timingInfo[i].decodeTimeStamp, timeOffset);
    }
    
    CMSampleBufferRef outputSampleBuffer;
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, itemCount, timingInfo, &outputSampleBuffer);
    
    if (timingInfo) {
        free(timingInfo);
        timingInfo = NULL;
    }
    
    return outputSampleBuffer;
}

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType andNowTime:(CMTime)time
{
    if(_delegate && [_delegate respondsToSelector:@selector(appendSampleBuffer:andNowTime:)])
    {
        [self.delegate appendSampleBuffer:sampleBuffer andNowTime:time];
    }
}


@end
