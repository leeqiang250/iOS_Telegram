#define MainScreenRect [UIScreen mainScreen].bounds
#define AlertView_W     270.0f
#define MessageMin_H    50.0f       //messagelab的最小高度
#define MessageMAX_H    160.0f      //messagelab的最大高度，当超过时，文本会以...结尾
#define LXATitle_H      20.0f
#define LXABtn_H        45.0f

#define LXADTitleFont       [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
#define LXADMessageFont     [UIFont systemFontOfSize:14 weight:UIFontWeightLight];
#define LXADBtnTitleFont    [UIFont systemFontOfSize:15];


#import "VCAlertView.h"
#import "UILabel+VCAdd.h"

@interface VCAlertView ()

@property (nonatomic,strong)UIWindow *alertWindow;
@property (nonatomic,strong)UIView *alertView;

@property (nonatomic,strong)UILabel *titleLab;
@property (nonatomic,strong)UILabel *messageLab;
@property (nonatomic,strong)UIButton *cancelBtn;
@property (nonatomic,strong)UIButton *otherBtn;
@property(nonatomic,strong) UIView * horLine;
@property(nonatomic,strong) UIView * verLine;

@end


@implementation VCAlertView

//+ (void) blackHudWithText:(NSString *)message {
//    if (![message length]) {
//        message = TGLocalized(@"transfer_abnormal_alert");
//    }
//    UIView *hudView = [[UIView alloc] init];
//    hudView.backgroundColor = [UIColor blackColor];
//    hudView.layer.cornerRadius = 5;
//    hudView.layer.masksToBounds = YES;
//    hudView.alpha = 0.0;
//
//
//    UILabel *label = [[UILabel alloc] init];
//    label.textColor = [UIColor whiteColor];
//    label.font = [UIFont systemFontOfSize:14];
//    label.font = [UIFont systemFontOfSize:13];
//    label.text = message;
//    [label sizeToFit];
//    hudView.bounds = CGRectMake(0, 0, label.bounds.size.width + 30, 46);
//    [hudView addSubview:label];
//    label.center = CGPointMake(hudView.bounds.size.width * 0.5, hudView.bounds.size.height * 0.5);
//    if (message.length == 0) {
//        return;
//    }
//    [[UIApplication sharedApplication].keyWindow addSubview:hudView];
//    [[UIApplication sharedApplication].keyWindow bringSubviewToFront:hudView];
//    hudView.center = CGPointMake([UIScreen mainScreen].bounds.size.width * 0.5, [UIScreen mainScreen].bounds.size.height * 0.5);
//    [UIView animateWithDuration:0.5 animations:^{
//        hudView.alpha = 0.9;
//    } completion:^(BOOL finished) {
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [UIView animateWithDuration:0.5 animations:^{
//                hudView.alpha = 0.0;
//            } completion:^(BOOL finished) {
//                [hudView removeFromSuperview];
//            }];
//        });
//    }];
//}


-(instancetype)initWithTitle:(NSString *)title message:(NSString *)message cancelBtnTitle:(NSString *)cancelTitle otherBtnTitle:(NSString *)otherBtnTitle clickIndexBlock:(LXAlertClickIndexBlock)block{
    
    if (!message || message.length == 0 )  message = @"";
    
    if(self=[super init]){
        self.frame=MainScreenRect;
        self.backgroundColor=[UIColor colorWithWhite:.3 alpha:.7];
        
        _alertView=[[UIView alloc] init];
        _alertView.backgroundColor=[UIColor whiteColor];
        _alertView.layer.cornerRadius=8.0;
        _alertView.layer.masksToBounds=YES;
        _alertView.userInteractionEnabled=YES;
         CGFloat titleHeight = 0;
        
        if (title) {
            _titleLab=[[UILabel alloc] initWithFrame:CGRectMake(0, 20, AlertView_W, LXATitle_H)];
            _titleLab.text=title;
            _titleLab.textAlignment=NSTextAlignmentCenter;
            _titleLab.textColor=[UIColor blackColor];
            _titleLab.font=LXADTitleFont;
            titleHeight = LXATitle_H + 20;
        }
        
        if (message.length) {
            CGFloat messageLabSpace = 25;
            _messageLab=[[UILabel alloc] init];
            _messageLab.backgroundColor=[UIColor whiteColor];
            _messageLab.text=message;
            _messageLab.textColor=[UIColor blackColor];
            _messageLab.font=LXADMessageFont;
            _messageLab.numberOfLines=0;
            _messageLab.textAlignment=NSTextAlignmentCenter;
            _messageLab.lineBreakMode=NSLineBreakByTruncatingTail;
            _messageLab.characterSpace=0.4;
            _messageLab.lineSpace=3;
            CGSize labSize = [_messageLab getLableRectWithMaxWidth:AlertView_W-messageLabSpace*2];
            CGFloat messageLabAotuH = labSize.height < MessageMin_H?MessageMin_H:labSize.height;
            CGFloat endMessageLabH = messageLabAotuH > MessageMAX_H?MessageMAX_H:messageLabAotuH;
            _messageLab.frame=CGRectMake(messageLabSpace, _titleLab.frame.size.height+_titleLab.frame.origin.y+20, AlertView_W-messageLabSpace*2, endMessageLabH);
        }
        
        
        //计算_alertView的高度
       
        _alertView.frame=CGRectMake(0, 0, AlertView_W, _messageLab.frame.size.height+titleHeight+LXABtn_H+40 );
        _alertView.center=self.center;
        [self addSubview:_alertView];
        [_alertView addSubview:_titleLab];
        [_alertView addSubview:_messageLab];
        
        if (cancelTitle) {
            
            _cancelBtn=[UIButton buttonWithType:UIButtonTypeCustom];
            [_cancelBtn setTitle:cancelTitle forState:UIControlStateNormal];
            [_cancelBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
           // [_cancelBtn setBackgroundImage:[UIImage imageWithColor:SFQLightGrayColor] forState:UIControlStateNormal];
            _cancelBtn.titleLabel.font=LXADBtnTitleFont;
            _cancelBtn.layer.cornerRadius=3;
            _cancelBtn.layer.masksToBounds=YES;
            [_cancelBtn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
            [_alertView addSubview:_cancelBtn];
        }
        
        if (otherBtnTitle) {
            _otherBtn=[UIButton buttonWithType:UIButtonTypeCustom];
            [_otherBtn setTitle:otherBtnTitle forState:UIControlStateNormal];
            [_otherBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            _otherBtn.titleLabel.font=LXADBtnTitleFont;
            _otherBtn.layer.cornerRadius=3;
            _otherBtn.layer.masksToBounds=YES;
            [_otherBtn setBackgroundColor:[UIColor whiteColor]];
            [_otherBtn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
            [_alertView addSubview:_otherBtn];
        }
        
        if (cancelTitle || otherBtnTitle) {
            _horLine = [[UIView alloc] init];
            _horLine.backgroundColor = [UIColor blackColor];
            [_alertView addSubview:_horLine];
        }
        
        if (cancelTitle && otherBtnTitle) {
            _verLine = [[UIView alloc] init];
            _verLine.backgroundColor = [UIColor blackColor];
            [_alertView addSubview:_verLine];
        }
        
        
        
        CGFloat btn_y = _alertView.frame.size.height-45;
        if (cancelTitle && !otherBtnTitle) {
            _cancelBtn.tag=0;
            _cancelBtn.frame=CGRectMake(0, btn_y, AlertView_W, LXABtn_H);
            _horLine.frame = CGRectMake(0, btn_y, AlertView_W, 0.5);
        }else if (!cancelTitle && otherBtnTitle){
            _otherBtn.tag=0;
            _otherBtn.frame=CGRectMake(0, btn_y, AlertView_W, LXABtn_H);
            _horLine.frame = CGRectMake(0, btn_y, AlertView_W, 0.5);

        }else if (cancelTitle && otherBtnTitle){
            _cancelBtn.tag=0;
            _otherBtn.tag=1;
            CGFloat btn_w =AlertView_W/2;
            _cancelBtn.frame=CGRectMake(0, btn_y, btn_w, LXABtn_H);
            _otherBtn.frame=CGRectMake(btn_w+0.5, btn_y, btn_w, LXABtn_H);
            _horLine.frame = CGRectMake(0, btn_y, AlertView_W, 0.5);
            _verLine.frame =CGRectMake(btn_w, btn_y, 0.5, LXABtn_H);
            
        }
        
        self.clickBlock=block;
        
    }
    return self;
}


-(void)btnClick:(UIButton *)btn{
    
    if (self.clickBlock) {
        self.clickBlock(btn.tag);
    }
    
    if (!_dontDissmiss) {
        [self dismissAlertView];
    }
    
}

-(void)setDontDissmiss:(BOOL)dontDissmiss{
    _dontDissmiss=dontDissmiss;
}

-(void)showAlertView{
    _alertWindow=[[UIWindow alloc] initWithFrame:MainScreenRect];
    _alertWindow.windowLevel=UIWindowLevelAlert;
    [_alertWindow becomeKeyWindow];
    [_alertWindow makeKeyAndVisible];
    
    [_alertWindow addSubview:self];
    
    [self setShowAnimation];
    
}

-(void)dismissAlertView{
    [self removeFromSuperview];
    [_alertWindow resignKeyWindow];
}

-(void)setShowAnimation{

            [UIView animateWithDuration:0 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                [_alertView.layer setValue:@(0) forKeyPath:@"transform.scale"];
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.23 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    [_alertView.layer setValue:@(1.2) forKeyPath:@"transform.scale"];
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:0.09 delay:0.02 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                        [_alertView.layer setValue:@(.9) forKeyPath:@"transform.scale"];
                    } completion:^(BOOL finished) {
                        [UIView animateWithDuration:0.05 delay:0.02 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                            [_alertView.layer setValue:@(1.0) forKeyPath:@"transform.scale"];
                        } completion:^(BOOL finished) {
                            
                        }];
                    }];
                }];
            }];

}





@end
