#import "RichEditPostViewController.h"
#import "EditPostViewController_Internal.h"
#import "WPSegmentedSelectionTableViewController.h"
#import "Post.h"
#import "AutosavingIndicatorView.h"
#import "NSString+XMLExtensions.h"
#import "WPPopoverBackgroundView.h"
#import "WPAddCategoryViewController.h"
#import "WPStyleGuide.h"

@implementation RichEditPostViewController {
}

#define USE_AUTOSAVES 0

#pragma mark -
#pragma mark LifeCycle Methods

- (void)viewDidLoad {
    WPFLogMethod();
    if (self.editorToolbar == nil) {
        CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, WPKT_HEIGHT_PORTRAIT);
        if (IS_IOS7) {
            self.editorToolbar = [[WPKeyboardToolbarWithoutGradient alloc] initWithFrame:frame];
            self.editorToolbar.delegate = self;
        }
    }

    [super viewDidLoad];
    
    self.toolbar.translucent = NO;
    self.toolbar.barStyle = UIBarStyleDefault;
    self.titleTextField.placeholder = NSLocalizedString(@"Title:", @"Label for the title of the post field. Should be the same as WP core.");
    self.navigationController.navigationBar.translucent = NO;
}

#pragma mark -
#pragma mark Instance Methods

// IOS 7 Version which pushes a view controller instead of "swapping" it
- (IBAction)showSettings:(id)sender
{
    PostSettingsViewController *vc = [[PostSettingsViewController alloc] initWithPost:self.apost];
    vc.statsPrefix = self.statsPrefix;
    vc.postDetailViewController = self;
    self.navigationItem.title = NSLocalizedString(@"Back", nil);
    [self.navigationController pushViewController:vc animated:YES];
}

// IOS 7 Version which pushes a view controller instead of "swapping" it
- (IBAction)showPreview:(id)sender
{
    PostPreviewViewController *vc = [[PostPreviewViewController alloc] initWithPost:self.apost];
    vc.postDetailViewController = self;
    self.navigationItem.title = NSLocalizedString(@"Back", nil);
    [self.navigationController pushViewController:vc animated:YES];
}

- (CGRect)normalTextFrame {
    if (IS_IPAD) {
        CGFloat y = 143;
        if (IS_IOS7) {
            y = CGRectGetMaxY(self.titleTextField.frame);
        }
        CGFloat height = self.toolbar.frame.origin.y - y;
        if ((self.interfaceOrientation == UIDeviceOrientationLandscapeLeft)
            || (self.interfaceOrientation == UIDeviceOrientationLandscapeRight)) // Landscape
            return CGRectMake(0, y, self.view.bounds.size.width, height);
        else // Portrait
            return CGRectMake(0, y, self.view.bounds.size.width, height);
    } else {
        CGFloat y = 136.f;
        if (IS_IOS7) {
            // On IOS7 we get rid of the Tags and Categories fields, so place the textview right under the title
            y = CGRectGetMaxY(self.titleTextField.frame);
        }
        CGFloat height = self.toolbar.frame.origin.y - y;
        if ((self.interfaceOrientation == UIDeviceOrientationLandscapeLeft)
            || (self.interfaceOrientation == UIDeviceOrientationLandscapeRight)) // Landscape
			return CGRectMake(0, y, self.view.bounds.size.width, height);
		else // Portrait
			return CGRectMake(0, y, self.view.bounds.size.width, height);
    }
}

- (void)refreshButtons {
    
    // If we're autosaving our first post remotely, don't mess with the save button because we want it to stay disabled
    if (![self.apost hasRemote] && self.isAutosaving)
        return;
    
    if (self.navigationItem.leftBarButtonItem == nil) {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancelView:)];
        self.navigationItem.leftBarButtonItem = cancelButton;
    }

    NSString *buttonTitle;
    if(![self.apost hasRemote] || ![self.apost.status isEqualToString:self.apost.original.status]) {
        if ([self.apost.status isEqualToString:@"publish"] && ([self.apost.dateCreated compare:[NSDate date]] == NSOrderedDescending)) {
            buttonTitle = NSLocalizedString(@"Schedule", @"Schedule button, this is what the Publish button changes to in the Post Editor if the post has been scheduled for posting later.");
		} else if ([self.apost.status isEqualToString:@"publish"]){
            buttonTitle = NSLocalizedString(@"Publish", @"Publish button label.");
		} else {
            buttonTitle = NSLocalizedString(@"Save", @"Save button label (saving content, ex: Post, Page, Comment).");
        }
    } else {
        buttonTitle = NSLocalizedString(@"Update", @"Update button label (saving content, ex: Post, Page, Comment).");
    }

    if (self.navigationItem.rightBarButtonItem == nil) {
        UIBarButtonItem *saveButton;
        if (IS_IOS7) {
            saveButton = [[UIBarButtonItem alloc] initWithTitle:buttonTitle style:UIBarButtonItemStylePlain target:self action:@selector(saveAction:)];
        } else {
            saveButton = [[UIBarButtonItem alloc] initWithTitle:buttonTitle style:UIBarButtonItemStyleDone target:self action:@selector(saveAction:)];
        }
        self.navigationItem.rightBarButtonItem = saveButton;
    } else {
        self.navigationItem.rightBarButtonItem.title = buttonTitle;
    }

    BOOL updateEnabled = self.hasChanges || self.apost.remoteStatus == AbstractPostRemoteStatusFailed;
    [self.navigationItem.rightBarButtonItem setEnabled:updateEnabled];
}

