///  MapViewController.m
//  Svail
//
//  Created by Mert Akanay on 4/14/15.
//  Copyright (c) 2015 Svail. All rights reserved.
//

#import "MapViewController.h"
#import <MapKit/MapKit.h>
#import "EventLocationDownloader.h"
#import "Service.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <ParseFacebookUtilsV4/PFFacebookUtils.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import "ParticipantsViewController.h"

//PARTICIPANT NUMBER ADDED TO EVENT ? CHANGE PIN COLOR ACCORDINGLY
//SEARCH SERVICE ONLY AROUND THE CURRENT LOCATION OR DRAGGED LOCATION
//CALLOUT CUSTOMIZED

@interface MapViewController () <MKMapViewDelegate, CLLocationManagerDelegate, UISearchBarDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property CLLocationManager *locationManager;
@property MKPointAnnotation *providerPoint;
@property MKPointAnnotation *draggedAnnotation;
@property NSMutableArray *eventsArray;
@property NSMutableArray *searchResults;
@property NSMutableArray *filterArray;
@property NSArray *resultsArray;
@property NSArray *annotationArray;
@property NSMutableArray *serviceParticipants;


@property (weak, nonatomic) IBOutlet UIBarButtonItem *profileButton;

@end

@implementation MapViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.locationManager = [CLLocationManager new];
    [self.locationManager requestWhenInUseAuthorization];
    self.mapView.showsUserLocation = YES;

    self.profileButton.image = [[User currentUser] objectForKey:@"profileImage"];

    //setting today's date and the next days of the week for segmented control's titles
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"MM/dd"];
    NSString *theDate = [dateFormat stringFromDate:currentDate];
    [self.segmentedControl setTitle:theDate forSegmentAtIndex:0];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *dayComponent = [NSDateComponents new];

    for (int i = 1; i < 7; i++) {
        dayComponent.day = i;
        NSDate *nextDay = [calendar dateByAddingComponents:dayComponent toDate:currentDate options:0];
        NSString *nextDayDate = [dateFormat stringFromDate:nextDay];
        [self.segmentedControl setTitle:nextDayDate forSegmentAtIndex:i];
    }

    //making segmentedcontrol selected when the view loads
    self.segmentedControl.selected = YES;

    //dismissing keyboard when tapped outside searchBar
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];

    //download Services from Parse and filter it according to today's event
    [EventLocationDownloader downloadEventLocation:^(NSArray *array)
     {
         self.eventsArray = [NSMutableArray arrayWithArray:array];
         [self filterEventsForDate:self.segmentedControl];
     }];
}

#pragma Mark - Dismiss Keyboard Method

-(void)dismissKeyboard {
    [self.searchBar resignFirstResponder];
    [self searchBarSearchButtonClicked:self.searchBar];
}

#pragma Mark - Helper Method to add Annotations on Map

-(void)addAnnotationToMapFromArray:(NSArray *)array
{
    //converting GeoPoint stored on Parse to coordinate and adding the annotation on map
    for (Service *aService in array) {

        PFGeoPoint *serviceGeoPoint = [aService objectForKey:@"theServiceGeoPoint"];
        double latitude = serviceGeoPoint.latitude;
        double longtitude = serviceGeoPoint.longitude;
        CLLocationCoordinate2D serviceCoordinate = CLLocationCoordinate2DMake(latitude, longtitude);
        aService.annotation = [[MKPointAnnotation alloc] init];
        aService.annotation.title = [aService objectForKey:@"title"];
        aService.annotation.coordinate = serviceCoordinate;
        [self.mapView addAnnotation:aService.annotation];

    }
}

#pragma Mark - Helper Method to zoom to a defined span on Map

-(void)zoom:(double *)latitude :(double *)logitude
{
    MKCoordinateRegion region;
    region.center.latitude = *latitude;
    region.center.longitude = *logitude;
    region.span.latitudeDelta = 0.05;
    region.span.longitudeDelta = 0.05;
    region = [self.mapView regionThatFits:region];
    [self.mapView setRegion:region animated:YES];
}

#pragma Mark - MKMapView Delegate Methods

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    MKPinAnnotationView *pinAnnotation = [[MKPinAnnotationView alloc]initWithAnnotation:annotation reuseIdentifier:nil];

    if (annotation == mapView.userLocation) {
        return nil;
    }

    //making the pinAnnotation of user's location draggable
    //    if (annotation == mapView.userLocation || annotation == self.draggedAnnotation) {
    //        pinAnnotation.pinColor = MKPinAnnotationColorPurple;
    //        pinAnnotation.draggable = YES;
    //    }
    pinAnnotation.canShowCallout = YES;
    pinAnnotation.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeContactAdd];
    pinAnnotation.leftCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];

    return pinAnnotation;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState
{
    //getting new coordinate from dragged pin annotation
    if (newState == MKAnnotationViewDragStateEnding)
    {
        CLLocationCoordinate2D newCoordinate = view.annotation.coordinate;
        NSLog(@"dropped at %f,%f", newCoordinate.latitude, newCoordinate.longitude);
        self.draggedAnnotation = [MKPointAnnotation new];
        self.draggedAnnotation.coordinate = newCoordinate;
        self.mapView.showsUserLocation = NO;
        [self.mapView addAnnotation:self.draggedAnnotation];

    }
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self.locationManager startUpdatingLocation];

}

