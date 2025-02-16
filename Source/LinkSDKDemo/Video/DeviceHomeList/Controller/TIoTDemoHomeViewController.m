//
//  TIoTDemoHomeViewController.m
//  LinkApp
//
//

#import "TIoTDemoHomeViewController.h"
#import "UIImage+TIoTDemoExtension.h"
#import "TIoTDemoVideoDeviceCell.h"
#import "TIoTDemoDeviceHeaderView.h"
#import "TIoTDemoCustomSheetView.h"
#import "TIoTCoreAppEnvironment.h"
#import "TIoTCoreDeviceSet.h"
#import "TIoTCoreXP2PBridge.h"
#import "TIoTDemoSameScreenVC.h"

#import "TIoTExploreDeviceListModel.h"
#import "TIoTVideoDeviceListModel.h"
#import "TIoTExploreOrVideoDeviceModel.h"
#import <YYModel.h>
#import "TIoTCloudStorageVC.h"
#import "TIoTDemoPreviewDeviceVC.h"
#import "TIoTDemoProductDetailModel.h"
#import "TIoTDemoNVRSubDeviceVC.h"
#import "TIoTDemoPlaybackVC.h"

static NSInteger const maxLimitDeviceNumber = 4;
static NSString *const kVideoDeviceListCellID = @"kVideoDeviceListCellID";
static NSString *const kVIdeoDeviceListHeaderID = @"kVIdeoDeviceListHeaderID";
static NSInteger const kLimit = 100;

@interface TIoTDemoHomeViewController ()<UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *dataArray;
@property (nonatomic, assign) BOOL isShowSameScreenChoiceIcon;
@property (nonatomic, strong) NSMutableArray *selectedArray;
@property (nonatomic, assign) BOOL isNVR;
@end

@implementation TIoTDemoHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupNavBar];
    [self setupUIViews];
    [self addRefreshControl];
    [self requestDeviceList];
}

- (void)setupNavBar {
    self.title = @"IoT Video Demo";
    [self setupNavBarStyleWithNormal:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavBarStyleWithNormal:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self setupNavBarStyleWithNormal:YES];
}

- (void)setupNavBarStyleWithNormal:(BOOL)isNormal {
    
    if (isNormal) {
        [self.navigationController.navigationBar setBackgroundImage:[UIImage getGradientImageWithColors:@[[UIColor colorWithHexString:@"#ffffff"],[UIColor colorWithHexString:@"#ffffff"]] imgSize:CGSizeMake(kScreenWidth, 44)] forBarMetrics:UIBarMetricsDefault];
    }else {
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithHexString:@"#FFFFFF"],NSFontAttributeName:[UIFont wcPfRegularFontOfSize:17]}];
        [self.navigationController.navigationBar setBackgroundImage:[UIImage getGradientImageWithColors:@[[UIColor colorWithHexString:@"#3D8BFF"],[UIColor colorWithHexString:@"#1242FF"]] imgSize:CGSizeMake(kScreenWidth, 44)] forBarMetrics:UIBarMetricsDefault];
        self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    }
    
}

- (void)setupUIViews {
    
    self.isShowSameScreenChoiceIcon = NO;
    
    self.view.backgroundColor = [UIColor colorWithHexString:KActionSheetBackgroundColor];
    
    [self.view addSubview:self.collectionView];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11.0, *)) {
            make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        }else {
            make.top.equalTo(self.view).offset(64);
        }
        make.left.right.bottom.equalTo(self.view);
    }];
    
}

- (void)addRefreshControl {
    if (@available(iOS 10.0,*)) {
        
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        refreshControl.tintColor = [UIColor colorWithHexString:kVideoDemoTextContentColor];
        refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"下拉刷新" attributes:@{NSFontAttributeName:[UIFont wcPfRegularFontOfSize:14],NSForegroundColorAttributeName:[UIColor colorWithHexString:kVideoDemoMainThemeColor]}];
        [refreshControl addTarget:self action:@selector(refreshDeviceList:) forControlEvents:UIControlEventValueChanged];
        self.collectionView.refreshControl = refreshControl;
    }
}

