//
//  ViewController.m
//  iOSRecorderScreen
//
//  Created by BoBo on 16/9/13.
//  Copyright © 2016年 JR_Dun. All rights reserved.
//

#import "ViewController.h"
#import "JRVideoMerge.h"

@interface ViewController ()

@property (nonatomic,strong) UIButton *buttonStart;
@property (nonatomic,strong) UIButton *buttonStop;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self initUI];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - initUI
- (void)initUI
{
    _buttonStart = [UIButton new];
    [_buttonStart setTitle:@"开始" forState:UIControlStateNormal];
    [_buttonStart setBackgroundColor:[UIColor colorWithRed:0.0 green:0.502 blue:1.0 alpha:1.0]];
    [_buttonStart addTarget:self action:@selector(startRecorder) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_buttonStart];
    
    _buttonStop = [UIButton new];
    [_buttonStop setTitle:@"停止" forState:UIControlStateNormal];
    [_buttonStop setBackgroundColor:[UIColor colorWithRed:0.0 green:0.502 blue:1.0 alpha:1.0]];
    [_buttonStop addTarget:self action:@selector(stopRecorder) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_buttonStop];
    
    _buttonStart.translatesAutoresizingMaskIntoConstraints = NO;
    _buttonStop.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSDictionary *views = NSDictionaryOfVariableBindings(_buttonStart,_buttonStop);
    NSDictionary *metrics = @{};
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[_buttonStart(100)]" options:0 metrics:metrics views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[_buttonStop(100)]" options:0 metrics:metrics views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-100-[_buttonStart(50)]-10-[_buttonStop(50)]" options:0 metrics:metrics views:views]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_buttonStart attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_buttonStop attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
}

#pragma mark - conf para
- (void)confData
{
    [[JRVideoMerge shareVideoMerge] confPara:@"folderName" andName:@"fileName"];
}

#pragma mark - 开始录制
- (void)startRecorder
{
    [[JRVideoMerge shareVideoMerge] startWithSourceView:self.view complete:^(NSString *fileOuputURL, UIImage *firstFrameImage, int length) {
        NSLog(@"录制结束");
    }];
}

#pragma mark - 停止录制
- (void)stopRecorder
{
    [[JRVideoMerge shareVideoMerge] stop];
}

@end
