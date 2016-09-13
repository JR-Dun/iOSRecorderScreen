//
//  JRVideoMerge.m
//  JRVideDemo
//
//  Created by BoBo on 16/3/27.
//  Copyright © 2016. All rights reserved.
//

#import "JRVideoMerge.h"

@interface JRVideoMerge() 

@property (nonatomic,strong) NSMutableArray                         *mp4Array;

@end

@implementation JRVideoMerge
{
    JRVideoWriter       *_writer1;
    JRVideoWriter       *_writer2;
    
    UIImage             *_firstFrameImage;
    
    CMTime               _lastRecorderTime;
    
    CFAbsoluteTime       _startTime;
    int                  _part;
    int                  _timeLength;
    int                  _mergeProcess;
    BOOL                 _finish;
}

+ (instancetype)shareVideoMerge
{
    static dispatch_once_t once;
    static JRVideoMerge *videoMerge = nil;
    dispatch_once(&once, ^{
        videoMerge = [self new];
    });
    return videoMerge;
}

- (void)confPara:(NSString *)identifier andName:(NSString *)name
{
    self.identifier = identifier;
    self.name = name;
}

- (void)startWithSourceView:(UIView *)view complete:(CompleteBlock)block
{
    [self addNotification];
    
    _finish = NO;
    self.sourceView = view;
    self.completeBlock = block;
    
    _startTime = CFAbsoluteTimeGetCurrent();
    //如果中途进教室重新上课，要根据视频文件重置_startTime。
    [self resetStartTime];
    _writer1 = [[JRVideoWriter alloc] initWithFilePath:[self getFileName] andSourceView:self.sourceView andStartTime:_startTime andFirstFrameImageBlock:^(UIImage *firstFrameImage) {
        _firstFrameImage = firstFrameImage;
    }];
    [[JRAudioBuffer shareAudioBuffer] startRunning:_startTime];
    [self startWriter1];
}

- (void)stop
{
    [self removeNotification];
    
    [[JRAudioBuffer shareAudioBuffer] stopRunning];
    [_writer1 setStatus:kJRVideoFinish];
    [_writer2 setStatus:kJRVideoFinish];
    
    _finish = YES;
}

- (void)startWriter1
{
    _mergeProcess++;
    __weak typeof(self) weakSelf = self;
    [_writer1 startWriterProgress:^(int frame) {
        if(frame == 5)
        {
        }
        else if(frame==10)
        {
            _writer2 = [[JRVideoWriter alloc] initWithFilePath:[weakSelf getFileName] andSourceView:weakSelf.sourceView andStartTime:_startTime];
            [weakSelf startWriter2];
            [_writer1 setStatus:kJRVideoFinish];
        }
    } complete:^(NSString *filePath) {
        _mergeProcess--;
        [weakSelf mergeVideo:filePath];
    }];
}
- (void)startWriter2
{
    _mergeProcess++;
    __weak typeof(self) weakSelf = self;
    [_writer2 startWriterProgress:^(int frame) {
        if(frame == 5)
        {
        }
        else if(frame==10)
        {
            _writer1 = [[JRVideoWriter alloc] initWithFilePath:[weakSelf getFileName] andSourceView:weakSelf.sourceView andStartTime:_startTime];
            [weakSelf startWriter1];
            [_writer2 setStatus:kJRVideoFinish];
        }
    } complete:^(NSString *filePath) {
        _mergeProcess--;
        [weakSelf mergeVideo:filePath];
    }];
}

//重置视频录制开始时间
- (void)resetStartTime
{
    NSString *path = [self fileOutputWithStatus:YES];
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:path])
    {
        AVAsset *asset = [self getAVAssetWithPath:path];
        if(asset)
        {
            if(asset.duration.value)
            {
                _lastRecorderTime = CMTimeSubtract(asset.duration,CMTimeMake(30, 30));
            }
        }
    }
}

