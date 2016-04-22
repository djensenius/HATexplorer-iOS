//
//  AppDelegate.swift
//  HATexplorer
//
//  Created by David Jensenius on 2015-07-22.
//  Copyright (c) 2015 David Jensenius. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    //var audioController: PdAudioController?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
        splitViewController.delegate = self
        /*
        audioController = PdAudioController()
        if let c = audioController {
            //let s = PdAudioController_Bridging().configurePlaybackWithSampleRate(44100, numberChannels: 2, inputEnabled: true, mixingEnabled: true, audioController: c)
            let s = PdAudioController_Bridging().configureAmbientWithSampleRate(44100, numberChannels: 2, mixingEnabled: true, audioController: c)
            switch s {
            case .OK:
                print("success")
                break //success
            case .Error:
                print("unrecoverable error: failed to initialize audio components")
            case .PropertyChanged:
                print("some properties have changed to run correctly (not fatal)")
            }
        } else {
            print("could not get PdAudioController")
        }
 */
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, LockNotifierCallback.notifierProc(), "com.apple.springboard.lockcomplete", nil, CFNotificationSuspensionBehavior.DeliverImmediately)
        
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        //audioController?.active = false
        print("Will resign active?")
        let userDefaults = NSUserDefaults.standardUserDefaults()
        if let fromLock: AnyObject = userDefaults.objectForKey("kDisplayStatusLocked") {
            print("From locked is \(fromLock)")
            if userDefaults.objectForKey("kDisplayStatusLocked") as! Bool == true {
                print("Locked screen!")
            } else {
                print("Home button pressed?")
                NSNotificationCenter.defaultCenter().postNotificationName("stopEverything", object: nil)
            }
        }
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        //audioController?.active = true
        print("Coming back to life!")
        let userDefaults = NSUserDefaults.standardUserDefaults()
        if let fromLock: AnyObject = userDefaults.objectForKey("kDisplayStatusLocked") {
            if fromLock as! Bool == true {
                userDefaults.setObject(false, forKey: "kDisplayStatusLocked")
                print("...from a locked screen!")
            } else {
                NSNotificationCenter.defaultCenter().postNotificationName("restartEverything", object: nil)
            }
        }
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: - Split view

    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController:UIViewController, ontoPrimaryViewController primaryViewController:UIViewController) -> Bool {
        if let secondaryAsNavController = secondaryViewController as? UINavigationController {
            if let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController {
                if topAsDetailController.detailItem == nil {
                    // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
                    return true
                }
            }
        }
        return false
    }

}

