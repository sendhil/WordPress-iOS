//
//  EditPostViewController_Internal.h
//  WordPress
//
//  Created by Jorge Bernal on 1/24/13.
//  Copyright (c) 2013 WordPress. All rights reserved.
//

#import "EditPostViewController.h"
#import "PostSettingsViewController.h"
#import "PostMediaViewController.h"
#import "PostPreviewViewController.h"
#import "Post.h"

extern NSString *const EditPostViewControllerDidAutosaveNotification;
extern NSString *const EditPostViewControllerAutosaveDidFailNotification;

typedef NS_ENUM(NSInteger, EditPostViewControllerAlertTag) {
    EditPostViewControllerAlertTagNone,
    EditPostViewControllerAlertTagLinkHelper,
    EditPostViewControllerAlertTagFailedMedia,
};

@interface EditPostViewController ()

@property (nonatomic, strong) PostSettingsViewController *postSettingsViewController;
@property (nonatomic, strong) PostMediaViewController *postMediaViewController;
@property (nonatomic, strong) PostPreviewViewController *postPreviewViewController;
@property (nonatomic, assign) EditPostViewControllerMode editMode;
@property (nonatomic, strong) AbstractPost *apost;
@property (readonly) BOOL hasChanges;
@property (readonly) Post *post;
@property (nonatomic, strong) WPKeyboardToolbarBase *editorToolbar;

@property (nonatomic, strong) UITextField *infoText;
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, assign) BOOL isAutosaved;
@property (nonatomic, assign) BOOL isAutosaving;
@property (nonatomic, assign) BOOL hasChangesToAutosave;
@property (nonatomic, assign) BOOL isEditing;
@property (nonatomic, assign) BOOL isShowingKeyboard;
@property (nonatomic, assign) BOOL isExternalKeyboard;
@property (nonatomic, assign) BOOL isNewCategory;
@property (nonatomic, assign) BOOL isShowingLinkAlert;


@property (nonatomic, weak) IBOutlet UIButton *hasLocation;
@property (nonatomic, weak) IBOutlet UIToolbar *toolbar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *photoButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *movieButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *settingsButton;
@property (nonatomic, weak) IBOutlet UITextField *titleTextField;
@property (nonatomic, weak) IBOutlet UITextView *textView;
@property (nonatomic, weak) IBOutlet UITextField *tagsTextField;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UITextField *textViewPlaceHolderField;
@property (nonatomic, weak) IBOutlet UIView *contentView;
@property (nonatomic, weak) IBOutlet UIView *editView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *writeButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *previewButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *attachmentButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *createCategoryBarButtonItem;
@property (nonatomic, weak) IBOutlet UIImageView *tabPointer;
@property (nonatomic, weak) IBOutlet UILabel *tagsLabel;
@property (nonatomic, weak) IBOutlet UILabel *categoriesLabel;
@property (nonatomic, weak) IBOutlet UIButton *categoriesButton;
@property (nonatomic, strong) UIAlertView *failedMediaAlertView;
@property (nonatomic, strong) UIAlertView *linkHelperAlertView;



- (BOOL)autosaveRemoteWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure;
- (void)refreshButtons;
- (IBAction)switchToEdit;
- (IBAction)switchToSettings;
- (IBAction)switchToMedia;
- (IBAction)switchToPreview;
- (CGRect)normalTextFrame;

- (NSString *)editorTitle;
- (void)savePost:(BOOL)upload;
- (BOOL)autosaveRemote;
- (BOOL)autosaveRemoteWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure;
- (NSString *)validateNewLinkInfo:(NSString *)urlText;
- (void)incrementCharactersChangedForAutosaveBy:(NSUInteger)change;
- (NSString *)formattedStatEventString:(NSString *)event;
- (void)logWPKeyboardToolbarButtonStat:(WPKeyboardToolbarButtonItem *)buttonItem;
- (void)showLinkView;
- (CGRect)normalTextFrame;
- (void)autosaveContent;

@end
