//
//  PostViewController.m
//  Svail
//
//  Created by Ronald Hernandez on 4/13/15.
//  Copyright (c) 2015 Svail. All rights reserved.
//

#import "PostViewController.h"
#import "Image.h"
#import <Parse/Parse.h>
#import "Service.h"
#import "User.h"
#import "SelectLocationFromMapViewController.h"
#import "MBProgressHUD.h"
#import <Social/Social.h>
#import <Accounts/Accounts.h>



@interface PostViewController ()<UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *serviceTitle;
@property (weak, nonatomic) IBOutlet UITextField *serviceDescription;
@property (weak, nonatomic) IBOutlet UITextField *serviceCategory;
@property (weak, nonatomic) IBOutlet UITextField *serviceCapacity;
@property (weak, nonatomic) IBOutlet UITextField *location;
@property (weak, nonatomic) IBOutlet UITextField *price;
@property SLComposeViewController *mySL;

@property Service *service;

@property (weak, nonatomic) IBOutlet UIDatePicker *startPickerDate;

@property (weak, nonatomic) IBOutlet UIDatePicker *endPickerDate;

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControlPicker;

@property User *currentUser;
@property (weak, nonatomic) IBOutlet UIView *firstView;

@property (weak, nonatomic) IBOutlet UIView *secondView;

@end

@implementation PostViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.service = [Service new];
    self.startPickerDate.transform = CGAffineTransformMakeScale(0.80, 0.65);
    self.endPickerDate.transform = CGAffineTransformMakeScale(0.80, 0.65);

    //set delegates for textfields
    [self setDelegatesForTextFields];




}

-(void)viewWillAppear:(BOOL)animated{


}

- (IBAction)onBackButtonTapped:(UIBarButtonItem *)sender {

    [self dismissViewControllerAnimated:YES completion:nil];

    
}




- (IBAction)onPostButtonTapped:(UIBarButtonItem *)sender {

    NSString *errorMessage = @"Error in from. Please note - All fields are required";


//    NSDate *startDate = [self.startPickerDate date];
//
//
//
//    NSDate *endDate = [self.endPickerDate date];




    // if ([self.serviceTitle.text isEqualToString:@""] || [self.serviceDescription.text isEqualToString:@""] || [self.serviceCategory.text isEqualToString:@""] || [self.serviceCapacity.text isEqualToString:@""] || [self.location.text isEqualToString:@""]) {
    //
    //        [self displayErrorAlert:errorMessage];
    //
    //
    //    }else{

    //MARK - Save Service information
    //    self.currentUser = [User new];
    //    self.currentUser.username = @"bitchesBeLike";
    //[self.currentUser setSessionToken:@"fsafsafafa"];

    //  [self.currentUser save];
    self.service.provider = [User currentUser];
    self.service.title = self.serviceTitle.text;
    self.service.serviceDescription = self.serviceDescription.text;
    self.service.category = self.serviceCategory.text;
    self.service.capacity = ((NSNumber *)self.serviceCapacity.text);
    self.service.price = ((NSNumber *) self.price.text);
    self.service.serviceLocationAddress = self.location.text;
     self.service.startDate = [self.startPickerDate date];
     self.service.endDate = [self.endPickerDate date];
    self.service.participants = @[].mutableCopy;

    if (self.segmentedControlPicker.selectedSegmentIndex == 0) {
        self.service.travel = false;
    }else if (self.segmentedControlPicker.selectedSegmentIndex == 1){
        self.service.travel = true;
    }
    //save the geopoint
    self.service.theServiceGeoPoint = self.serviceGeoPoint;








    //Indicator starts annimating when user posts.
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.7 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){


    [self.service saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {

//        //stop actiivity indication from annimating.
//        [activityIndicator stopAnimating];


        if (!error) {
            [self displaySuccessMessage:@"You Service has been posted"];

            [self performSegueWithIdentifier:@"toSelectImageVC" sender:self];
        }else{
            [self displayErrorAlert:error.localizedDescription];

        }
    }];

        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });



}

