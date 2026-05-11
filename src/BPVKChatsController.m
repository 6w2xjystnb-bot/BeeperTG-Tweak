//
//  BPVKChatsController.m
//  BeeperTG
//

#import "BPVKChatsController.h"
#import "BPConstants.h"
#import "BPVKBridge.h"

// Simple cell identifier
static NSString * const kChatCellId = @"BPVKChatCell";

@interface BPVKChatCell : UITableViewCell
@end
@implementation BPVKChatCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
}
@end

@interface BPVKChatsController ()
@property (nonatomic, strong) NSArray *conversations; // Array of VK conversation dicts
@property (nonatomic, strong) UIRefreshControl *rc;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation BPVKChatsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"VK Messages";
    self.conversations = @[];

    // Table setup
    [self.tableView registerClass:[BPVKChatCell class] forCellReuseIdentifier:kChatCellId];

    // Refresh control
    self.rc = [[UIRefreshControl alloc] init];
    [self.rc addTarget:self action:@selector(loadConversations) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = self.rc;

    // Spinner for first load
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];

    // Auth button if no token
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Auth"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(showAuth)];

    // Listen for real-time updates from Long Poll
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNewMessage:)
                                                 name:@"BeeperTG.VKNewMessage"
                                               object:nil];

    // Initial load
    if ([[BPVKBridge sharedInstance] accessToken].length > 0) {
        [self loadConversations];
    } else {
        [self showAuthAlert];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Auth

- (void)showAuth {
    // In a real tweak you open SFSafariViewController or a WKWebView.
    // Here we print the OAuth URL to the console so you can grab the token.
    NSURL *url = [[BPVKBridge sharedInstance] oauthURL];
    NSLog(@"[BeeperTG] Open this URL in Safari to get token: %@", url.absoluteString);

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"VK Auth"
                                                                   message:@"Copy the OAuth URL from the console and open it in Safari. After auth, paste the access_token into NSUserDefaults key 'BeeperTG_VKToken'."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAuthAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"VK Not Connected"
                                                                   message:@"Tap Auth to link your VK account."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Auth" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showAuth];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
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
    // Refresh the list when a new message arrives via Long Poll
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

    // Title
    NSString *title = chat[@"title"];
    if (!title) {
        NSInteger peerId = [peer[@"id"] integerValue];
        title = [NSString stringWithFormat:@"User %ld", (long)peerId];
    }
    cell.textLabel.text = title;

    // Last message preview
    NSString *text = lastMsg[@"text"] ?: @"...";
    cell.detailTextLabel.text = text;
    cell.detailTextLabel.textColor = [UIColor grayColor];

    // Unread badge (simple accessory)
    NSInteger unread = [conv[@"conversation"][@"unread_count"] integerValue];
    if (unread > 0) {
        cell.accessoryType = UITableViewCellAccessoryDetailButton;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *conv = self.conversations[indexPath.row];
    NSInteger peerId = [conv[@"conversation"][@"peer"][@"id"] integerValue];
    NSString *title  = conv[@"conversation"][@"chat_settings"][@"title"] ?: [NSString stringWithFormat:@"%ld", (long)peerId];

    // Open a detail chat view (placeholder)
    UIViewController *detail = [[UIViewController alloc] init];
    detail.title = title;
    detail.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 40)];
    label.text = [NSString stringWithFormat:@"VK Chat %ld\n(Detail UI not yet implemented)", (long)peerId];
    label.numberOfLines = 0;
    [detail.view addSubview:label];

    [self.navigationController pushViewController:detail animated:YES];
}

@end