-(void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    //zooming map to current location at startup
    double latitude = self.locationManager.location.coordinate.latitude;
    double longitude = self.locationManager.location.coordinate.longitude;
    [self zoom:&latitude :&longitude];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    //    for (CLLocation *location in locations) {
    //        if (location.verticalAccuracy < 100 && location.horizontalAccuracy < 100)
    //        {
    ////            [self.locationManager stopUpdatingLocation];
    ////            [self findEventNearby:location];
    //        }
    //    }
}

-(void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{

        NSArray *emptyArray = @[];
        PFQuery *newQuery=[Service query];
        [newQuery whereKey:@"participants" notContainedIn:emptyArray];
        [newQuery includeKey:@"participants"];
        [newQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            self.serviceParticipants = objects.mutableCopy;

            if (control == view.rightCalloutAccessoryView)
            {
                [self.serviceParticipants addObject:[User currentUser]];
            }
            else if (control == view.leftCalloutAccessoryView)
            {
                UIStoryboard *profileStoryBoard = [UIStoryboard storyboardWithName:@"UserProfile" bundle:nil];
                ParticipantsViewController *participantsVC = [profileStoryBoard instantiateViewControllerWithIdentifier:@"participantsVC"];
                [self presentViewController:participantsVC animated:true completion:nil];
                participantsVC.participants = self.serviceParticipants;
            }
        }];



}

#pragma Mark - Methods to filter Services with SegmentedControl and SearchBar

- (IBAction)segmentSelected:(UISegmentedControl *)sender
{
    [self filterEventsForDate:sender];
}

-(void)filterEventsForDate:(UISegmentedControl *)sender
{
    //removing all annotations from map
    self.annotationArray = self.mapView.annotations;
    [self.mapView removeAnnotations:self.annotationArray];

    self.filterArray = [NSMutableArray new];

    NSString *currentDate = [self.segmentedControl titleForSegmentAtIndex:sender.selectedSegmentIndex];

    for (Service *aService in self.eventsArray) {

        //changing the date format for date on Parse and storing it as a string
        NSDate *serviceDate = [aService objectForKey:@"startDate"];
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        //        [dateFormat setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
        [dateFormat setDateFormat:@"MM/dd"];
        NSString *serviceDateString = [dateFormat stringFromDate:serviceDate];

        if ([serviceDateString isEqualToString:currentDate])
        {
            [self.filterArray addObject:aService];

            if ([self.searchBar.text isEqualToString:@""]) {
                [self addAnnotationToMapFromArray:self.filterArray];
            }
        }
    }
    [self.mapView reloadInputViews];
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    //removing all annotations from map
    self.annotationArray = self.mapView.annotations;
    [self.mapView removeAnnotations:self.annotationArray];

    self.searchResults = [NSMutableArray new];

    if (![searchBar.text isEqualToString:@""]) {

        for (Service *aService in self.filterArray) {
            if ([[aService objectForKey:@"title"] containsString:searchBar.text]) {

                [self.searchResults addObject:aService];
            }
        }
    }else{
        self.searchResults = self.filterArray;
    }
    [self addAnnotationToMapFromArray:self.searchResults];

    [searchBar resignFirstResponder];
}


#pragma Mark - Segue to Post Service View Controller

- (IBAction)onAddServiceButtonTapped:(UIBarButtonItem *)sender
{
    //        UIStoryboard *postStoryBoard = [UIStoryboard storyboardWithName:@"Post" bundle:nil];
    //        UIViewController *postVC = [postStoryBoard instantiateViewControllerWithIdentifier:@"PostNavBar"];
    //        [self presentViewController:postVC animated:true completion:nil];

    if ([User currentUser] != nil){

        NSLog(@"the user is loggged in");

        UIStoryboard *postStoryBoard = [UIStoryboard storyboardWithName:@"Post" bundle:nil];

        UIViewController *postVC = [postStoryBoard instantiateViewControllerWithIdentifier:@"PostNavBar"];

        [self presentViewController:postVC animated:true completion:nil];

    }else {

        //        UIStoryboard *loginStoryBoard = [UIStoryboard storyboardWithName:@"Login" bundle:nil];

        //        UIViewController *loginVC = [loginStoryBoard instantiateViewControllerWithIdentifier:@"LoginNavVC"];

        //        [self presentViewController:loginVC animated:true completion:nil];

        [self presentActionSheetForLogInOrSignUp];


    }

}


