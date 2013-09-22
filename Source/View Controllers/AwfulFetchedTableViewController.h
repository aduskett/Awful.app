//  AwfulFetchedTableViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulOldTableViewController.h"

@interface AwfulFetchedTableViewController : AwfulOldTableViewController <NSFetchedResultsControllerDelegate>

// Subclasses must implement.
- (NSFetchedResultsController *)createFetchedResultsController;

@end
