//
//  ReviewPurchaseViewController.m
//  Svail
//
//  Created by zhenduo zhu on 4/22/15.
//  Copyright (c) 2015 Svail. All rights reserved.
//

#import "ReviewReservationViewController.h"
#import "User.h"
#import "Verification.h"
#import "Service.h"
#import "ServiceSlot.h"
#import "Rating.h"
#import "ConfirmPurchaseViewController.h"
#import "CustomViewUtilities.h"
#import "RatingViewController.h"
#import "Image.h"
#import "ServiceImagesCollectionViewCell.h"
#import "ParticipantCollectionViewCell.h"
#import "PickTimeSlotViewController.h"


@interface ReviewReservationViewController () <UICollectionViewDelegate,UICollectionViewDataSource>
@property (weak, nonatomic) IBOutlet UIImageView *providerProfileImageView;
@property (weak, nonatomic) IBOutlet UILabel *providerNameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *safetyImageView;
@property (weak, nonatomic) IBOutlet UILabel *ratingLabel;
@property (weak, nonatomic) IBOutlet UILabel *numOfServicesLabel;
@property (weak, nonatomic) IBOutlet UILabel *serviceTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *servicePriceLabel;
@property (weak, nonatomic) IBOutlet UILabel *serviceDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *serviceTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *serviceCapacityLabel;
@property (weak, nonatomic) IBOutlet UILabel *serviceCategoryLabel;
@property (weak, nonatomic) IBOutlet UILabel *serviceLocationLabel;
@property (weak, nonatomic) IBOutlet UITextView *serviceDescriptionTextView;
@property (weak, nonatomic) IBOutlet UILabel *participantsLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *serviceImagesCollectionView;
@property (weak, nonatomic) IBOutlet UICollectionView *participantsCollectionView;
@property (weak, nonatomic) IBOutlet UIButton *pickTimeSlotButton;



@property (nonatomic) User *currentUser;
@property (nonatomic) NSMutableArray *participants;
@property (nonatomic) NSMutableArray *serviceImageArray;
@property (nonatomic) User *provider;

@end

@implementation ReviewReservationViewController

