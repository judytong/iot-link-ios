//
//  WCSoftapWaitVC.m
//  TenextCloud
//
//

#import "TIoTSoftapWaitVC.h"
#import "GCDAsyncUdpSocket.h"
#import <NetworkExtension/NEHotspotConfigurationManager.h>
#import "CHDWaveView.h"
#import "TIoTHelpCenterViewController.h"

#import "TIoTCoreAddDevice.h"

#define APIP @"192.168.4.1"
#define APPort 8266

@interface TIoTSoftapWaitVC ()<GCDAsyncUdpSocketDelegate,TIoTCoreAddDeviceDelegate>
@property (strong, nonatomic) GCDAsyncUdpSocket *socket;
@property (strong, nonatomic) dispatch_queue_t delegateQueue;

@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic) NSUInteger sendCount;
@property (nonatomic, strong) dispatch_source_t timer2;
@property (nonatomic) NSUInteger sendCount2;

@property (nonatomic, strong) NSTimer *progressTimer;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) CHDWaveView *pan;
@property (nonatomic, strong) UILabel *progressLab;
@property (nonatomic, strong) UILabel *tipLab;

@property (nonatomic,strong) NSDictionary *signInfo;//签名信息
@property (nonatomic, assign) BOOL isTokenbindedStatus;

@property (nonatomic, strong) TIoTCoreSoftAP   *softAP;

@end

@implementation TIoTSoftapWaitVC

- (void)dealloc
{
    DDLogDebug(@"释放");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupUI];
    
    [self createSoftAPWith:[NSString getGateway]];
    
}

- (void)createSoftAPWith:(NSString *)ip {

    NSString *apSsid = self.wifiInfo[@"name"];
    NSString *apPwd = self.wifiInfo[@"pwd"];
    
    self.softAP = [[TIoTCoreSoftAP alloc]initWithSSID:apSsid PWD:apPwd];
    self.softAP.delegate = self;
    self.softAP.gatewayIpString = ip;
    __weak __typeof(self)weakSelf = self;
    self.softAP.udpFaildBlock = ^{
        [weakSelf connectFaild];
    };
    [self.softAP startAddDevice];
}

#pragma mark - TIoTCoreAddDeviceDelegate 代理方法 (与TCSocketDelegate一一对应)
- (void)softApUdpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    DDLogInfo(@"连接成功");
    
    //设备收到WiFi的ssid/pwd/token，正在上报，此时2秒内，客户端没有收到设备回复，如果重复发送5次，都没有收到回复，则认为配网失败，Wi-Fi 设备有异常
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timer, ^{
        
        if (self.sendCount >= 5) {
            dispatch_source_cancel(self.timer);
            dispatch_async(dispatch_get_main_queue(), ^{
               [self connectFaild];
            });
            return ;
        }
        
        NSString *Ssid = self.wifiInfo[@"name"];
        NSString *Pwd = self.wifiInfo[@"pwd"];
        NSString *Token = self.wifiInfo[@"token"];
        [sock sendData:[NSJSONSerialization dataWithJSONObject:@{@"cmdType":@(1),@"ssid":Ssid,@"password":Pwd,@"token":Token} options:NSJSONWritingPrettyPrinted error:nil] withTimeout:-1 tag:10];
        self.sendCount ++;
    });
    dispatch_resume(self.timer);
}

- (void)softApUdpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    DDLogInfo(@"发送成功");
}

- (void)softApuUdpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    DDLogInfo(@"发送失败 %@", error);
}

- (void)softApUdpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    NSError *JSONParsingError;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&JSONParsingError];
    self.signInfo = dictionary;
    DDLogInfo(@"嘟嘟嘟 %@",dictionary);
    
    if ([dictionary[@"cmdType"] integerValue] == 2) {
        //设备已经收到WiFi的ssid/psw/token，正在进行连接WiFi并上报，此时客户端根据token 2秒轮询一次（总时长100s）检测设备状态,然后在绑定设备。
        //如果deviceReply返回的是Current_Error，则配网绑定过程中失败，需要退出配网操作;Previous_Error则为上一次配网的出错日志，只需要上报，不影响当此操作。
        if (![NSObject isNullOrNilWithObject:dictionary[@"deviceReply"]])  {
            if ([dictionary[@"deviceReply"] isEqualToString:@"Previous_Error"]) {
                [self checkTokenStateWithCirculationWithDeviceData:dictionary];
            }else {
                //deviceReplay 为 Cuttent_Error
                DDLogError(@"soft配网过程中失败，需要重新配网");
                [self connectFaild];
            }
            
        }else {
            DDLogInfo(@"dictionary==%@----soft链路设备success",dictionary);
            [self checkTokenStateWithCirculationWithDeviceData:dictionary];
        }
        
    }
}