- (NSString *)getFileName
{
    NSString *filename          = [NSString stringWithFormat:@"%@_qfd_%d.mp4", self.name,_part++];
    NSString *path              = [NSString stringWithFormat:@"%@%@", self.folderPath, filename];
    
    //文件已存在，同时视频正常 part++
    //文件存在，视频状态不正常 要删除该文件，返回当前文件路径
    //文件不存在 直接返回当前文件路径
    NSFileManager *fileManager = [NSFileManager defaultManager];
    while([fileManager fileExistsAtPath:path])
    {
        BOOL isFileOk = NO;
        AVAsset *asset = [self getAVAssetWithPath:path];
        if(asset)
        {
            if(asset.duration.value)
            {
                isFileOk = YES;
            }
        }
        
        if(isFileOk)
        {
            filename = [NSString stringWithFormat:@"%@_qfd_%d.mp4", self.name,_part++];
            path     = [NSString stringWithFormat:@"%@%@", self.folderPath, filename];
        }
        else
        {
            [fileManager removeItemAtPath:path error:nil];
            break;
        }
    }
    
    return path;
}

- (NSString *)fileOutputWithStatus:(BOOL)isComplete
{
    NSString *filename          = [NSString stringWithFormat:@"%@_qfd_%@.mp4", self.name,isComplete?@"ok":@"tmp"];
    NSString *path              = [NSString stringWithFormat:@"%@%@", self.folderPath, filename];
    
    return path;
}

- (NSString *)folderPath
{
    NSString *folder = [NSString stringWithFormat:@"/video/%@/new/",self.identifier];
    //未上传视频文件夹
    folder = [[self documentPath] stringByAppendingString:folder];
    if (![[NSFileManager defaultManager] fileExistsAtPath:folder]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    //已上传视频文件夹
    NSString *folderOld = [NSString stringWithFormat:@"/video/%@/old/",self.identifier];
    if (![[NSFileManager defaultManager] fileExistsAtPath:folderOld]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:folderOld withIntermediateDirectories:YES attributes:nil error:nil];
    }

    
    return folder;
}

- (NSString *)documentPath
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

- (void)removeFileWithPath:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:path])
    {
        [fileManager removeItemAtPath:path error:nil];
    }
}

#pragma mark 视频文件合并(遍历所有已存在的视频)
- (void)mergeVideoFile
{
    NSString *filename = @"";
    NSString *path     = @"";
    
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:[self fileOutputWithStatus:YES] error:nil];
    
    if(!_mp4Array)
        _mp4Array = [[NSMutableArray alloc] init];
    
    for(int i = 0; i<4; i++)
    {
        filename = [NSString stringWithFormat:@"%@_qfd_%d.mp4", self.name,i];
        path     = [NSString stringWithFormat:@"%@%@", self.folderPath, filename];
        
        [_mp4Array addObject:path];
    }
    
    [self mergeVideoWithDataArray:[_mp4Array mutableCopy]];
}

#pragma mark 视频片段合并
- (void)mergeVideo:(NSString *)path
{
    if(path)
    {
        if(!_mp4Array)
            _mp4Array = [[NSMutableArray alloc] init];
        
        [self.mp4Array addObject:path];
    }
    
    if(self.mp4Array.count>0)
    {
        NSString *path = [self fileOutputWithStatus:YES];
        NSFileManager *fileManager  = [NSFileManager defaultManager];
        if([fileManager fileExistsAtPath:path])
        {
            [self mergeVideoWithFirst:path andSecond:self.mp4Array[0]];
        }
        else
        {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager copyItemAtPath:self.mp4Array[0] toPath:path error:nil];
            [fileManager removeItemAtPath:self.mp4Array[0] error:nil];
            [self.mp4Array removeObjectAtIndex:0];
        }
    }
}

