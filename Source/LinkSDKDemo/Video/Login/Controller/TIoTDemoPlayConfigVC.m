//
//  TIoTDemoPlayConfigVC.m
//  LinkSDKDemo
//

#import "TIoTDemoPlayConfigVC.h"
#import "NSObject+additions.h"
#import "UIColor+Color.h"
#import "NSString+Extension.h"
#import "TIoTCoreAppEnvironment.h"
#import "TIoTLoginCustomView.h"
#import "TIoTDemoHomeViewController.h"
#import "TIoTDemoNavController.h"
#import "TIoTDemoTabBarController.h"
#import "TIoTCoreUserManage.h"

@interface TIoTDemoPlayConfigVC ()
@property (nonatomic, strong) TIoTLoginCustomView *loginView;
@property (nonatomic, strong) UIButton *loginBtn;
@end

@implementation TIoTDemoPlayConfigVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGFloat kTopSpace = 30;
    CGFloat kWidthPadding = 16;
    
    self.loginView = [[TIoTLoginCustomView alloc]init];
    [self.view addSubview:self.loginView];
    [self.loginView mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11.0, *)) {
            make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(kTopSpace);
        }else {
            make.top.equalTo(self.view);
        }
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(56*3 + 3 + 35 + 21);
    }];
    
    self.loginBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.loginBtn.backgroundColor = [UIColor colorWithHexString:kVideoDemoMainThemeColor];
    [self.loginBtn setButtonFormateWithTitlt:@"登录" titleColorHexString:@"#FFFFFF" font:[UIFont wcPfRegularFontOfSize:17]];
    [self.loginBtn addTarget:self action:@selector(requestDeviceList) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loginBtn];
    [self.loginBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left).offset(kWidthPadding);
        make.right.equalTo(self.view.mas_right).offset(-kWidthPadding);
        make.top.equalTo(self.loginView.mas_bottom).offset(40);
        make.height.mas_equalTo(45);
    }];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(hideKeyBoard)];
    [self.view addGestureRecognizer:tap];
    
    // 读取信息
    [self readAccessID];
    
    [self readLoginInfoFromManage];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
}

- (void)hideKeyBoard {
    [self.loginView.accessID resignFirstResponder];
    [self.loginView.accessToken resignFirstResponder];
    [self.loginView.productID resignFirstResponder];
}

#pragma mark - event

- (void)requestDeviceList {
    
    // 保存信息
    [self saveDeviceInfo];
    
    if ((![NSString isNullOrNilWithObject:self.loginView.secretIDString] && ![NSString isFullSpaceEmpty:self.loginView.secretIDString]) && (![NSString isNullOrNilWithObject:self.loginView.secretKeyString] && ![NSString isFullSpaceEmpty:self.loginView.secretKeyString]) && (![NSString isNullOrNilWithObject:self.loginView.productIDString] && ![NSString isFullSpaceEmpty:self.loginView.productIDString])) {
        
        TIoTCoreAppEnvironment *environment = [TIoTCoreAppEnvironment shareEnvironment];
        environment.cloudSecretId = self.loginView.secretIDString;
        environment.cloudSecretKey = self.loginView.secretKeyString;
        environment.cloudProductId = self.loginView.productIDString;
        
        //原播放列表
        TIoTDemoHomeViewController *homeVC = [[TIoTDemoHomeViewController alloc]init];
        [self.navigationController pushViewController:homeVC animated:YES];
    }else {
        //原播放列表
        TIoTDemoHomeViewController *homeVC = [[TIoTDemoHomeViewController alloc]init];
        [self.navigationController pushViewController:homeVC animated:YES];
    }
    
}

- (void)saveDeviceInfo {
    
    [self saveLoginViewInfo];
    
    [self saveAccessID];
}

- (void)saveLoginViewInfo {
    [TIoTCoreUserManage shared].demoAccessID = self.loginView.accessID.text?:@"";
    
    self.loginView.secretIDString = self.loginView.accessID.text?:@"";
    
    NSUserDefaults *defaluts = [NSUserDefaults standardUserDefaults];
    if (![NSString isNullOrNilWithObject:self.loginView.accessID.text?:@""]) {
        [defaluts setValue:@{@"AccessTokenString":self.loginView.accessToken.text?:@"",@"productIDString":self.loginView.productID.text?:@""} forKey:self.loginView.accessID.text?:@""];
        self.loginView.secretKeyString = self.loginView.accessToken.text;
        self.loginView.productIDString = self.loginView.productID.text;
        
    }
}

- (void)saveAccessID {
    NSUserDefaults *defaluts = [NSUserDefaults standardUserDefaults];
    NSMutableArray *accessIDArray = [NSMutableArray arrayWithArray:[defaluts objectForKey:@"AccessIDArrayKey"]];
    if (accessIDArray != nil) {
        if (![accessIDArray containsObject:self.loginView.secretIDString?:@""]) {
            [accessIDArray addObject:self.loginView.accessID.text?:@""];
            [defaluts setValue:accessIDArray forKey:@"AccessIDArrayKey"];
        }
    }else {
        NSMutableArray *IDArray = [[NSMutableArray alloc]init];
        [IDArray addObject:self.loginView.secretIDString?:@""];
        [defaluts removeObjectForKey:[defaluts objectForKey:@"AccessIDArrayKey"]];
        [defaluts setValue:IDArray forKey:@"AccessIDArrayKey"];
    }
}

- (void)readLoginInfoFromManage {
    self.loginView.accessID.text = [TIoTCoreUserManage shared].demoAccessID?:@"";
    
    NSUserDefaults *defaluts = [NSUserDefaults standardUserDefaults];
    NSDictionary *tokenAndProductIDDic = [NSDictionary dictionaryWithDictionary:[defaluts objectForKey:self.loginView.accessID.text?:@""]];
    if (tokenAndProductIDDic != nil) {
        self.loginView.accessToken.text = [tokenAndProductIDDic objectForKey:@"AccessTokenString"];
        self.loginView.productID.text = [tokenAndProductIDDic objectForKey:@"productIDString"];
    }
}

- (void)readAccessID {
    NSUserDefaults *defaluts = [NSUserDefaults standardUserDefaults];
    NSMutableArray *accessIDArray = [NSMutableArray arrayWithArray:[defaluts objectForKey:@"AccessIDArrayKey"]];
    if (accessIDArray != nil) {
        if (accessIDArray.count != 0) {
            self.loginView.accessID.text = accessIDArray.lastObject;
        }
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
