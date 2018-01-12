//
//  TGWebViewController.m
//  Telegraph
//
//  Created by brent on 2017/12/5.
//
#import "define.h"
#import "ASCache.h"
#import "TGWebViewController.h"
#import "TGApplication.h"
#import "TGFont.h"

@interface TGWebViewController ()

@end

@implementation TGWebViewController{
    UIBarButtonItem *_backItem;
    UIBarButtonItem *_closeItem;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
        //        self.navigationController.navigationBarHidden = NO;
    }
    return self;
}

-(void) back{
    if(self.webView.canGoBack){
        [self.webView goBack];
    }
    //[self.navigationController popViewControllerAnimated:YES];
}

-(void) closeNative{
    
    if(self.webView.canGoForward){
        [self.webView goForward];
    }
    //[self.navigationController popViewControllerAnimated:YES];
}

-(void)setBarButtonStatus{
    if (_webView.canGoBack) {
        [self backItem].enabled=YES;
    }else{
        [self backItem].enabled = NO;
    }
    if(_webView.canGoForward){
        [self closeItem].enabled = YES;
    }else{
        [self closeItem].enabled = NO;
    }
}

- (UIBarButtonItem *)backItem
{
    if (!_backItem) {
        
        _backItem= [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Back") style:UIBarButtonItemStylePlain target:self action:@selector(back)];
        
        /*_backItem = [[UIBarButtonItem alloc] init];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0,0,44,44);
        //        btn.imageEdgeInsets = UIEdgeInsetsMake(0,0,0,0);
        //        btn.titleEdgeInsets = UIEdgeInsetsMake(0,0,0,0);
        //这是一张“<”的图片，可以让美工给切一张
        /*UIImage *image = [UIImage imageNamed:@"nav_back"];
        [btn setImage:image forState:UIControlStateNormal];
        [btn setImage:image forState:UIControlStateHighlighted];
        [btn setTitle:@"返回" forState:UIControlStateNormal];
        [btn setTitle:@"返回" forState:UIControlStateHighlighted];
        [btn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:15]];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        _backItem.customView = btn;*/
    }
    return _backItem;
}

- (UIBarButtonItem *)closeItem
{
    if (!_closeItem) {
        _closeItem= [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Forward") style:UIBarButtonItemStylePlain target:self action:@selector(closeNative)];
        /*_closeItem = [[UIBarButtonItem alloc] init];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0,0,44,44);
        [btn setTitle:@"关闭" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(closeNative) forControlEvents:UIControlEventTouchUpInside];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:15]];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _closeItem.customView = btn;*/
    }
    return _closeItem;
}

- (void)loadView
{
    [super loadView];
    
    //[self updateBarButtonItemsAnimated:false];
    
    [self setTitleText:TGLocalized(@"DiscoverList.Title")];
//    [self setLeftBarButtonItem:self.backItem];
//    _titleContainer = [[TGDialogListTitleContainer alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 2.0f, 2.0f)];
//    [self setTitleView:_titleContainer];
//    
//    UILabel *_titleLabel = [[UILabel alloc] init];
//    _titleLabel.backgroundColor = [UIColor clearColor];
//    _titleLabel.textColor = [UIColor blackColor];
//    _titleLabel.font = TGBoldSystemFontOfSize(17.0f);
//    _titleLabel.text = @"发现";
//    [_titleLabel sizeToFit];
//    [_titleContainer addSubview:_titleLabel];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = TGLocalized(@"DiscoverList.Title");
    self.view.backgroundColor = [UIColor redColor];
    self.navigationItem.leftBarButtonItem = self.backItem;
    
    NSString *urlString = [[ASCache shared] getByIdentifier:kDiscoverURLCacheIdentifier];
    if(!urlString){
        urlString=@"https://www.biyong.io/client/";
    }
    _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - 44)];
    [self.view addSubview:_webView];
    NSURL *url = [NSURL URLWithString:urlString];
    [_webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60]];
    _webView.delegate = self;
    _webView.scalesPageToFit = YES;
    
    [self setLeftBarButtonItem:[self backItem] animated:true];
    [self setRightBarButtonItem:[self closeItem] animated:true];
    [self setBarButtonStatus];
    // Do any additional setup after loading the view from its nib.
}

-(void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

-(void) viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    
    NSString *requestString = [[request URL] absoluteString];
    
    if ([requestString hasPrefix:@"https://0.plus"])
    {
        NSArray *urlCom = [[NSArray alloc]initWithArray:[requestString pathComponents]];
        
        requestString=[[NSString alloc]initWithFormat:@"https://0.plus/%@",[urlCom lastObject]];
        
        NSURL *url = [NSURL URLWithString:requestString];
        [(TGApplication *)[UIApplication sharedApplication] openURL:url];
        
        return NO;
    }
    
    return YES;
}

-(void) webViewDidStartLoad:(UIWebView *)webView{
    //显示网络请求加载
    [UIApplication sharedApplication].networkActivityIndicatorVisible = true;
}

-(void) webViewDidFinishLoad:(UIWebView *)webView{
//    if(self.title.length <= 0){
//        NSString *title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
//        self.title = title;
//    }
    
    //显示网络请求加载
    [UIApplication sharedApplication].networkActivityIndicatorVisible = false;
    
    [self setBarButtonStatus];
}

-(void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
   
    //[UIApplication sharedApplication].networkActivityIndicatorVisible = false;
    [self setBarButtonStatus];
    /*NSLog(@"error %@",error);
    if(webView.canGoBack){
        self.navigationItem.leftBarButtonItems = @[self.backItem, self.closeItem];
    }
    else{
        self.navigationItem.leftBarButtonItem = self.backItem;
    }*/
}

@end