- (void)refreshDeviceList:(UIRefreshControl *)sender {
    [self requestDeviceList];
}

#pragma mark - 请求设备列表
- (void)requestDeviceList {
    
    //获取产品详情、区分NVR
    [self requestProductDetail];
    
}

- (void)requestProductDetail {
    NSMutableDictionary *paramDic = [[NSMutableDictionary alloc]init];
    paramDic[@"ProductId"] = [TIoTCoreAppEnvironment shareEnvironment].cloudProductId?:@"";
    paramDic[@"Version"] = @"2020-12-15";
    [[TIoTCoreDeviceSet shared] requestVideoOrExploreDataWithParam:paramDic action:DescribeProduct vidowOrExploreHost:TIotApiHostVideo success:^(id  _Nonnull responseObject) {
        
        TIoTDemoProductDetailModel *model = [TIoTDemoProductDetailModel yy_modelWithJSON:responseObject];
        if (![NSString isNullOrNilWithObject:model.Data.DeviceType]) {
            if ([model.Data.DeviceType isEqualToString:@"1"]) { //IPC
                self.isNVR = NO;
            }else if ([model.Data.DeviceType isEqualToString:@"2"]){ //NVR
                self.isNVR = YES;
            }
            //video 设备列表
            [self requestVideoList];
        }
        
    } failure:^(NSString * _Nullable reason, NSError * _Nullable error, NSDictionary * _Nullable dic) {
        
    }];
    
}

///MARK: video 设备列表
- (void)requestVideoList {
    
    NSMutableDictionary *paramDic = [[NSMutableDictionary alloc]init];
    paramDic[@"ProductId"] = [TIoTCoreAppEnvironment shareEnvironment].cloudProductId?:@"";
    paramDic[@"Version"] = @"2020-12-15";
    paramDic[@"Limit"] = [NSNumber numberWithInteger:kLimit];
    paramDic[@"Offset"] = [NSNumber numberWithInteger:0];

    [[TIoTCoreDeviceSet shared] requestVideoOrExploreDataWithParam:paramDic action:DescribeDevices vidowOrExploreHost:TIotApiHostVideo success:^(id  _Nonnull responseObject) {
        TIoTExploreDeviceListModel *model = [TIoTExploreDeviceListModel yy_modelWithJSON:responseObject];

        [self.dataArray removeAllObjects];
        self.dataArray = [NSMutableArray arrayWithArray:model.Devices];
        [self.collectionView reloadData];
        [self.collectionView.refreshControl endRefreshing];
    } failure:^(NSString * _Nullable reason, NSError * _Nullable error, NSDictionary * _Nullable dic) {

    }];
}

