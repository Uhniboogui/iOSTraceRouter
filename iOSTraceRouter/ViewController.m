//
//  ViewController.m
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import "ViewController.h"
#import "TraceRouteManager.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *txfHostname;
@property (weak, nonatomic) IBOutlet UITextView *tvTracerouteResult;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UIButton *startBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.spinner.hidesWhenStopped = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)startBtnTapped:(id)sender {
    
    [self.spinner startAnimating];
    [self.startBtn setEnabled:NO];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[TraceRouteManager sharedInstance] tracerouteForHost:self.txfHostname.text completion:^(NSString *resultString, NSError *error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (resultString) {
                    self.tvTracerouteResult.text = resultString;
                }
                
                if (error) {
                    self.tvTracerouteResult.text = error.description;
                }
                
                [self.spinner stopAnimating];
                [self.startBtn setEnabled:YES];
            });
        }];
    });
}

- (IBAction)cancelBtnTapped:(id)sender {
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.txfHostname endEditing:YES];
}

@end
