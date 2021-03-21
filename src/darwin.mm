#ifdef __APPLE__
#import "platform.h"

#include <AppKit/AppKit.h>
#include <iostream>
#include <string>
#include <vector>
#include <functional>

std::string getCwd () {
  NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
  auto str = std::string([bundlePath UTF8String]);
  return str;
}

std::vector<std::string> getMenuItemDetails (void* item) {
  id menuItem = (id) item;
  std::string id = std::to_string([menuItem tag]);
  std::string title = [[menuItem title] UTF8String];
  std::string state = [menuItem state] == NSControlStateValueOn ? "true" : "false";
  std::vector<std::string> vec = { id, title, state };
  return vec;
}

bool createContextMenu (std::string seq, std::string value) {
  auto opts = split(value, ';');

  NSPoint mouseLocation = [NSEvent mouseLocation];
  NSMenu *pMenu = [[NSMenu alloc] initWithTitle:@"Context Menu"];
  [pMenu insertItemWithTitle:@"Beep" action:@selector(menuItemSelected:) keyEquivalent:@"" atIndex:0];
  [pMenu insertItemWithTitle:@"Honk" action:@selector(menuItemSelected:) keyEquivalent:@"" atIndex:1];
  [pMenu popUpMenuPositioningItem:pMenu.itemArray[0] atLocation:NSPointFromCGPoint(CGPointMake(mouseLocation.x, mouseLocation.y)) inView:nil];
  return true;
}