#pragma mark - UICollectionViewDataSource And UICollectionViewDelegate
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataArray.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    TIoTDemoVideoDeviceCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kVideoDeviceListCellID forIndexPath:indexPath];
    
    TIoTExploreOrVideoDeviceModel *model = self.dataArray[indexPath.row];
    
    cell.isShowChoiceDeviceIcon = self.isShowSameScreenChoiceIcon;
    __weak typeof(self) weakSelf = self;
    cell.chooseDeviceBlock = ^(UIButton * _Nonnull itemBtn) {
        if (weakSelf.selectedArray.count <= maxLimitDeviceNumber - 1) {
            if ([itemBtn.currentImage isEqual:[UIImage imageNamed:@"device_unselect"]]) {
                model.isSelected = @"1";
                [weakSelf.selectedArray addObject:model];
                [itemBtn setImage:[UIImage imageNamed:@"device_select"] forState:UIControlStateNormal];
            }else if ([itemBtn.currentImage isEqual:[UIImage imageNamed:@"device_select"]]) {
                model.isSelected = @"0";
                [weakSelf.selectedArray removeObject:model];
                [itemBtn setImage:[UIImage imageNamed:@"device_unselect"] forState:UIControlStateNormal];
            }
            itemBtn.selected = !itemBtn.selected;
        }else {
            if ([itemBtn.currentImage isEqual:[UIImage imageNamed:@"device_unselect"]]) {
                [MBProgressHUD showMessage:[NSString stringWithFormat:@"最多选择%ld台摄像机",(long)maxLimitDeviceNumber] icon:@"overstep_device"];
            }else if ([itemBtn.currentImage isEqual:[UIImage imageNamed:@"device_select"]]) {
                model.isSelected = @"0";
                [weakSelf.selectedArray removeObject:model];
                [itemBtn setImage:[UIImage imageNamed:@"device_unselect"] forState:UIControlStateNormal];
                itemBtn.selected = !itemBtn.selected;
            }
        }
    };
    cell.model = model;
    
    if (self.isNVR == YES) {
        cell.isNVRDevice = YES;
    }
    
    TIoTDemoCustomSheetView *customActionSheet = [[TIoTDemoCustomSheetView alloc]init];
    cell.moreActionBlock = ^{
        NSArray *actionTitleArray = @[@"预览",@"回放",@"取消"];
        
        ChooseFunctionBlock previewVideoBlock = ^(TIoTDemoCustomSheetView *view){
            DDLogVerbose(@"预览");
            
            TIoTDemoPreviewDeviceVC *previewDeviceVC = [[TIoTDemoPreviewDeviceVC alloc]init];
            previewDeviceVC.selectedModel = model;
            previewDeviceVC.isNVR = NO;
            [weakSelf.navigationController pushViewController:previewDeviceVC animated:YES];
            [weakSelf resetDeviceListStatus];
            [customActionSheet removeFromSuperview];
        };
        
        ChooseFunctionBlock playbackVideoBlock = ^(TIoTDemoCustomSheetView *view){
            DDLogVerbose(@"回放");
            TIoTExploreOrVideoDeviceModel *model = self.dataArray[indexPath.row];
//            TIoTCloudStorageVC *cloudStorageVC = [[TIoTCloudStorageVC alloc]init];
//            cloudStorageVC.deviceModel = model;
//            [self.navigationController pushViewController:cloudStorageVC animated:YES];
//            [customActionSheet removeFromSuperview];
            
            TIoTDemoPlaybackVC *playBackVC = [[TIoTDemoPlaybackVC alloc]init];
            playBackVC.deviceModel = model;
            playBackVC.isNVR = self.isNVR;
            playBackVC.deviceName = model.DeviceName;
            playBackVC.isFromHome = YES;
            
            [self.navigationController pushViewController:playBackVC animated:YES];
            [customActionSheet removeFromSuperview];  
        };
        
        ChooseFunctionBlock cancelBlock = ^(TIoTDemoCustomSheetView *view) {
            DDLogVerbose(@"取消");
            [view removeFromSuperview];
        };
        NSArray *actionBlockArray = @[previewVideoBlock,playbackVideoBlock,cancelBlock];
        
        
        [customActionSheet sheetViewTopTitleArray:actionTitleArray withMatchBlocks:actionBlockArray];
        [[UIApplication sharedApplication].delegate.window addSubview:customActionSheet];
        [customActionSheet mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.leading.right.bottom.equalTo([UIApplication sharedApplication].delegate.window);
        }];
    };
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    TIoTExploreOrVideoDeviceModel *model = self.dataArray[indexPath.row];
    if (self.isNVR == YES) {
        //NVR 子设备页面
        TIoTDemoNVRSubDeviceVC *NVRDeviceVC = [[TIoTDemoNVRSubDeviceVC alloc]init];
        NVRDeviceVC.selectedModel = model;
        [self.navigationController pushViewController:NVRDeviceVC animated:YES];
    }else {
        //预览页
        TIoTDemoPreviewDeviceVC *previewDeviceVC = [[TIoTDemoPreviewDeviceVC alloc]init];
        previewDeviceVC.selectedModel = model;
        previewDeviceVC.isNVR = NO;
        [self.navigationController pushViewController:previewDeviceVC animated:YES];
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    CGFloat kHeight = 44;
    if (self.dataArray.count == 0) {
        kHeight = 0;
    }
    return CGSizeMake(kScreenWidth, kHeight);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    TIoTDemoDeviceHeaderView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:kVIdeoDeviceListHeaderID forIndexPath:indexPath];
    __weak typeof(self) weakSelf = self;
    
    //编辑操作
    headerView.editBlock = ^(TIoTDemoDeviceHeaderView *headerView,BOOL isEditPartten){
        
        if (isEditPartten) {
            TIoTDemoCustomSheetView *editSheet = [[TIoTDemoCustomSheetView alloc]init];
            
            NSArray *actionTitleArray = @[@"编辑同屏摄像机",@"取消"];
            //选择同频摄像机
            ChooseFunctionBlock editSameScreen = ^(TIoTDemoCustomSheetView *view) {
                
                weakSelf.isShowSameScreenChoiceIcon = YES;
                
                [collectionView reloadData];
                
                [headerView enterEditPattern];
                [editSheet removeFromSuperview];
            };
            //取消
            ChooseFunctionBlock cancelBlock = ^(TIoTDemoCustomSheetView *view) {
                [headerView exitEditPattern];
                [view removeFromSuperview];
            };
            
            NSArray *actionBlockArray = @[editSameScreen,cancelBlock];
            
            [editSheet sheetViewTopTitleArray:actionTitleArray withMatchBlocks:actionBlockArray];
            [[UIApplication sharedApplication].delegate.window addSubview:editSheet];
            [editSheet mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.leading.right.bottom.equalTo([UIApplication sharedApplication].delegate.window);
            }];
        }else {
            if (self.selectedArray.count != 0) {
                TIoTDemoSameScreenVC *sameScreenVC = [[TIoTDemoSameScreenVC alloc]init];
                sameScreenVC.isNVRType = NO;
                [sameScreenVC setupSameScreenArray:self.selectedArray];
                [weakSelf.navigationController pushViewController:sameScreenVC animated:YES];
                [weakSelf resetDeviceListStatus];
            }else {
                [weakSelf resetDeviceListStatus];
            }
        }
        
    };
    
    //取消操作
    headerView.cancelEditBlock = ^{
        [weakSelf resetDeviceListStatus];
    };
    if (self.isNVR == YES) {
        [headerView hideEditButton];
    }
    return headerView;
    
}

