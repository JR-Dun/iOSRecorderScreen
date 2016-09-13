//
//  JRVideoWriter.m
//  JRVideDemo
//
//  Created by BoBo on 16/3/26.
//  Copyright © 2016. All rights reserved.
//

#import "JRVideoWriter.h"

@interface JRVideoWriter() <JRAudioBufferDelegate>
{
    CFAbsoluteTime       _timeOfFirstFrame;
    dispatch_queue_t     _queue;
    UIImage             *_viewImage;            //采集图片
    UIImage             *_firstFrameImage;      //第一帧的图片
    int                  _timeLength;           //视频时长
    CMTime               _currentAudioTime;
}

@property (readwrite, nonatomic)    CGSize           size;
@property (readwrite, nonatomic)    int              framesPerSecond;
@property (readwrite, nonatomic)    NSString        *filePath;
@property (strong, nonatomic)       UIView          *sourceView;

@property (strong, nonatomic) NSMutableArray                        *frameBuffer;
@property (strong, nonatomic) AVAssetWriter                         *writer;
@property (strong, nonatomic) AVAssetWriterInput                    *input;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor  *adapter;
@property (strong, nonatomic) AVAssetWriterInput                    *audioInput;

@end

@implementation JRVideoWriter


- (id)initWithFilePath:(NSString *)filePath andSourceView:(UIView *)view andStartTime:(CFAbsoluteTime)startTime
{
    self = [super init];
    if(self)
    {
        self.size               = CGSizeMake(512, 384);     //视频尺寸
        self.framesPerSecond    = 1;                       //每秒帧数
        self.frameBuffer        = [[NSMutableArray alloc] init];
        self.sourceView         = view;
        _timeOfFirstFrame       = startTime;
        
        _queue      = dispatch_queue_create([@"qfd.screen.recorder.queue" cStringUsingEncoding:NSUTF8StringEncoding], 0);
        
        self.filePath = filePath;
        NSLog(@"初始化Writer（%ld） PATH:%@",(long)self.writer.status,self.filePath);
    }
    
    return self;
}

- (id)initWithFilePath:(NSString *)filePath andSourceView:(UIView *)view andStartTime:(CFAbsoluteTime)startTime andFirstFrameImageBlock:(JRFirstFrameBlock)imageBlock
{
    self = [self initWithFilePath:filePath andSourceView:view andStartTime:startTime];
    if(self)
    {
        self.firstFrameImageBlock = imageBlock;
    }
    
    return self;
}

- (void)startWriterProgress:(JRProgressBlock)progress complete:(JRCompleteBlock)completeBlock
{
    self.progressBlock = progress;
    self.completeBlock = completeBlock;
    
    self.status = kJRVideoStart;
    [self writeVideoWithCatchFrames];
    
    [JRAudioBuffer shareAudioBuffer].delegate = self;
}

#pragma mark initWriter
- (AVAssetWriter *)writer
{
    if(_writer)
        return _writer;
    
    NSError *error = nil;
    
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:self.filePath])
    {
        [fileManager removeItemAtPath:self.filePath error:nil];
    }
    
    _writer = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:self.filePath] fileType:AVFileTypeMPEG4 error:&error];
    NSAssert(error == nil, error.debugDescription);
    
    [self setVideo];
    
#if TARGET_IPHONE_SIMULATOR
    //模拟器不支持录制音频
#elif TARGET_OS_IPHONE
    //真机要录制音频
    [self setAudio];
#endif
    
    self.status = kJRVideoInit;
    
    if(_writer.status!=AVAssetWriterStatusWriting)
    {
        if([_writer startWriting])
        {
            [_writer startSessionAtSourceTime:kCMTimeZero];
        }
    }
    
    return _writer;
}

- (AVAssetWriterInput *)input
{
    if(_input)
        return _input;
    
    
    NSDictionary *settings = @{
                               AVVideoCodecKey: AVVideoCodecH264,
                               AVVideoWidthKey: @(self.size.width),
                               AVVideoHeightKey: @(self.size.height)
                               };
    
    _input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    
    NSDictionary *attributes = @{
                                 (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
                                 (NSString *)kCVPixelBufferWidthKey: @(self.size.width),
                                 (NSString *)kCVPixelBufferHeightKey: @(self.size.height)
                                 };
    self.adapter = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_input sourcePixelBufferAttributes:attributes];
    
    _input.expectsMediaDataInRealTime = YES;
    
    return _input;
}

- (AVAssetWriterInput *)audioInput
{
    if(_audioInput)
        return _audioInput;
    
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    NSDictionary *audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                   [NSNumber numberWithInt:64000], AVEncoderBitRateKey,
                                   [NSNumber numberWithFloat: 44100.0], AVSampleRateKey,
                                   [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
                                   [NSData dataWithBytes:&acl length:sizeof(acl)], AVChannelLayoutKey,nil ];
    _audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    _audioInput.expectsMediaDataInRealTime = YES;
    
    return _audioInput;
}

#pragma mark initVideo
- (void)setVideo
{
    if([self.writer canAddInput:self.input])
    {
        [self.writer addInput:self.input];
    }
}

#pragma mark initAudio
- (void)setAudio
{
    if ([self.writer canAddInput:self.audioInput]) {
        [self.writer addInput:self.audioInput];
    }
}