void createMenu (std::string menu) {
  NSString *title;
  NSMenu *appleMenu;
  NSMenu *serviceMenu;
  NSMenu *windowMenu;
  NSMenu *editMenu;
  NSMenu *dynamicMenu;
  NSMenuItem *menuItem;
  NSMenu *mainMenu;

  if (NSApp == nil) {
    return;
  }

  mainMenu = [[NSMenu alloc] init];

  // Create the main menu bar
  [NSApp setMainMenu:mainMenu];

  [mainMenu release];  // we're done with it, let NSApp own it.
  mainMenu = nil;

  // Create the application menu

  id appName = [[NSProcessInfo processInfo] processName];
  appleMenu = [[NSMenu alloc] initWithTitle:@""];

  // Add menu items
  title = [@"About " stringByAppendingString:appName];
  [appleMenu addItemWithTitle:title action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];

  [appleMenu addItem:[NSMenuItem separatorItem]];

  [appleMenu addItemWithTitle:@"Preferences…" action:nil keyEquivalent:@","];

  [appleMenu addItem:[NSMenuItem separatorItem]];

  serviceMenu = [[NSMenu alloc] initWithTitle:@""];
  menuItem = (NSMenuItem *)[appleMenu addItemWithTitle:@"Services" action:nil keyEquivalent:@""];
  [menuItem setSubmenu:serviceMenu];

  [NSApp setServicesMenu:serviceMenu];
  [serviceMenu release];

  [appleMenu addItem:[NSMenuItem separatorItem]];

  title = [@"Hide " stringByAppendingString:appName];
  [appleMenu addItemWithTitle:title action:@selector(hide:) keyEquivalent:@"h"];

  menuItem = (NSMenuItem *)[appleMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
  [menuItem setKeyEquivalentModifierMask:(NSEventModifierFlagOption|NSEventModifierFlagCommand)];

  [appleMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];

  [appleMenu addItem:[NSMenuItem separatorItem]];

  title = [@"Quit " stringByAppendingString:appName];
  [appleMenu addItemWithTitle:title action:@selector(terminate:) keyEquivalent:@"q"];

  // Put menu into the menubar
  menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  [menuItem setSubmenu:appleMenu];
  [[NSApp mainMenu] addItem:menuItem];
  [menuItem release];

  // Tell the application object that this is now the application menu
  // [NSApp setAppleMenu:appleMenu];
  [appleMenu release];

  // deserialize the menu
  std::replace(menu.begin(), menu.end(), '_', '\n');

  // split on ;
  auto menus = split(menu, ';');

  for (auto m : menus) {
    auto menu = split(m, '\n');
    auto menuTitle = split(trim(menu[0]), ':')[0];
    NSString* nssTitle = [NSString stringWithUTF8String:menuTitle.c_str()];
    dynamicMenu = [[NSMenu alloc] initWithTitle:nssTitle];

    for (int i = 1; i < menu.size(); i++) {
      auto parts = split(trim(menu[i]), ':');
      auto title = parts[0];
      auto pair = split(trim(parts[1]), ' ');
      auto id = std::stoi(pair[0]);
      auto key = pair.size() == 2 ? pair[1] : "";

      NSString* nssTitle = [NSString stringWithUTF8String:title.c_str()];
      NSString* nssKey = [NSString stringWithUTF8String:key.c_str()];
      NSString* nssSelector = [NSString stringWithUTF8String:"menuItemSelected:"];

      if (menuTitle.compare("Edit") == 0) {
        if (title.compare("Cut") == 0) nssSelector = [NSString stringWithUTF8String:"cut:"];
        if (title.compare("Copy") == 0) nssSelector = [NSString stringWithUTF8String:"copy:"];
        if (title.compare("Paste") == 0) nssSelector = [NSString stringWithUTF8String:"paste:"];
        if (title.compare("Delete") == 0) nssSelector = [NSString stringWithUTF8String:"delete:"];
        if (title.compare("Select All") == 0) nssSelector = [NSString stringWithUTF8String:"selectAll:"];
      }

      if (title.compare("Minimize") == 0) nssSelector = [NSString stringWithUTF8String:"performMiniaturize:"];
      if (title.compare("Zoom") == 0) nssSelector = [NSString stringWithUTF8String:"performZoom:"];
      
      menuItem = [dynamicMenu
        addItemWithTitle:nssTitle
        action:NSSelectorFromString(nssSelector)
        keyEquivalent:nssKey
      ];

      [menuItem setTag:id];
    }

    menuItem = [[NSMenuItem alloc] initWithTitle:nssTitle action:nil keyEquivalent:@""];

    [[NSApp mainMenu] addItem:menuItem];
    [menuItem setSubmenu:dynamicMenu];
    [menuItem release];
    [dynamicMenu release];
  }
}

std::string dialog_open(
  int flags,
  const char *filters,
  const char *default_path,
  const char *default_name)
{
  NSURL *url;
  const char *utf8_path;
  NSSavePanel *dialog;
  NSOpenPanel *open_dialog;
  NSURL *default_url;
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  if (flags & NOC_FILE_DIALOG_OPEN) {
    dialog = open_dialog = [NSOpenPanel openPanel];
  } else {
    dialog = [NSSavePanel savePanel];
  }

  if (flags & NOC_FILE_DIALOG_DIR) {
    [open_dialog setCanChooseDirectories:YES];
    [open_dialog setCanCreateDirectories:YES];
    [open_dialog setCanChooseFiles:YES];
    [open_dialog setAllowsMultipleSelection:YES];
  }

  if (default_path) {
    default_url = [NSURL fileURLWithPath: [NSString stringWithUTF8String:default_path]];
    [dialog setDirectoryURL:default_url];
    [dialog setNameFieldStringValue:default_url.lastPathComponent];
  }

  std::string result;
  std::vector<std::string> paths;

  if ([dialog runModal] == NSModalResponseOK) {
    NSArray* urls = [dialog URLs];

    for (NSURL* url in urls) {
      if ([url isFileURL]) {
        paths.push_back(std::string((char*) [[url path] UTF8String]));
      }
    }
  }

  [pool release];

  for (size_t i = 0, i_end = paths.size(); i < i_end; ++i) {
    result += (i ? "," : "");
    result += paths[i]; 
  }

  return result;
}

#endif