- (IBAction)onProfileButtonTapped:(UIBarButtonItem *)sender
{
    UIStoryboard *editProfileStoryBoard = [UIStoryboard storyboardWithName:@"EditProfile" bundle:nil];
    UIViewController *editProfileVC = [editProfileStoryBoard instantiateViewControllerWithIdentifier:@"editProfileNavVC"];
    [self presentViewController:editProfileVC animated:true completion:nil];
}


#pragma Mark - Unwind Segues

-(IBAction)unwindSegueFromLogInViewController:(UIStoryboardSegue *)segue

{

}

-(IBAction)unwindSegueFromRegisterViewController:(UIStoryboardSegue *)segue

{

}


#pragma Marks - Helper Methods

//actionSheets - this will handle the user's actions

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{



    if (buttonIndex == 0) {

        UIStoryboard *loginStoryBoard = [UIStoryboard storyboardWithName:@"Login" bundle:nil];

        UIViewController *loginVC = [loginStoryBoard instantiateViewControllerWithIdentifier:@"LoginNavVC"];

        [self presentViewController:loginVC animated:true completion:nil];



    } else if(buttonIndex == 1){

        UIStoryboard *signUpStoryBoard = [UIStoryboard storyboardWithName:@"Login" bundle:nil];

        UIViewController *signUpVC = [signUpStoryBoard instantiateViewControllerWithIdentifier:@"SignUpNavVC"];

        [self presentViewController:signUpVC animated:true completion:nil];



    }else{

        NSArray *permissionsArray = @[ @"email", @"public_profile"];

        [PFFacebookUtils logInInBackgroundWithReadPermissions:permissionsArray block:^(PFUser *user, NSError *error) {
            if (!user) {
                NSLog(@"Uh oh. The user cancelled the Facebook login.");

                //Present an alert when the user cancels the login

                NSString *alertMessage = @"There was a problem logging in. You must Svail to use your facebook account to log you in";

                NSString *alertTitle =@"Oops - Facebook Login was canceled";

                [[[UIAlertView alloc] initWithTitle:alertTitle

                                            message:alertMessage

                                           delegate:nil

                                  cancelButtonTitle:@"OK"

                                  otherButtonTitles:nil] show];

            } else if (user.isNew) {
                //if the user is new want to get his/her data and store it in parse.
                [self getFacebookUserData];

                //we also need to retrieve his profile picture.


                UIStoryboard *profileStoryBoard = [UIStoryboard storyboardWithName:@"EditProfile" bundle:nil];
                ParticipantsViewController *editProfileVC = [profileStoryBoard instantiateViewControllerWithIdentifier:@"editProfileNavVC"];
                [self presentViewController:editProfileVC animated:true completion:nil];



                NSLog(@"User signed up and logged in through Facebook!");




                NSLog(@"%@", user);
            } else {
                NSLog(@"User logged in through Facebook!");
            }
        }];



    }

}

//this helper method is used to retrieve the facebook data from the user and store in parse.
-(void)getFacebookUserData{

    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:nil];
    [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
        // handle response
        [User currentUser].name = result[@"name"];
        [User currentUser].email = result[@"email"];
        [User currentUser].isFbUser = true;
        [[User currentUser] saveInBackground];


        [self getFbUserProfileImage:result[@"id"]];

    }];
}

//helper method to retrieve user's profile image from facebook..

-(void)getFbUserProfileImage:(id)facebookID{


    // URL should point to https://graph.facebook.com/{facebookId}/picture?type=large&return_ssl_resources=1
    NSURL *pictureURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=large&return_ssl_resources=1", facebookID]];

    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:pictureURL];

    // Run network request asynchronously
    [NSURLConnection sendAsynchronousRequest:urlRequest
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:
     ^(NSURLResponse *response, NSData *data, NSError *connectionError) {
         if (connectionError == nil && data != nil) {
             // Set the image in the imageView
             // UIImage *image = [UIImage imageWithData:data];

             PFFile *file = [ PFFile fileWithData:data];

             [User currentUser].profileImage = file;

             [[User currentUser] saveInBackground];


             NSLog(@"%@", data);
         }
     }];
    
}

-(void)presentActionSheetForLogInOrSignUp{
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Sign in or Sign Up"
                                  
                                                             delegate:self
                                  
                                                    cancelButtonTitle:@"Cancel"destructiveButtonTitle:nil otherButtonTitles:@"Sign in", @"Sign Up", @"Login With Facebook", nil];
    
    
    //present the action sheet.
    [actionSheet showInView:self.view];
    
}


@end