static NSUInteger kMaxNumberOfServiceImages = 4;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
  //  [self getServiceImages];

    //setup color tint
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:255/255.0 green:127/255.0 blue:59/255.0 alpha:1.0];
    
    //setting image to Navigation Bar's title
    UILabel *titleView = (UILabel *)self.navigationItem.titleView;
    titleView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 30)];
    titleView.font = [UIFont fontWithName:@"Noteworthy" size:20];
    titleView.text = @"Review Reservation";
    titleView.textColor = [UIColor colorWithRed:21/255.0 green:137/255.0 blue:255/255.0 alpha:1.0];
    [self.navigationItem setTitleView:titleView];
    
    
    self.participantsCollectionView.showsHorizontalScrollIndicator = true;
    self.safetyImageView.hidden = true;
    self.currentUser = [User currentUser];
    
    self.participantsCollectionView.layer.borderWidth = 0.5;
    self.participantsCollectionView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    
    self.participantsCollectionView.hidden = true;
    self.serviceTimeLabel.hidden = true;
    
    self.serviceImageArray = [[NSMutableArray alloc]initWithCapacity:kMaxNumberOfServiceImages];
    for (int i = 0; i < kMaxNumberOfServiceImages; i++) {
        self.serviceImageArray[i] = [UIImage imageNamed:@"image_placeholder"];
    }
    [self.serviceImagesCollectionView reloadData];
    

    
    PFQuery *serviceQuery = [Service query];
    [serviceQuery includeKey:@"provider.verification"];
    [serviceQuery includeKey:@"participants"];
    serviceQuery.cachePolicy = kPFCachePolicyCacheThenNetwork;
    [serviceQuery getObjectInBackgroundWithId:self.service.objectId block:^(PFObject *object, NSError *error)
     {
         
         if (!error) {
             self.service = (Service *)object;

             self.provider = self.service.provider;
             self.participants = self.service.participants;
             [self.participantsCollectionView reloadData];
             
             self.providerNameLabel.text = self.service.provider.name;
             
             if ([[self.provider.verification objectForKey:@"safetyLevel"] integerValue] >= 5) {
                 self.safetyImageView.hidden = false;
             } else {
                 self.safetyImageView.hidden = true;
             }
             
             [self.provider.profileImage getDataInBackgroundWithBlock:^(NSData *data, NSError *error)
              {
                  if (!error) {
                      [CustomViewUtilities setupProfileImageView:self.providerProfileImageView WithImage:[UIImage imageWithData:data]];
                  }
              }];
             
             PFQuery *providerServicesQuery = [Service query];
             [providerServicesQuery whereKey:@"provider" equalTo:self.service.provider];
             providerServicesQuery.cachePolicy = kPFCachePolicyCacheThenNetwork;
             [providerServicesQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
              {
                  if (!error) {
                      self.numOfServicesLabel.text = [NSString stringWithFormat:@"%lu",objects.count];
                      
                  }
                  
              }];
             
             PFQuery *providerRatingsQuery = [Rating query];
             [providerRatingsQuery whereKey:@"ratee" equalTo:self.provider];
             providerRatingsQuery.cachePolicy = kPFCachePolicyCacheThenNetwork;
             [providerRatingsQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
              {
                  if (!error) {
                      self.ratingLabel.text = [NSString stringWithFormat:@"%.1f",[[objects valueForKeyPath:@"@avg.value"] doubleValue]];
                  }
              }];
             
             
         } else {
             //             UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
             //            [alert show];
             return;
         }
         
     }];
    
    
    
    [self setupTitleLabel];
    [self setupPriceLabel];
    [self setupCapacityLabel];
    [self setupCategoryLabel];
    [self setupDateLabel];
    if (self.serviceSlot) {
        self.serviceTimeLabel.hidden = false;
        [self setupTimeLabel];
    }

    [self setupLocationLabel];
    [self setupDescriptionTextView];
    
    
    

}

-(void)getServiceImages
{
    PFQuery *imagesQuery = [Image query];
    [imagesQuery whereKey:@"service" equalTo:self.service];
    [imagesQuery findObjectsInBackgroundWithBlock:^(NSArray *objects,
                                                    NSError *error)
     {
         if (!error) {
             [self.serviceImagesCollectionView reloadData];
             for (int i = 0;i < objects.count;i++) {
                 PFFile *imageFile = objects[i];
                 [imageFile getDataInBackgroundWithBlock:^(NSData *data,
                                                           NSError *error)
                  {
                      if (!error) {
                          self.serviceImageArray[i] = [UIImage imageWithData:data];
                          [self.serviceImagesCollectionView reloadData];
                      }
                  }];
             }
         }
     }];
}


- (IBAction)onCancelButtonTapped:(UIBarButtonItem *)sender
{
    UIStoryboard *mapStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController *mapNavVC = [mapStoryboard instantiateViewControllerWithIdentifier:@"MapNavVC"];
    [self presentViewController:mapNavVC animated:true completion:nil];
    
}

-(void)setupTitleLabel
{
    self.serviceTitleLabel.text = [NSString stringWithFormat:@"Title %@",self.service.title];
    self.serviceTitleLabel.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.serviceTitleLabel.text rangeOfString:@"Title"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.serviceTitleLabel.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.serviceTitleLabel.attributedText = attributedText;
}


-(void)setupTimeLabel
{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"HH:MM"];
    self.serviceTimeLabel.text = [NSString stringWithFormat:@"Time %@",
                                  [self.serviceSlot getStartTimeString]];
    self.serviceTimeLabel.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.serviceTimeLabel.text rangeOfString:@"Time"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.serviceTimeLabel.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.serviceTimeLabel.attributedText = attributedText;
}