// TODO :: Update for rich text editing
- (void)refreshUIForCurrentPost {
    self.navigationItem.title = [self editorTitle];

    self.titleTextField.text = self.apost.postTitle;
    if (self.post) {
        self.tagsTextField.text = self.post.tags;
        [self.categoriesButton setTitle:[NSString decodeXMLCharactersIn:[self.post categoriesText]] forState:UIControlStateNormal];
        [self.categoriesButton.titleLabel setFont:[UIFont systemFontOfSize:16.0f]];
    }
    
    if(self.apost.content == nil || [self.apost.content isEmpty]) {
        self.textViewPlaceHolderField.hidden = NO;
        self.textView.text = @"";
    }
    else {
        self.textViewPlaceHolderField.hidden = YES;
        if ((self.apost.mt_text_more != nil) && ([self.apost.mt_text_more length] > 0))
			self.textView.text = [NSString stringWithFormat:@"%@\n<!--more-->\n%@", self.apost.content, self.apost.mt_text_more];
		else
			self.textView.text = self.apost.content;
    }
    
	// workaround for odd text view behavior on iPad
	[self.textView setContentOffset:CGPointZero animated:NO];

    [self refreshButtons];
}

// TODO :: Update for rich text editing
- (void)autosaveContent {
    self.apost.postTitle = self.titleTextField.text;
    self.navigationItem.title = [self editorTitle];
    if (!IS_IOS7) {
        // Tags isn't on the main editor in iOS 7
        self.post.tags = self.tagsTextField.text;
    }
    self.apost.content = self.textView.text;
	if ([self.apost.content rangeOfString:@"<!--more-->"].location != NSNotFound)
		self.apost.mt_text_more = @"";

    if ( self.apost.original.password != nil ) { //original post was password protected
        if ( self.apost.password == nil || [self.apost.password isEqualToString:@""] ) { //removed the password
            self.apost.password = @"";
        }
    }

    [self.apost autosave];
}

#pragma mark -
#pragma mark AlertView Delegate Methods

// TODO :: Update for rich text editing
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    WordPressAppDelegate *delegate = (WordPressAppDelegate*)[[UIApplication sharedApplication] delegate];
	
    if (alertView.tag == EditPostViewControllerAlertTagLinkHelper) {
        self.isShowingLinkAlert = NO;
        if (buttonIndex == 1) {
            if ((self.urlField.text == nil) || ([self.urlField.text isEqualToString:@""])) {
                [delegate setAlertRunning:NO];
                return;
            }
			
            if ((self.infoText.text == nil) || ([self.infoText.text isEqualToString:@""]))
                self.infoText.text = self.urlField.text;
			
            NSString *urlString = [self validateNewLinkInfo:[self.urlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            NSString *aTagText = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", urlString, self.infoText.text];
            
            NSRange range = self.textView.selectedRange;
            
            NSString *oldText = self.textView.text;
            NSRange oldRange = self.textView.selectedRange;
            self.textView.text = [self.textView.text stringByReplacingCharactersInRange:range withString:aTagText];
            
            //reset selection back to nothing
            range.length = 0;
            
            if (range.length == 0) {                // If nothing was selected
                range.location += [aTagText length]; // Place selection between tags
                self.textView.selectedRange = range;
            }
            [[self.textView.undoManager prepareWithInvocationTarget:self] restoreText:oldText withRange:oldRange];
            [self.textView.undoManager setActionName:@"link"];
            
            self.hasChangesToAutosave = YES;
            [self autosaveContent];
            [self incrementCharactersChangedForAutosaveBy:MAX(oldRange.length, aTagText.length)];
        }
		
        [delegate setAlertRunning:NO];
        [self.textView touchesBegan:nil withEvent:nil];
        self.linkHelperAlertView = nil;
    } else if (alertView.tag == EditPostViewControllerAlertTagFailedMedia) {
        if (buttonIndex == 1) {
            WPFLog(@"Saving post even after some media failed to upload");
            [self savePost:YES];
        } else {
            [self switchToMedia];
        }
        self.failedMediaAlertView = nil;
    }
	
    return;
}


#pragma mark - TextView delegate

// TODO :: Update for rich text editing
- (void)textViewDidEndEditing:(UITextView *)aTextView {
    WPFLogMethod();
	
	if([self.textView.text isEqualToString:@""]) {
        [self.editView addSubview:self.textViewPlaceHolderField];
	}
	
    self.isEditing = NO;
    self.hasChangesToAutosave = YES;
    [self autosaveContent];
    [self autosaveRemote];

    [self refreshButtons];
}

#pragma mark - TextField delegate

// TODO :: Update for rich text editing
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField == self.titleTextField) {
        self.apost.postTitle = [textField.text stringByReplacingCharactersInRange:range withString:string];
        self.navigationItem.title = [self editorTitle];

    } else if (textField == self.tagsTextField) {
        self.post.tags = [self.tagsTextField.text stringByReplacingCharactersInRange:range withString:string];
    }

    self.hasChangesToAutosave = YES;
    [self refreshButtons];
    return YES;
}

