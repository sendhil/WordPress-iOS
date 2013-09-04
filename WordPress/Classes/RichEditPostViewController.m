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
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, WPKT_HEIGHT_PORTRAIT);
    self.editorToolbar = [[WPKeyboardToolbarWithoutGradient alloc] initWithFrame:frame];
    self.editorToolbar.delegate = self;
    
    [super viewDidLoad];
    
    UIColor *color = [UIColor UIColorFromHex:0x222222];
    self.writeButton.tintColor = color;
    self.settingsButton.tintColor = color;
    self.previewButton.tintColor = color;
    self.attachmentButton.tintColor = color;
    self.photoButton.tintColor = color;
    self.movieButton.tintColor = color;

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
        CGFloat y = CGRectGetMaxY(self.titleTextField.frame);
        CGFloat height = self.toolbar.frame.origin.y - y;
        if ((self.interfaceOrientation == UIDeviceOrientationLandscapeLeft)
            || (self.interfaceOrientation == UIDeviceOrientationLandscapeRight)) // Landscape
            return CGRectMake(0, y, self.view.bounds.size.width, height);
        else // Portrait
            return CGRectMake(0, y, self.view.bounds.size.width, height);
    } else {
        CGFloat y = CGRectGetMaxY(self.titleTextField.frame);
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
        UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:buttonTitle style:UIBarButtonItemStylePlain target:self action:@selector(saveAction:)];
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
    } else {
        self.textViewPlaceHolderField.hidden = YES;
        if ((self.apost.mt_text_more != nil) && ([self.apost.mt_text_more length] > 0)) {
			self.textView.text = [NSString stringWithFormat:@"%@\n<!--more-->\n%@", self.apost.content, self.apost.mt_text_more];
		} else {
			self.textView.text = self.apost.content;
        }
    }
    
	// workaround for odd text view behavior on iPad
	[self.textView setContentOffset:CGPointZero animated:NO];

    [self refreshButtons];
}