#pragma mark 视频帧
- (void)writeVideoWithCatchFrames
{
    while (self.writer.status == AVAssetWriterStatusWriting) {
        break;
    };
    
    int __block frame = 0;
    
    __weak typeof(self) weakSelf = self;
    
    [self.input requestMediaDataWhenReadyOnQueue:_queue usingBlock:^{
        CVPixelBufferRef buffer = NULL;
        while ([weakSelf.input isReadyForMoreMediaData]) {
            if(weakSelf.status==kJRVideoFinish && [weakSelf.frameBuffer count] == 0)
            {
                printf("视频保存完毕\n");
                if (buffer)
                {
                    CFRelease(buffer);
                    buffer = NULL;
                }
                
                //录制完成
                [weakSelf.input markAsFinished];
                [weakSelf.writer finishWritingWithCompletionHandler:^{
                    weakSelf.writer = nil;
                    if(weakSelf.completeBlock)
                    {
                        weakSelf.completeBlock(weakSelf.filePath);
                    }
                }];
                
                break;
            }
            
            if([weakSelf.frameBuffer count] == 0)
            {
                //截图
                if(!_viewImage)
                {
                    printf("截图[%d]..\n", frame);
                    _viewImage = [weakSelf imageFromView:weakSelf.sourceView];
                }
                
                //图片转换成视频帧buffer
                [weakSelf writeFrameWithImage:[_viewImage copy]];
                _viewImage = nil;
            }
            else
            {
                //图片处理成视频帧
                if (buffer == NULL)
                {
                    buffer = [weakSelf pixelBufferForImage:[weakSelf.frameBuffer objectAtIndex:0]];
                }
                
                if (buffer)
                {
                    CFAbsoluteTime interval = (CFAbsoluteTimeGetCurrent() - _timeOfFirstFrame) * 30;
                    CMTime currentSampleTime = CMTimeMake((int)interval, 30);//_currentAudioTime
                    if(_currentAudioTime.value)
                    {
                        currentSampleTime = _currentAudioTime;
                    }
                    _timeLength = (int)interval / 30;
                    
                    if(![weakSelf.adapter appendPixelBuffer:buffer withPresentationTime:currentSampleTime])
                        printf("插入视频帧失败 TimeLength:%d\n",_timeLength);
                    else
                    {
                        printf("视频帧[%d] TimeLength:%d\n", frame,_timeLength);
                        ++frame;
                    }
                    
                    if(weakSelf.progressBlock)
                    {
                        weakSelf.progressBlock(frame);
                    }
                    
                    [weakSelf.frameBuffer removeObjectAtIndex:0];
                    
                    CFRelease(buffer);
                    buffer = NULL;
                    
                    [NSThread sleepForTimeInterval:60/(weakSelf.framesPerSecond*60)];
                }
            }
        }
    }];
}

- (UIImage *)imageFromView:(UIView *)view
{
    UIGraphicsBeginImageContext(view.frame.size);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
    UIImage *rasterizedView = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return rasterizedView;
}

- (UIImage *)imageCompressForSize:(UIImage *)sourceImage targetSize:(CGSize)size
{
    int h = sourceImage.size.height;
    int w = sourceImage.size.width;
    
    if(h <= size.height && w <= size.width) {
        return sourceImage;
    } else {
        float destWith = 0.0f;
        float destHeight = 0.0f;
        
        float suoFang = (float)w/h;
        float suo = (float)h/w;
        if (w>h) {
            destWith = (float)size.width;
            destHeight = size.width * suo;
        }else {
            destHeight = (float)size.height;
            destWith = size.height * suoFang;
        }
        
        CGSize itemSize = CGSizeMake(destWith, destHeight);
        UIGraphicsBeginImageContext(itemSize);
        CGRect imageRect = CGRectMake(0, 0, destWith, destHeight);
        [sourceImage drawInRect:imageRect];
        UIImage *newImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return newImg;
    }
}

- (void)writeFrameWithImage:(UIImage *)image
{
    if(!image) return;
    
    image = [self imageCompressForSize:image targetSize:self.size];
    if(!_firstFrameImage)
    {
        _firstFrameImage = [image copy];
        if(_firstFrameImageBlock)
        {
            self.firstFrameImageBlock([_firstFrameImage copy]);
        }
    }
    [self.frameBuffer addObject:image];
}

// image 转 CVPixelBufferRef
- (CVPixelBufferRef)pixelBufferForImage:(UIImage *)image
{
    
    CGImageRef cgImage = image.CGImage;
    
    NSDictionary *options = @{
                              (NSString *)kCVPixelBufferCGImageCompatibilityKey: @(YES),
                              (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES)
                              };
    
    //return [self pixelBufferFasterForImage:cgImage andOption:options];
    
    CVPixelBufferRef buffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, self.size.width, self.size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &buffer);
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    void *data                  = CVPixelBufferGetBaseAddress(buffer);
    CGColorSpaceRef colorSpace  = CGColorSpaceCreateDeviceRGB();
    CGContextRef context        = CGBitmapContextCreate(data, self.size.width, self.size.height, 8, 4*self.size.width, colorSpace, (kCGBitmapAlphaInfoMask & kCGImageAlphaNoneSkipFirst));
    
    if (context == NULL)
    {
        free (data);
        fprintf (stderr, "Context not created!");
    }
    
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)), cgImage);
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    return buffer;
}


#pragma mark ..
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer andNowTime:(CMTime)time
{
    _currentAudioTime = time;
    if (self.writer.status == AVAssetWriterStatusWriting) {
        if (self.audioInput.readyForMoreMediaData) {
            if ([self.audioInput appendSampleBuffer:sampleBuffer])
            {
                //NSLog(@"音频流 TimeLength:%d",_timeLength);
            }
            else
            {
                NSLog(@"写入音频错误：错误信息：%@", [self.writer error]);
            }
        }
    }
}

@end
