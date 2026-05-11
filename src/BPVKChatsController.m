//
//  BPVKChatsController.m
//  BeeperTG
//

#import "BPVKChatsController.h"
#import "BPConstants.h"
#import "BPVKBridge.h"

static NSString * const kChatCellId = @"BPVKChatCell";

@interface BPVKChatCell : UITableViewCell
@end
@implementation BPVKChatCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
}
@end

@interface BPVKChatsController ()
@property (nonatomic, strong) NSArray *conversations;
@property (nonatomic, strong) UIRefreshControl *rc;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation BPVKChatsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"VK Messages";
    self.conversations = @[];

    [self.tableView registerClass:[BPVKChatCell class] forCellReuseIdentifier:kChatCellId];

    self.rc = [[UIRefreshControl alloc] init];
    [self.rc addTarget:self action:@selector(loadConversations) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = self.rc;

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Auth"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(showAuthSheet)];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNewMessage:)
                                                 name:@"BeeperTG.VKNewMessage"
                                               object:nil];

    if ([[BPVKBridge sharedInstance] accessToken].length > 0) {
        [self loadConversations];
    } else {
        [self showAuthSheet];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Auth Sheet

- (void)showAuthSheet {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"VK Auth (Kate Mobile)"
                                                                   message:@"Enter your VK login & password. Direct auth uses Kate Mobile keys."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Phone or email";
        tf.keyboardType = UIKeyboardTypeEmailAddress;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Password";
        tf.secureTextEntry = YES;
    }];

    UIAlertAction *loginAction = [UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *login = alert.textFields[0].text;
        NSString *pass  = alert.textFields[1].text;
        if (login.length && pass.length) {
            [self runDirectAuth:login password:pass];
        }
    }];
    [alert addAction:loginAction];

    [alert addAction:[UIAlertAction actionWithTitle:@"Browser OAuth" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSURL *url = [[BPVKBridge sharedInstance] browserOAuthURL];
        NSLog(@"[BeeperTG] OAuth URL: %@", url.absoluteString);
        UIAlertController *info = [UIAlertController alertControllerWithTitle:@"OAuth URL"
                                                                      message:@"Open the printed URL in Safari, authorize, then copy the access_token from the redirect and save it to NSUserDefaults (BeeperTG_VKToken)."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [info addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:info animated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)runDirectAuth:(NSString *)login password:(NSString *)pass {
    [self.spinner startAnimating];
    [[BPVKBridge sharedInstance] directAuthWithLogin:login password:pass completion:^(BOOL success, NSError *error) {
        [self.spinner stopAnimating];
        if (success) {
            [[BPVKBridge sharedInstance] startLongPolling];
            [self loadConversations];
        } else {
            NSString *msg = error.localizedDescription ?: @"Unknown error";
            UIAlertController *err = [UIAlertController alertControllerWithTitle:@"Auth Failed"
                                                                         message:msg
                                                                  preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:err animated:YES completion:nil];
        }
    }];
}

#pragma mark - Data

- (void)loadConversations {
    [self.spinner startAnimating];
    [[BPVKBridge sharedInstance] fetchConversationsWithCount:50 completion:^(NSArray *conversations, NSError *error) {
        [self.spinner stopAnimating];
        [self.rc endRefreshing];
        if (error) {
            NSLog(@"[BeeperTG] Failed to fetch conversations: %@", error.localizedDescription);
            return;
        }
        self.conversations = conversations ?: @[];
        [self.tableView reloadData];
    }];
}

- (void)refreshConversations {
    [self loadConversations];
}

- (void)onNewMessage:(NSNotification *)note {
    [self loadConversations];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.conversations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BPVKChatCell *cell = [tableView dequeueReusableCellWithIdentifier:kChatCellId forIndexPath:indexPath];
    NSDictionary *conv = self.conversations[indexPath.row];
    NSDictionary *chat = conv[@"conversation"][@"chat_settings"] ?: @{};
    NSDictionary *peer = conv[@"conversation"][@"peer"] ?: @{};
    NSDictionary *lastMsg = conv[@"last_message"] ?: @{};

    NSString *title = chat[@"title"];
    if (!title) {
        NSInteger peerId = [peer[@"id"] integerValue];
        title = [NSString stringWithFormat:@"User %ld", (long)peerId];
    }
    cell.textLabel.text = title;

    NSString *text = lastMsg[@"text"] ?: @"...";
    cell.detailTextLabel.text = text;
    cell.detailTextLabel.textColor = [UIColor grayColor];

    NSInteger unread = [conv[@"conversation"][@"unread_count"] integerValue];
    cell.accessoryType = unread > 0 ? UITableViewCellAccessoryDetailButton : UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *conv = self.conversations[indexPath.row];
    NSInteger peerId = [conv[@"conversation"][@"peer"][@"id"] integerValue];
    NSString *title  = conv[@"conversation"][@"chat_settings"][@"title"] ?: [NSString stringWithFormat:@"%ld", (long)peerId];

    UIViewController *detail = [[UIViewController alloc] init];
    detail.title = title;
    detail.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 60)];
    label.text = [NSString stringWithFormat:@"VK Chat %ld\n(Detail UI not yet implemented)", (long)peerId];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    [detail.view addSubview:label];

    [self.navigationController pushViewController:detail animated:YES];
}

@end