// TODO :: Update for rich text editing
- (void)autosaveContent {
    self.apost.postTitle = self.titleTextField.text;
    self.navigationItem.title = [self editorTitle];
    // TODO :: This should convert the rich text into HTML
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
            
            NSMutableAttributedString *oldText = [self.textView.attributedText mutableCopy];
            NSRange oldRange = self.textView.selectedRange;
            [oldText replaceCharactersInRange:range withString:aTagText];
            self.textView.attributedText = oldText;
            
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
	
	if(!self.textView.text.length > 0) {
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
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    UIImage *image = [UIImage imageWithData:media.thumbnail];
    attachment.image = image;
    
    NSTextStorage *text = self.textView.textStorage;
    [text beginEditing];
    
    NSMutableAttributedString *attachmentString = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
    [attachmentString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    style.alignment = NSTextAlignmentCenter;
    [attachmentString addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, 1)];
    
    [text insertAttributedString:attachmentString atIndex:0];

    [text endEditing];
    self.hasChangesToAutosave = YES;
//    [self refreshUIForCurrentPost];
    [self.apost autosave];
    [self incrementCharactersChangedForAutosaveBy:2];
    
}

// TODO :: Update for rich text editing
- (void)insertMediaBelow:(NSNotification *)notification {
    [WPMobileStats trackEventForWPCom:[self formattedStatEventString:StatsEventPostDetailAddedPhoto]];
    
	Media *media = (Media *)[notification object];
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    UIImage *image = [UIImage imageWithData:media.thumbnail];
    attachment.image = image;
    
    NSTextStorage *text = self.textView.textStorage;
    [text beginEditing];
    
    NSMutableAttributedString *attachmentString = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
    [attachmentString insertAttributedString:[[NSAttributedString alloc] initWithString:@"\n"] atIndex:0];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    style.alignment = NSTextAlignmentCenter;
    [attachmentString addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(1, 1)];

    [text appendAttributedString:attachmentString];
    
    [text endEditing];

    self.hasChangesToAutosave = YES;
//    [self refreshUIForCurrentPost];
    [self.apost autosave];
    [self incrementCharactersChangedForAutosaveBy:2];
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
- (void)restoreText:(NSAttributedString *)text withRange:(NSRange)range {
    NSLog(@"restoreText:%@",text);
    NSAttributedString *oldText = self.textView.attributedText;
    NSRange oldRange = self.textView.selectedRange;
    self.textView.scrollEnabled = NO;
    // iOS6 seems to have a bug where setting the text like so : textView.text = text;
    // will cause an infinate loop of undos.  A work around is to perform the selector
    // on the main thread.
    // textView.text = text;
    [self.textView performSelectorOnMainThread:@selector(setAttributedText:) withObject:text waitUntilDone:NO];
    self.textView.scrollEnabled = YES;
    self.textView.selectedRange = range;
    [[self.textView.undoManager prepareWithInvocationTarget:self] restoreText:oldText withRange:oldRange];
    self.hasChangesToAutosave = YES;
    [self autosaveContent];
    [self incrementCharactersChangedForAutosaveBy:MAX(text.length, range.length)];
}

// TODO :: Update for rich text editing
- (void)wrapSelectionWithTag:(NSString *)tag {
    // TODO - Determine if text field is empty or selection/cursor is at the end of the text
    
    NSTextStorage *text = self.textView.textStorage;
    
    NSRange range = self.textView.selectedRange;
    NSUInteger length = text.length;
    NSUInteger index = range.location;
    
    UIFont *existingFont = nil;
    NSNumber *strikeThrough = @0;
    NSParagraphStyle *paragraphStyle = [NSParagraphStyle defaultParagraphStyle];
    
    if (length == 0) {
        existingFont = self.textView.font;
    } else {
        existingFont = [text attribute:NSFontAttributeName atIndex:range.location effectiveRange:nil];
        strikeThrough = [text attribute:NSStrikethroughStyleAttributeName atIndex:range.location effectiveRange:nil] ?: @0;
        paragraphStyle = [text attribute:NSParagraphStyleAttributeName atIndex:range.location effectiveRange:nil] ?: [NSParagraphStyle defaultParagraphStyle];
    }
    
    UIFontDescriptor *fd = [existingFont fontDescriptor];
    
    UIFontDescriptorSymbolicTraits traits = 0;
    //    if ([tag isEqualToString:@"ul"] || [tag isEqualToString:@"ol"]) {
    //        prefix = [NSString stringWithFormat:@"<%@>\n", tag];
    //        suffix = [NSString stringWithFormat:@"\n</%@>\n", tag];
    //    } else if ([tag isEqualToString:@"li"]) {
    //        prefix = [NSString stringWithFormat:@"\t<%@>", tag];
    //        suffix = [NSString stringWithFormat:@"</%@>\n", tag];
    //    } else if ([tag isEqualToString:@"more"]) {
    //        prefix = @"<!--more-->";
    //        suffix = @"\n";
    
    if ([tag isEqualToString:@"strong"]) {
        traits = UIFontDescriptorTraitBold;
    } else if ([tag isEqualToString:@"em"]) {
        traits = UIFontDescriptorTraitItalic;
    } else if ([tag isEqualToString:@"del"]) {
        if (strikeThrough.intValue == 0) {
            strikeThrough = @1;
        } else {
            strikeThrough = @0;
        }
    } else if ([tag isEqualToString:@"blockquote"]) {
        NSMutableParagraphStyle *newStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
        
        if (paragraphStyle.headIndent == 0.0) {
            newStyle.headIndent = 20.0;
            newStyle.firstLineHeadIndent = 20.0;
        } else {
            newStyle.headIndent = 0.0;
            newStyle.firstLineHeadIndent = 0.0;
        }
        
        paragraphStyle = newStyle;
    } else if ([tag isEqualToString:@"ol"]) {
        
    } else if ([tag isEqualToString:@"li"]) {
        
    }
    
    self.textView.scrollEnabled = NO;
    
    [text beginEditing];
    
    UIFontDescriptorSymbolicTraits newTraits = fd.symbolicTraits ^ traits;
    UIFontDescriptor *newFd = [fd fontDescriptorWithSymbolicTraits:newTraits];
    UIFont *newFont = [UIFont fontWithDescriptor:newFd size:0.0];
    [text addAttribute:NSFontAttributeName value:newFont range:range];
    [text addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
    [text addAttribute:NSStrikethroughStyleAttributeName value:strikeThrough range:range];
    
    [text endEditing];
    
    self.textView.scrollEnabled = YES;
    
    self.hasChangesToAutosave = YES;
    [self autosaveContent];
    //    [self incrementCharactersChangedForAutosaveBy:MAX(replacement.length, originalRange.length)];
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
        NSAttributedString *oldText = self.textView.attributedText;
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
