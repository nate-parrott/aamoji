//
//  Utilities.swift
//  aamoji
//
//  Created by Nate Parrott on 5/19/15.
//  Copyright (c) 2015 Nate Parrott. All rights reserved.
//

import AppKit

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

extension NSWorkspace {
    func terminateApp(bundleID: String) -> Bool {
        for app in runningApplications as! [NSRunningApplication] {
            if let appBundleID = app.bundleIdentifier {
                if appBundleID.lowercaseString == bundleID.lowercaseString {
                    return app.terminate()
                }
            }
        }
        return false
    }
}

extension String {
    func containsOnlyCharactersFromSet(set: NSCharacterSet) -> Bool {
        return componentsSeparatedByCharactersInSet(set.invertedSet).count == 1
    }
}
