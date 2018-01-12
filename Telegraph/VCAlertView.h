#import <UIKit/UIKit.h>

typedef void(^LXAlertClickIndexBlock)(NSInteger clickIndex);

@interface VCAlertView : UIView

@property (nonatomic,copy)LXAlertClickIndexBlock clickBlock;

/**
 *  初始化alert方法（根据内容自适应大小，目前只支持1个按钮或2个按钮）
 *
 *  @param title         标题
 *  @param message       内容（根据内容自适应大小）
 *  @param cancelTitle   取消按钮
 *  @param otherBtnTitle 其他按钮
 *  @param block         点击事件block
 *
 *  @return 返回alert对象
 */
-(instancetype)initWithTitle:(NSString *)title message:(NSString *)message cancelBtnTitle:(NSString *)cancelTitle otherBtnTitle:(NSString *)otherBtnTitle clickIndexBlock:(LXAlertClickIndexBlock)block;

/**
 *  showLXAlertView
 */
-(void)showAlertView;

/**
 *  不隐藏，默认为NO。设置为YES时点击按钮alertView不会消失（适合在强制升级时使用）
 */
@property (nonatomic,assign)BOOL dontDissmiss;

// 黑色的文字浮窗
+ (void) blackHudWithText:(NSString *)message;
@end