- (void)mergeVideoWithFirst:(NSString *)path1 andSecond:(NSString *)path2
{
    NSString *firstVideo = path1;
    NSString *secondVideo = path2;
    
    AVAsset *firstAsset = [self getAVAssetWithPath:firstVideo];
    AVAsset *secondAsset = [self getAVAssetWithPath:secondVideo];
    //
    if(!firstAsset)
    {
        [self.mp4Array removeObject:path1];
        [self removeFileWithPath:path1];
    }
    if(!secondAsset)
    {
        [self.mp4Array removeObject:path2];
        [self removeFileWithPath:path2];
    }
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    //为视频类型的的Track
    AVMutableCompositionTrack *compositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    //由于没有计算当前CMTime的起始位置，现在插入0的位置,所以合并出来的视频是后添加在前面，可以计算一下时间，插入到指定位置
    //CMTimeRangeMake 指定起去始位置
    
    CMTime firstTime = CMTimeSubtract(firstAsset.duration,CMTimeMake(30, 30));
    CMTimeRange firstTimeRange = CMTimeRangeMake(kCMTimeZero, firstTime);
    //视频片段接驳调整（偏移量）
    CMTime secondTime = CMTimeAdd(firstTime, CMTimeMake(0, 30));
    if(_lastRecorderTime.value)
    {
        CMTime offSetTime = CMTimeSubtract(firstTime, _lastRecorderTime);
        secondTime = CMTimeAdd(offSetTime, CMTimeMake(0, 30));
    }
    CMTimeRange secondTimeRange = CMTimeRangeMake(kCMTimeZero, secondAsset.duration);
    if(CMTimeCompare(secondAsset.duration, firstAsset.duration) > 0)
    {
        secondTimeRange = CMTimeRangeMake(secondTime, secondAsset.duration);
    }
    
    //视频轨道
    if([secondAsset tracksWithMediaType:AVMediaTypeVideo] && [secondAsset tracksWithMediaType:AVMediaTypeVideo].count>0)
    {
        [compositionTrack insertTimeRange:secondTimeRange ofTrack:[secondAsset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];
    }
    else
    {
        NSLog(@"secondAsset找不到视频轨道");
        [self removeFileWithPath:path2];
    }
    if([firstAsset tracksWithMediaType:AVMediaTypeVideo] && [firstAsset tracksWithMediaType:AVMediaTypeVideo].count>0)
    {
        [compositionTrack insertTimeRange:firstTimeRange ofTrack:[firstAsset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];
    }
    else
    {
        NSLog(@"firstAsset找不到视频轨道");
    }
    
    //视频总时长
    CMTime allTime = CMTimeAdd(firstTime, secondTime);
    _timeLength = (int)(allTime.value/allTime.timescale);
    
    //只合并视频，导出后声音会消失，所以需要把声音插入到混淆器中
    //添加音频,添加本地其他音乐也可以,与视频一致
#if TARGET_IPHONE_SIMULATOR
#elif TARGET_OS_IPHONE
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    if([secondAsset tracksWithMediaType:AVMediaTypeAudio] && [secondAsset tracksWithMediaType:AVMediaTypeAudio].count>0)
    {
        [audioTrack insertTimeRange:secondTimeRange ofTrack:[secondAsset tracksWithMediaType:AVMediaTypeAudio][0] atTime:kCMTimeZero error:nil];
    }
    else
    {
        NSLog(@"secondAsset找不到音轨");
        [self removeFileWithPath:path2];
    }
    
    if([firstAsset tracksWithMediaType:AVMediaTypeAudio] && [firstAsset tracksWithMediaType:AVMediaTypeAudio].count > 0)
    {
        [audioTrack insertTimeRange:firstTimeRange ofTrack:[firstAsset tracksWithMediaType:AVMediaTypeAudio][0] atTime:kCMTimeZero error:nil];
    }
    else
    {
        NSLog(@"firstAsset找不到音轨");
    }
#endif
    
    NSString *filePath = [self fileOutputWithStatus:NO];
    ////如果文件已存在 删除文件
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:filePath])
    {
        [fileManager removeItemAtPath:filePath error:nil];
    }
    AVAssetExportSession *exporterSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    exporterSession.outputFileType = AVFileTypeMPEG4;
    exporterSession.outputURL = [NSURL fileURLWithPath:filePath]; //如果文件已存在，将造成导出失败
    exporterSession.shouldOptimizeForNetworkUse = YES; //用于互联网传输
    
    NSLog(@"视频片段合并开始 \nvideo1:%@ \nvideo2:%@",path1,path2);
    __weak typeof(self) weakSelf = self;
    [exporterSession exportAsynchronouslyWithCompletionHandler:^{
        switch (exporterSession.status) {
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"视频片段合并成功\n");
                [weakSelf.mp4Array removeObject:path1];
                [weakSelf.mp4Array removeObject:path2];
                [weakSelf removeFileWithPath:path1];
                [weakSelf removeFileWithPath:path2];
                [weakSelf changeName];
                break;
            default:
                NSLog(@"视频片段合并错误\n");
                [self complete];
                break;
        }
    }];
}