//token 2秒轮询查看设备状态
- (void)checkTokenStateWithCirculationWithDeviceData:(NSDictionary *)data {
    dispatch_source_cancel(self.timer);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.timer2 = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(self.timer2, DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(self.timer2, ^{

            if (self.sendCount2 >= 100) {
                dispatch_source_cancel(self.timer2);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self connectFaild];
                });
                return ;
            }
            if (self.isTokenbindedStatus == NO) {
                [self getDevideBindTokenStateWithData:data];
            }
            
            self.sendCount2 ++;
        });
        dispatch_resume(self.timer2);

    });
}

//获取设备绑定token状态
- (void)getDevideBindTokenStateWithData:(NSDictionary *)deviceData {
    [[TIoTRequestObject shared] post:AppGetDeviceBindTokenState Param:@{@"Token":self.wifiInfo[@"token"]} success:^(id responseObject) {
        //State:Uint Token 状态，1：初始生产，2：可使用状态
        DDLogInfo(@"AppGetDeviceBindTokenState---responseobject=%@",responseObject);
        if ([responseObject[@"State"] isEqual:@(1)]) {
            self.isTokenbindedStatus = NO;
        }else if ([responseObject[@"State"] isEqual:@(2)]) {
            self.isTokenbindedStatus = YES;
            [self bindingDevidesWithData:deviceData];
        }
    } failure:^(NSString *reason, NSError *error,NSDictionary *dic) {
        DDLogError(@"AppGetDeviceBindTokenState---reason=%@---error=%@",reason,error);
        
    }];
}

//获取签名，绑定设备
- (void)bindDevice:(NSDictionary *)deviceData{
    if (![NSObject isNullOrNilWithObject:deviceData[@"productId"]]) {

        [[TIoTRequestObject shared] post:AppSigBindDeviceInFamily Param:@{@"ProductId":deviceData[@"productId"],@"DeviceName":deviceData[@"deviceName"],@"TimeStamp":deviceData[@"timestamp"],@"ConnId":deviceData[@"connId"],@"Signature":deviceData[@"signature"],@"DeviceTimestamp":deviceData[@"timestamp"],@"FamilyId":[TIoTCoreUserManage shared].familyId} success:^(id responseObject) {
            [self connectSucess:deviceData];
            [HXYNotice addUpdateDeviceListPost];
        } failure:^(NSString *reason, NSError *error,NSDictionary *dic) {
            [self connectFaild];
        }];
    }
    else
    {
        [self connectFaild];
    }
}

//判断token返回后（设备状态为2），绑定设备
- (void)bindingDevidesWithData:(NSDictionary *)deviceData {
    if (![NSObject isNullOrNilWithObject:deviceData[@"productId"]]) {
        NSString *roomId = self.roomId ?: @"0";
        [[TIoTRequestObject shared] post:AppTokenBindDeviceFamily Param:@{@"ProductId":deviceData[@"productId"],@"DeviceName":deviceData[@"deviceName"],@"Token":self.wifiInfo[@"token"],@"FamilyId":[TIoTCoreUserManage shared].familyId,@"RoomId":roomId} success:^(id responseObject) {
            [self connectSucess:deviceData];
            [HXYNotice addUpdateDeviceListPost];
        } failure:^(NSString *reason, NSError *error,NSDictionary *dic) {
            [self connectFaild];
        }];
    }else {
        [self connectFaild];
    }

}

#pragma mark - UI

