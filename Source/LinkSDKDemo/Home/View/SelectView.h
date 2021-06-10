//
//  WCChoseValueView.h
//  TenextCloud
//
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SelectView : UIView

@property (nonatomic) BOOL isAction;//控制删除动作按钮
@property (nonatomic, copy) void (^deleteTap)(void);

@property (nonatomic, copy) void (^updateData)(NSDictionary *dataDic);
@property (nonatomic, copy) NSString *showValue;//要选中的值
@property (nonatomic, copy) NSDictionary *dic;
- (void)show;
- (void)hide;

@end

NS_ASSUME_NONNULL_END
