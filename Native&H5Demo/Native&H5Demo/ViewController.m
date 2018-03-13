//
//  ViewController.m
//  Native&H5Demo
//
//  Created by YaoJiaQi on 2018/2/12.
//  Copyright © 2018年 YaoJiaQi. All rights reserved.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import "MyCustomURLProtocol.h"

#define KScreenWidth [UIScreen mainScreen].bounds.size.width
#define KScreenHeight [UIScreen mainScreen].bounds.size.height

@interface ViewController ()<WKNavigationDelegate, WKUIDelegate,WKScriptMessageHandler,UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic,weak) CALayer *progressLayer;
@property (nonatomic,strong) WKWebView *webview;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupWebview];
    [self setupProgress];
}
- (void)setupWebview{
    //注册
    [NSURLProtocol registerClass:[MyCustomURLProtocol class]];
    //实现拦截功能
    Class cls = NSClassFromString(@"WKBrowsingContextController");
    SEL sel = NSSelectorFromString(@"registerSchemeForCustomProtocol:");
    if ([(id)cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [(id)cls performSelector:sel withObject:@"myapp"];
#pragma clang diagnostic pop
    }
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.selectionGranularity = WKSelectionGranularityDynamic;
    config.allowsInlineMediaPlayback = YES;
    WKPreferences *preferences = [WKPreferences new];
    preferences.javaScriptCanOpenWindowsAutomatically = YES;
    config.preferences = preferences;

    WKUserContentController *user = [[WKUserContentController alloc]init];
    [user addScriptMessageHandler:self name:@"takePicturesByNative"];
    config.userContentController =user;
    
    WKWebView *webview = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, KScreenWidth, KScreenHeight - 64) configuration:config];
    [self.view addSubview:webview];
    
//    /* 加载服务器url的方法*/
//    NSString *url = @"https://www.baidu.com";
//    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
//    [webview loadRequest:request];
    /* 加载本地html文件的方法 */
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"];
    NSString *htmlString = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    [webview loadHTMLString:htmlString baseURL:nil];
    
    webview.navigationDelegate = self;
    webview.UIDelegate = self;
    [webview addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [webview addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
    
    self.webview = webview;
}

-(void)setupProgress{
    UIView *progress = [[UIView alloc]init];
    progress.frame = CGRectMake(0, 0, KScreenWidth, 3);
    progress.backgroundColor = [UIColor  clearColor];
    [self.view addSubview:progress];
    
    CALayer *layer = [CALayer layer];
    layer.frame = CGRectMake(0, 0, 0, 3);
    layer.backgroundColor = [UIColor greenColor].CGColor;
    [progress.layer addSublayer:layer];
    self.progressLayer = layer;
}
#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message{
    if ([message.name isEqualToString:@"takePicturesByNative"]) {
        [self takePicturesByNative];
    }
}

#pragma mark - WKUIDelegate
/* 在本Webview打开网址,如果返回的是原webview会崩溃 */
-(WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures{
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }])];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}
#pragma mark - KVO回馈
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.progressLayer.opacity = 1;
        if ([change[@"new"] floatValue] <[change[@"old"] floatValue]) {
            return;
        }
        self.progressLayer.frame = CGRectMake(0, 0, KScreenWidth*[change[@"new"] floatValue], 3);
        if ([change[@"new"]floatValue] == 1.0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.progressLayer.opacity = 0;
                self.progressLayer.frame = CGRectMake(0, 0, 0, 3);
            });
        }
    }else if ([keyPath isEqualToString:@"title"]){
        self.title = change[@"new"];
    }
}

- (void)takePicturesByNative{
    UIImagePickerController *vc = [[UIImagePickerController alloc] init];
    vc.delegate = self;
    vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self presentViewController:vc animated:YES completion:nil];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSTimeInterval timeInterval = [[NSDate date]timeIntervalSince1970];
    NSString *timeString = [NSString stringWithFormat:@"%.0f",timeInterval];
    
    UIImage *image = [info  objectForKey:UIImagePickerControllerOriginalImage];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",timeString]];  //保存到本地
    [UIImagePNGRepresentation(image) writeToFile:filePath atomically:YES];
    NSString *str = [NSString stringWithFormat:@"myapp://%@",filePath];
    [picker dismissViewControllerAnimated:YES completion:^{
        // oc 调用js 并且传递图片路径参数
        [self.webview evaluateJavaScript:[NSString stringWithFormat:@"getImg('%@')",str] completionHandler:^(id _Nullable data, NSError * _Nullable error) {
        }];

    }];
}

@end