#pragma mark - Media management

// TODO :: Update for rich text editing
- (void)insertMediaAbove:(NSNotification *)notification {
    [WPMobileStats trackEventForWPCom:[self formattedStatEventString:StatsEventPostDetailAddedPhoto]];
    
	Media *media = (Media *)[notification object];
	NSString *prefix = @"<br /><br />";
	
	if(self.apost.content == nil || [self.apost.content isEqualToString:@""]) {
		self.apost.content = @"";
		prefix = @"";
	}
	
	NSMutableString *content = [[NSMutableString alloc] initWithString:media.html];
	NSRange imgHTML = [self.textView.text rangeOfString: content];
	
	NSRange imgHTMLPre = [self.textView.text rangeOfString:[NSString stringWithFormat:@"%@%@", @"<br /><br />", content]];
 	NSRange imgHTMLPost = [self.textView.text rangeOfString:[NSString stringWithFormat:@"%@%@", content, @"<br /><br />"]];
	
	if (imgHTMLPre.location == NSNotFound && imgHTMLPost.location == NSNotFound && imgHTML.location == NSNotFound) {
		[content appendString:[NSString stringWithFormat:@"%@%@", prefix, self.apost.content]];
        self.apost.content = content;
	}
	else { 
		NSMutableString *processedText = [[NSMutableString alloc] initWithString:self.textView.text];
		if (imgHTMLPre.location != NSNotFound) 
			[processedText replaceCharactersInRange:imgHTMLPre withString:@""];
		else if (imgHTMLPost.location != NSNotFound) 
			[processedText replaceCharactersInRange:imgHTMLPost withString:@""];
		else  
			[processedText replaceCharactersInRange:imgHTML withString:@""];  
		 
		[content appendString:[NSString stringWithFormat:@"<br /><br />%@", processedText]]; 
		self.apost.content = content;
	}
    self.hasChangesToAutosave = YES;
    [self refreshUIForCurrentPost];
    [self.apost autosave];
    [self incrementCharactersChangedForAutosaveBy:content.length];
}

// TODO :: Update for rich text editing
- (void)insertMediaBelow:(NSNotification *)notification {
    [WPMobileStats trackEventForWPCom:[self formattedStatEventString:StatsEventPostDetailAddedPhoto]];
    
	Media *media = (Media *)[notification object];
	NSString *prefix = @"<br /><br />";
	
	if(self.apost.content == nil || [self.apost.content isEqualToString:@""]) {
		self.apost.content = @"";
		prefix = @"";
	}
	
	NSMutableString *content = [[NSMutableString alloc] initWithString:self.apost.content];
	NSRange imgHTML = [content rangeOfString: media.html];
	NSRange imgHTMLPre = [content rangeOfString:[NSString stringWithFormat:@"%@%@", @"<br /><br />", media.html]]; 
 	NSRange imgHTMLPost = [content rangeOfString:[NSString stringWithFormat:@"%@%@", media.html, @"<br /><br />"]];
	
	if (imgHTMLPre.location == NSNotFound && imgHTMLPost.location == NSNotFound && imgHTML.location == NSNotFound) {
		[content appendString:[NSString stringWithFormat:@"%@%@", prefix, media.html]];
        self.apost.content = content;
	}
	else {
		if (imgHTMLPre.location != NSNotFound) 
			[content replaceCharactersInRange:imgHTMLPre withString:@""]; 
		else if (imgHTMLPost.location != NSNotFound) 
			[content replaceCharactersInRange:imgHTMLPost withString:@""];
		else  
			[content replaceCharactersInRange:imgHTML withString:@""];
		[content appendString:[NSString stringWithFormat:@"<br /><br />%@", media.html]];
		self.apost.content = content;
	}
    self.hasChangesToAutosave = YES;
    [self refreshUIForCurrentPost];
    [self.apost autosave];
    [self incrementCharactersChangedForAutosaveBy:content.length];
}

