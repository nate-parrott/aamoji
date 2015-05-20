//
//  AamojiInserter+HTML.swift
//  aamoji
//
//  Created by Nate Parrott on 5/19/15.
//  Copyright (c) 2015 Nate Parrott. All rights reserved.
//

import Foundation

extension AamojiInserter {
    func shortcutListHTML() -> String {
        let template = NSString(contentsOfFile: NSBundle.mainBundle().pathForResource("ShortcutListTemplate", ofType: "html")!, encoding: NSUTF8StringEncoding, error: nil)!
        
        var shortcutsForEmoji = [String: [String]]()
        for entry in aamojiEntries() {
            let emoji = entry[ReplacementReplaceWithKey] as! String
            let shortcut = entry[ReplacementShortcutKey] as! String
            shortcutsForEmoji[emoji] = (shortcutsForEmoji[emoji] ?? []) + [shortcut]
        }
        
        var html = ""
        for (emoji, shortcuts) in shortcutsForEmoji {
            let allShortcuts = ", ".join(shortcuts)
            html += "<li><span class='emoji'>\(emoji)</span> \(allShortcuts)</li>\n"
        }
        
        return template.stringByReplacingOccurrencesOfString("<!--SHORTCUTS-->", withString: html)
    }
}