- (void)setupUI{
    self.view.backgroundColor = kRGBColor(247, 249, 250);
    
    UIButton *cancleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancleBtn addTarget:self action:@selector(cancleClick:) forControlEvents:UIControlEventTouchUpInside];
    [cancleBtn setTitle:NSLocalizedString(@"off", @"关闭") forState:UIControlStateNormal];
    [cancleBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    cancleBtn.titleLabel.font = [UIFont wcPfRegularFontOfSize:16];
    [cancleBtn sizeToFit];
    UIBarButtonItem *cancleItem = [[UIBarButtonItem alloc] initWithCustomView:cancleBtn];
    self.navigationItem.leftBarButtonItems  = @[cancleItem];
    
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.bottom.equalTo(self.view);
    }];
    
    [self.scrollView addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
        make.height.greaterThanOrEqualTo(@0.f);
    }];
    
    self.pan = [[CHDWaveView alloc] initWithFrame: CGRectMake(0, 64, kScreenWidth, 220)];
    self.pan.backgroundColor = kRGBColor(204, 204, 204);
    self.pan.progress = 0;
    self.pan.speed = 0.8;
    [self.contentView addSubview:self.pan];
    
    
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self progress];
    }];
    [[NSRunLoop currentRunLoop] addTimer:self.progressTimer forMode:NSRunLoopCommonModes];
    
    self.progressLab = [[UILabel alloc] init];
    self.progressLab.text = NSLocalizedString(@"connection", @"连接中");
    self.progressLab.textColor = kRGBColor(51, 51, 51);
    self.progressLab.font = [UIFont wcPfSemiboldFontOfSize:24];
    [self.contentView addSubview:self.progressLab];
    [self.progressLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentView);
        make.top.equalTo(self.pan.mas_bottom).offset(40);
    }];
    
    self.tipLab = [[UILabel alloc] init];
    self.tipLab.text = NSLocalizedString(@"connect_toast", @"请将设备与手机尽量靠近") ;
    self.tipLab.textColor = kRGBColor(51, 51, 51);
    self.tipLab.font = [UIFont wcPfRegularFontOfSize:16];
    [self.view addSubview:self.tipLab];
    [self.tipLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.progressLab.mas_bottom).offset(10);
    }];
}

//假的进度条
- (void)progress{
    self.pan.progress += 0.01;
    if (self.pan.progress >= 0.99){
        self.pan.progress = 0.99;
    }
}

//配网成功
- (void)connectSucess:(NSDictionary *)devieceData{
    [self releaseAlloc];
    self.tipLab.hidden = YES;
    self.progressLab.text = NSLocalizedString(@"connect_success", @"连接成功");
//    [self.pan sucess];
    self.pan.progress = 1;
    
    UIButton *tryAgainBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [tryAgainBtn setTitle:NSLocalizedString(@"add_new_device", @"继续添加新设备") forState:UIControlStateNormal];
    [tryAgainBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tryAgainBtn.titleLabel.font = [UIFont wcPfRegularFontOfSize:16];
    [tryAgainBtn addTarget:self action:@selector(changeTypeClick:) forControlEvents:UIControlEventTouchUpInside];
    tryAgainBtn.backgroundColor = [UIColor colorWithHexString:kIntelligentMainHexColor];
    tryAgainBtn.layer.cornerRadius = 3;
    [self.view addSubview:tryAgainBtn];
    [tryAgainBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(30);
        make.top.equalTo(self.progressLab.mas_bottom).offset(149 * kScreenAllHeightScale);
        make.width.mas_equalTo(kScreenWidth - 60);
        make.height.mas_equalTo(48);
    }];
    
    
    UIButton *changeTypeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [changeTypeBtn setTitle:NSLocalizedString(@"back_home", @"返回首页") forState:UIControlStateNormal];
    [changeTypeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    changeTypeBtn.titleLabel.font = [UIFont wcPfRegularFontOfSize:16];
    [changeTypeBtn addTarget:self action:@selector(backHome:) forControlEvents:UIControlEventTouchUpInside];
    changeTypeBtn.backgroundColor = [UIColor colorWithHexString:kIntelligentMainHexColor];
    changeTypeBtn.layer.cornerRadius = 3;
    [self.view addSubview:changeTypeBtn];
    [changeTypeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(30);
        make.top.equalTo(tryAgainBtn.mas_bottom).offset(30 * kScreenAllHeightScale);
        make.width.mas_equalTo(kScreenWidth - 60);
        make.height.mas_equalTo(48);
        make.bottom.equalTo(self.contentView).offset(-30);
    }];
}

//配网失败
- (void)connectFaild{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self releaseAlloc];
        self.tipLab.hidden = YES;
        self.progressLab.text = NSLocalizedString(@"connect_fail", @"连接失败");