// TODO :: Update for rich text editing
- (void)removeMedia:(NSNotification *)notification {
    [WPMobileStats trackEventForWPCom:[self formattedStatEventString:StatsEventPostDetailRemovedPhoto]];

	//remove the html string for the media object
	Media *media = (Media *)[notification object];
	self.textView.text = [self.textView.text stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"<br /><br />%@", media.html] withString:@""];
	self.textView.text = [self.textView.text stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@<br /><br />", media.html] withString:@""];
	self.textView.text = [self.textView.text stringByReplacingOccurrencesOfString:media.html withString:@""];
    self.hasChangesToAutosave = YES;
    [self autosaveContent];
    [self refreshUIForCurrentPost];
    [self incrementCharactersChangedForAutosaveBy:media.html.length];
}


#pragma mark - Keyboard toolbar

// TODO :: Update for rich text editing
- (void)restoreText:(NSString *)text withRange:(NSRange)range {
    NSLog(@"restoreText:%@",text);
    NSString *oldText = self.textView.text;
    NSRange oldRange = self.textView.selectedRange;
    self.textView.scrollEnabled = NO;
    // iOS6 seems to have a bug where setting the text like so : textView.text = text;
    // will cause an infinate loop of undos.  A work around is to perform the selector
    // on the main thread.
    // textView.text = text;
    [self.textView performSelectorOnMainThread:@selector(setText:) withObject:text waitUntilDone:NO];
    self.textView.scrollEnabled = YES;
    self.textView.selectedRange = range;
    [[self.textView.undoManager prepareWithInvocationTarget:self] restoreText:oldText withRange:oldRange];
    self.hasChangesToAutosave = YES;
    [self autosaveContent];
    [self incrementCharactersChangedForAutosaveBy:MAX(text.length, range.length)];
}

// TODO :: Update for rich text editing
- (void)wrapSelectionWithTag:(NSString *)tag {
    NSRange range = self.textView.selectedRange;
    NSRange originalRange = range;
    NSString *selection = [self.textView.text substringWithRange:range];
    NSString *prefix, *suffix;
    if ([tag isEqualToString:@"ul"] || [tag isEqualToString:@"ol"]) {
        prefix = [NSString stringWithFormat:@"<%@>\n", tag];
        suffix = [NSString stringWithFormat:@"\n</%@>\n", tag];
    } else if ([tag isEqualToString:@"li"]) {
        prefix = [NSString stringWithFormat:@"\t<%@>", tag];
        suffix = [NSString stringWithFormat:@"</%@>\n", tag];
    } else if ([tag isEqualToString:@"more"]) {
        prefix = @"<!--more-->";
        suffix = @"\n";
    } else if ([tag isEqualToString:@"blockquote"]) {
        prefix = [NSString stringWithFormat:@"\n<%@>", tag];
        suffix = [NSString stringWithFormat:@"</%@>\n", tag];
    } else {
        prefix = [NSString stringWithFormat:@"<%@>", tag];
        suffix = [NSString stringWithFormat:@"</%@>", tag];        
    }
    self.textView.scrollEnabled = NO;
    NSString *replacement = [NSString stringWithFormat:@"%@%@%@",prefix,selection,suffix];
    self.textView.text = [self.textView.text stringByReplacingCharactersInRange:range
                                                                     withString:replacement];
    self.textView.scrollEnabled = YES;
    if (range.length == 0) {                // If nothing was selected
        range.location += [prefix length]; // Place selection between tags
    } else {
        range.location += range.length + [prefix length] + [suffix length]; // Place selection after tag
        range.length = 0;
    }
    self.textView.selectedRange = range;
    self.hasChangesToAutosave = YES;
    [self autosaveContent];
    [self incrementCharactersChangedForAutosaveBy:MAX(replacement.length, originalRange.length)];
}

// TODO :: Update for rich text editing
- (void)keyboardToolbarButtonItemPressed:(WPKeyboardToolbarButtonItem *)buttonItem {
    WPFLogMethod();
    [self logWPKeyboardToolbarButtonStat:buttonItem];
    if ([buttonItem.actionTag isEqualToString:@"link"]) {
        [self showLinkView];
    } else if ([buttonItem.actionTag isEqualToString:@"done"]) {
        [self.textView resignFirstResponder];
    } else {
        NSString *oldText = self.textView.text;
        NSRange oldRange = self.textView.selectedRange;
        [self wrapSelectionWithTag:buttonItem.actionTag];
        [[self.textView.undoManager prepareWithInvocationTarget:self] restoreText:oldText withRange:oldRange];
        [self.textView.undoManager setActionName:buttonItem.actionName];
    }
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    WPFLogMethod();
    [super didReceiveMemoryWarning];
}

@end
