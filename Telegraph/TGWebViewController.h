//
//  TGWebViewController.h
//  Telegraph
//
//  Created by brent on 2017/12/5.
//

#import <UIKit/UIKit.h>
#import "TGViewController.h"
#import "TGDialogListTitleContainer.h"

@interface TGWebViewController : TGViewController<UIWebViewDelegate>

@property(nonatomic,retain)UIWebView *webView;

@property (nonatomic, strong) TGDialogListTitleContainer *titleContainer;

@end