//        [self.pan faild];
        self.pan.progress = 0;
        
        UILabel *errorResultLab = [[UILabel alloc] init];
        errorResultLab.numberOfLines = 0;
        errorResultLab.textColor = kRGBColor(153, 153, 153);
        errorResultLab.font = [UIFont wcPfRegularFontOfSize:14];
        errorResultLab.text = NSLocalizedString(@"connect_step", @"1、检查设备是否通电，并按照指引进入配网模式\n2、检查WIFI是否正常（暂时只支持2.4G路由器）\n3、检查WIFI密码是否错误");
        errorResultLab.textAlignment = NSTextAlignmentLeft;
        [self.contentView addSubview:errorResultLab];
        [errorResultLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView).offset(30);
            make.right.equalTo(self.contentView).offset(-30);
            make.top.equalTo(self.progressLab.mas_bottom).offset(10);
        }];
        
        UIButton *moreResultBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [moreResultBtn setTitle:NSLocalizedString(@"see_more_fail_cause",  @"查看更多失败原因") forState:UIControlStateNormal];
        [moreResultBtn addTarget:self action:@selector(moreErrorResult:) forControlEvents:UIControlEventTouchUpInside];
        moreResultBtn.titleLabel.font = [UIFont wcPfRegularFontOfSize:16];
        [moreResultBtn setTitleColor:kRGBColor(235, 61, 61) forState:UIControlStateNormal];
        [self.contentView addSubview:moreResultBtn];
        [moreResultBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView).offset(30);
            make.top.equalTo(errorResultLab.mas_bottom).offset(5);
        }];
        
        UIButton *tryAgainBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [tryAgainBtn setTitle:NSLocalizedString(@"connect_again", @"按步骤重试")  forState:UIControlStateNormal];
        [tryAgainBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        tryAgainBtn.titleLabel.font = [UIFont wcPfRegularFontOfSize:16];
        [tryAgainBtn addTarget:self action:@selector(tryAgainClick:) forControlEvents:UIControlEventTouchUpInside];
        tryAgainBtn.backgroundColor = [UIColor whiteColor];
        tryAgainBtn.layer.cornerRadius = 3;
        [self.view addSubview:tryAgainBtn];
        [tryAgainBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.view).offset(30);
            make.top.equalTo(moreResultBtn.mas_bottom).offset(40 * kScreenAllHeightScale);
            make.width.mas_equalTo(kScreenWidth - 60);
            make.height.mas_equalTo(48);
        }];
        
        
        UIButton *changeTypeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [changeTypeBtn setTitle:NSLocalizedString(@"tab_connect_way", @"切换配网方式") forState:UIControlStateNormal];
        [changeTypeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        changeTypeBtn.titleLabel.font = [UIFont wcPfRegularFontOfSize:16];
        [changeTypeBtn addTarget:self action:@selector(changeTypeClick:) forControlEvents:UIControlEventTouchUpInside];
        changeTypeBtn.backgroundColor = [UIColor colorWithHexString:kIntelligentMainHexColor];
        changeTypeBtn.layer.cornerRadius = 3;
        [self.view addSubview:changeTypeBtn];
        [changeTypeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.view).offset(30);
            make.top.equalTo(tryAgainBtn.mas_bottom).offset(30 * kScreenAllHeightScale);
            make.width.mas_equalTo(kScreenWidth - 60);
            make.height.mas_equalTo(48);
            make.bottom.equalTo(self.contentView).offset(-30);
        }];
    });
}

- (void)releaseAlloc{
    self.timer = nil;
    self.timer2 = nil;
    
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    if (self.socket) {
        [self.socket close];
        self.socket = nil;
    }
    
}

#pragma mark - event

- (void)cancleClick:(id)sender{
    TIoTAlertView *av = [[TIoTAlertView alloc] initWithFrame:[UIScreen mainScreen].bounds andStyle:WCAlertViewStyleText];
    [av alertWithTitle:NSLocalizedString(@"exit_toast_title", @"退出添加设备") message:NSLocalizedString(@"addDevicing_confirmSignout", @"当前正在添加设备，是否确认退出") cancleTitlt:NSLocalizedString(@"cancel", @"取消") doneTitle:NSLocalizedString(@"confirm", @"确定")];
    av.doneAction = ^(NSString * _Nonnull text) {
        [self releaseAlloc];
        [self dismissViewControllerAnimated:YES completion:nil];
    };
    [av showInView:[UIApplication sharedApplication].keyWindow];
}

- (void)changeTypeClick:(id)sender{
    [self dismissViewControllerAnimated:YES completion:nil];
    [HXYNotice postChangeAddDeviceType:0];
}

- (void)tryAgainClick:(id)sender{
    [self dismissViewControllerAnimated:YES completion:nil];
    [HXYNotice postChangeAddDeviceType:1];
}

- (void)moreErrorResult:(id)sender{
    TIoTHelpCenterViewController *vc = [[TIoTHelpCenterViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)backHome:(id)sender{
    [self dismissViewControllerAnimated:YES completion:nil];
    [HXYNotice addUpdateDeviceListPost];
}

- (void)toBind
{
    [self bindDevice:self.signInfo];
}

#pragma mark setter or getter
- (UIScrollView *)scrollView{
    if (_scrollView == nil) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.backgroundColor = kRGBColor(247, 249, 250);
    }
    return _scrollView;
}

- (UIView *)contentView{
    if (_contentView == nil) {
        _contentView = [[UIView alloc] init];
        _contentView.backgroundColor = kRGBColor(247, 249, 250);
    }
    return _contentView;
}
@end