-(void)setupDateLabel
{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"MM/dd/yy"];
    self.serviceDateLabel.text = [NSString stringWithFormat:@"Date %@",
                                  [dateFormatter stringFromDate:self.service.startDate]],
    self.serviceDateLabel.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.serviceDateLabel.text rangeOfString:@"Date"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.serviceDateLabel.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.serviceDateLabel.attributedText = attributedText;
}


-(void)setupPriceLabel
{
    
    self.servicePriceLabel.text = [NSString stringWithFormat:@"Price : $%@",self.service.price];
    self.servicePriceLabel.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.servicePriceLabel.text rangeOfString:@"Price"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.servicePriceLabel.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.servicePriceLabel.attributedText = attributedText;
}

-(void)setupCapacityLabel
{
    
    self.serviceCapacityLabel.text = [NSString stringWithFormat:@"Capacity : %@",self.service.capacity];
    self.serviceCapacityLabel.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.serviceCapacityLabel.text rangeOfString:@"Capacity"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.serviceCapacityLabel.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.serviceCapacityLabel.attributedText = attributedText;
}

-(void)setupLocationLabel
{
    self.serviceLocationLabel.numberOfLines = 0;
    self.serviceLocationLabel.text = [NSString stringWithFormat:@"Location %@",self.service.serviceLocationAddress];
    self.serviceLocationLabel.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.serviceLocationLabel.text rangeOfString:@"Location"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.serviceLocationLabel.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.serviceLocationLabel.attributedText = attributedText;
}


-(void)setupCategoryLabel
{
    self.serviceCategoryLabel.numberOfLines = 0;
    self.serviceCategoryLabel.text = [NSString stringWithFormat:@"Category %@",self.service.category];
    self.serviceCategoryLabel.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.serviceCategoryLabel.text rangeOfString:@"Category"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.serviceCategoryLabel.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.serviceCategoryLabel.attributedText = attributedText;
}

-(void)setupDescriptionTextView
{
    self.serviceDescriptionTextView.text = [NSString stringWithFormat:@"Description\n%@",self.service.serviceDescription];
    self.serviceDescriptionTextView.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.serviceDescriptionTextView.text rangeOfString:@"Description"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.serviceDescriptionTextView.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.serviceDescriptionTextView.attributedText = attributedText;
}

-(void)setupParticipantsLabel
{
    
    self.participantsLabel.text = [NSString stringWithFormat:@"Participants"];
    self.participantsLabel.font = [UIFont fontWithName:@"Arial" size:15.0];
    NSRange range = [self.participantsLabel.text rangeOfString:@"Participants"];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]initWithString:self.participantsLabel.text];
    [attributedText setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:13.0]} range:range];
    [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
    self.participantsLabel.attributedText = attributedText;
    
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (collectionView == self.serviceImagesCollectionView) {
        return self.serviceImageArray.count;
    } else {
        return self.participants.count;
    }
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (collectionView == self.serviceImagesCollectionView) {
        ServiceImagesCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ServiceImageCell" forIndexPath:indexPath];
        cell.serviceImageView.image = self.serviceImageArray[indexPath.row];
        return cell;
    } else {
        ParticipantCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ParticipantCell" forIndexPath:indexPath];
        User *participant = self.participants[indexPath.row];
        [participant.profileImage getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
            if (!error) {
                [CustomViewUtilities setupProfileImageView:cell.profileImageView WithImage:[UIImage imageWithData:data]];
                [cell layoutSubviews];
            }
        }];
        cell.nameLabel.text = participant.name;
        return cell;
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
//    RatingViewController *ratingVC = [segue destinationViewController];
//    ratingVC.service = self.service;
    if ([segue.identifier isEqualToString:@"ToPickTimeSlotSegue"] ) {
        PickTimeSlotViewController *pickTimeSlotVC = segue.destinationViewController;
        pickTimeSlotVC.service = self.service;
    }
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if (![self.service.participants containsObject:self.currentUser]) {
        return YES;
    } else {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil message:@"You already reserved the service" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];
        return NO;
    }
}

@end