-(NSString*)getAddressFromLatLong : (NSString *)latLng {
    //  NSString *string = [[Address.text stringByAppendingFormat:@"+%@",cityTxt.text] stringByAppendingFormat:@"+%@",addressText];
    NSString *esc_addr =  [latLng stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    NSString *req = [NSString stringWithFormat:@"http://maps.google.com/maps/api/geocode/json?sensor=false&address=%@", esc_addr];
    NSString *result = [NSString stringWithContentsOfURL:[NSURL URLWithString:req] encoding:NSUTF8StringEncoding error:NULL];
    NSMutableDictionary *data = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding]options:NSJSONReadingMutableContainers error:nil];
    NSMutableArray *dataArray = (NSMutableArray *)[data valueForKey:@"results" ];
    if (dataArray.count == 0) {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Error" message:@"Please Enter a valid address" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];
    }else{
        for (id firstTime in dataArray) {
            NSString *jsonStr1 = [firstTime valueForKey:@"formatted_address"];
            return jsonStr1;
        }
    }

    return nil;
}


-(IBAction)unwindSegueFromSelectLocationFromMapViewController:(UIStoryboardSegue *)segue{

    if ([segue.sourceViewController isKindOfClass:[SelectLocationFromMapViewController class]]) {
        SelectLocationFromMapViewController *selectLocationVC = [segue sourceViewController];
        // if the user clicked Cancel, we don't want to change the color
        self.serviceGeoPoint = [PFGeoPoint new];

        self.serviceGeoPoint.latitude = selectLocationVC.serviceGeoPointFromMap.latitude;
        self.serviceGeoPoint.longitude = selectLocationVC.serviceGeoPointFromMap.longitude;
        self.location.text = selectLocationVC.userLocation;

        NSLog(@"%f %f", self.serviceGeoPoint.longitude, self.serviceGeoPoint.latitude);
    }
}
- (IBAction)onTappedButtonSetLocation:(UIButton *)sender {
        [self performSegueWithIdentifier:@"toSelectLocationFromMap" sender:self];
}

//hide keyboard when user touches outside.
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}



//Helper method to display error to user.
-(void)displayErrorAlert:(NSString *)error{


    UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"Error in form" message:error delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];

    [alertView show];

}

//Helper method to display success message to user.
-(void)displaySuccessMessage:(NSString *)text{


    UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"Success!" message:text delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    
    [alertView show];
    
}

#pragma Marks - hiding keyboard
-(BOOL)textFieldShouldReturn:(UITextField *)textField{
     [textField resignFirstResponder];

    [self.view endEditing:true];
    return false;
}


- (IBAction)hideKeyBoardForLocationTextField:(UITextField *)sender {
    [sender resignFirstResponder];

}
//set the delegate for textfields. 
//Helpers method to set the delegates of the textfields.
-(void)setDelegatesForTextFields{
    self.serviceTitle.delegate = self;
    self.serviceDescription.delegate = self;
    self.serviceCategory.delegate = self;
    self.serviceCapacity.delegate = self;
    self.location.delegate = self;

    
}
//share to facebook
- (IBAction)sharetoFacebookButton:(UIButton *)sender {

    //allocate composed view controller
    self.mySL = [[SLComposeViewController alloc]init];

    //set the type of social media that you want to post to.
    self.mySL = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];

    //set the text that you want to share.
    [self.mySL setInitialText:[NSString stringWithFormat:@"Hi, I just posted a new service on Svail! Please check it out! => %@ - %@ for only $%@", self.serviceTitle.text, self.serviceDescription.text, self.price.text]];

    [self presentViewController:self.mySL animated:true completion:nil];

    
}

- (IBAction)tweetItButtonTapped:(UIButton *)sender {

    //allocate composed view controller
    self.mySL = [[SLComposeViewController alloc]init];

    //set the type of social media that you want to post to.
    self.mySL = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];

    //set the text that you want to share.
    [self.mySL setInitialText:[NSString stringWithFormat:@"Hi, I just posted a new service on Svail! Please check it out! => %@ - %@ for only $%@", self.serviceTitle.text, self.serviceDescription.text, self.price.text]];

    [self presentViewController:self.mySL animated:true completion:nil];


}


@end