#pragma mark - event

- (void)resetDeviceListStatus {
    self.isShowSameScreenChoiceIcon = NO;
    [self.dataArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        TIoTExploreOrVideoDeviceModel *model = obj;
        model.isSelected = @"0";
    }];
    if (self.selectedArray.count != 0) {
        [self.selectedArray removeAllObjects];
    }
    [self.collectionView reloadData];
}

#pragma mark - Lazy loading
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc]init];
        CGFloat scale = 138.0/165.0;
        CGFloat itemWidth = (kScreenWidth - 16*2 - 13)/2;
        CGFloat itemHeight = itemWidth*scale;
        CGFloat padding = 16;
        flowLayout.sectionHeadersPinToVisibleBounds = YES;
        flowLayout.itemSize = CGSizeMake(itemWidth, itemHeight);
        flowLayout.sectionInset = UIEdgeInsetsMake(4, padding, 4, padding);
        _collectionView = [[UICollectionView alloc]initWithFrame:CGRectZero collectionViewLayout:flowLayout];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.backgroundColor = [UIColor colorWithHexString:@"#F5F5F5"];
        [_collectionView registerClass:[TIoTDemoVideoDeviceCell class] forCellWithReuseIdentifier:kVideoDeviceListCellID];
        [_collectionView registerClass:[TIoTDemoDeviceHeaderView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:kVIdeoDeviceListHeaderID];
    }
    return _collectionView;
}

- (NSMutableArray *)selectedArray {
    if (!_selectedArray) {
        _selectedArray = [[NSMutableArray alloc]init];
    }
    return _selectedArray;
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
