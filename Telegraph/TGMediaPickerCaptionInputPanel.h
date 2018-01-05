#import "HPGrowingTextView.h"

@class TGModernConversationAssociatedInputPanel;

@protocol TGMediaPickerCaptionInputPanelDelegate;

@interface TGMediaPickerCaptionInputPanel : UIView

@property (nonatomic, weak) id<TGMediaPickerCaptionInputPanelDelegate> delegate;

@property (nonatomic, strong) NSString *caption;
- (void)setCaption:(NSString *)caption animated:(bool)animated;

@property (nonatomic, readonly) HPGrowingTextView *inputField;

@property (nonatomic, assign) CGFloat bottomMargin;
@property (nonatomic, assign, getter=isCollapsed) bool collapsed;
- (void)setCollapsed:(bool)collapsed animated:(bool)animated;

- (void)replaceMention:(NSString *)mention;
- (void)replaceMention:(NSString *)mention username:(bool)username userId:(int32_t)userId;
- (void)replaceHashtag:(NSString *)hashtag;

- (void)adjustForOrientation:(UIInterfaceOrientation)orientation keyboardHeight:(CGFloat)keyboardHeight duration:(NSTimeInterval)duration animationCurve:(NSInteger)animationCurve;

- (void)dismiss;

- (CGFloat)heightForInputFieldHeight:(CGFloat)inputFieldHeight;
- (CGFloat)baseHeight;

- (void)setAssociatedPanel:(TGModernConversationAssociatedInputPanel *)associatedPanel animated:(bool)animated;
- (TGModernConversationAssociatedInputPanel *)associatedPanel;

- (void)setContentAreaHeight:(CGFloat)contentAreaHeight;

@end

@protocol TGMediaPickerCaptionInputPanelDelegate <NSObject>

- (bool)inputPanelShouldBecomeFirstResponder:(TGMediaPickerCaptionInputPanel *)inputPanel;
- (void)inputPanelFocused:(TGMediaPickerCaptionInputPanel *)inputPanel;
- (void)inputPanelRequestedSetCaption:(TGMediaPickerCaptionInputPanel *)inputPanel text:(NSString *)text;
- (void)inputPanelMentionEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel mention:(NSString *)mention startOfLine:(bool)startOfLine;
- (void)inputPanelHashtagEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel hashtag:(NSString *)hashtag;
- (void)inputPanelWillChangeHeight:(TGMediaPickerCaptionInputPanel *)inputPanel height:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve;

@optional
- (void)inputPanelTextChanged:(TGMediaPickerCaptionInputPanel *)inputTextPanel text:(NSString *)text;

@end