- (void)mergeVideoWithDataArray:(NSArray *)array
{
    if(!_mp4Array || _mp4Array.count<=0)
        return;
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    //为视频类型的的Track
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    for(int i=0;i<array.count;i++)
    {
        NSString *path = array[i];
        
        AVAsset *asset = [self getAVAssetWithPath:path];
        if(asset)
        {
            CMTime time = asset.duration;
            CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
            _timeLength += (int)(time.value/time.timescale);
            if([asset tracksWithMediaType:AVMediaTypeVideo] && [asset tracksWithMediaType:AVMediaTypeVideo].count>0)
            {
                [videoTrack insertTimeRange:timeRange ofTrack:[asset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];
            }
            
            if([asset tracksWithMediaType:AVMediaTypeAudio] && [asset tracksWithMediaType:AVMediaTypeAudio].count > 0)
            {
                [audioTrack insertTimeRange:timeRange ofTrack:[asset tracksWithMediaType:AVMediaTypeAudio][0] atTime:kCMTimeZero error:nil];
            }
            
        }
    }
    
    NSString *filePath = [self fileOutputWithStatus:YES];
    ////如果文件已存在 删除文件
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:filePath])
    {
        [fileManager removeItemAtPath:filePath error:nil];
    }
    AVAssetExportSession *exporterSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    exporterSession.outputFileType = AVFileTypeMPEG4;
    exporterSession.outputURL = [NSURL fileURLWithPath:filePath]; //如果文件已存在，将造成导出失败
    exporterSession.shouldOptimizeForNetworkUse = YES; //用于互联网传输
    //__weak typeof(self) weakSelf = self;
    [exporterSession exportAsynchronouslyWithCompletionHandler:^{
        switch (exporterSession.status) {
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"视频片段合并成功\n");
                break;
            default:
                NSLog(@"视频片段合并错误\n");
                break;
        }
    }];
}

- (void)changeName
{
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    NSString *path = [self fileOutputWithStatus:NO];
    NSString *path2 = [self fileOutputWithStatus:YES];
    if([fileManager fileExistsAtPath:path])
    {
        if([fileManager fileExistsAtPath:path2])
        {
            [fileManager removeItemAtPath:path2 error:nil];
        }
        [fileManager copyItemAtPath:path toPath:path2 error:nil];
        [fileManager removeItemAtPath:path error:nil];
    }
    
    [self complete];
}

- (AVAsset *)getAVAssetWithPath:(NSString *)path
{
    NSDictionary *optDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    return [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:path] options:optDict];
}

- (void)complete
{
    if(_finish && _mergeProcess==0 && _completeBlock && _mp4Array.count == 0)
    {
        self.completeBlock([self fileOutputWithStatus:YES],_firstFrameImage,_timeLength);
    }
}

#pragma mark Notification
- (void)addNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil]; //监听是否触发home键挂起程序.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil]; //监听是否重新进入程序程序.
}

- (void)removeNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [[JRAudioBuffer shareAudioBuffer] stopRunning];
    [_writer1 setStatus:kJRVideoFinish];
    [_writer2 setStatus:kJRVideoFinish];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    _writer1 = [[JRVideoWriter alloc] initWithFilePath:[self getFileName] andSourceView:self.sourceView andStartTime:_startTime];
    [[JRAudioBuffer shareAudioBuffer] startRunning:_startTime];
    [self startWriter1];
}

@end
