//
//  AamojiInserter.swift
//  aamoji
//
//  Created by Nate Parrott on 5/19/15.
//  Copyright (c) 2015 Nate Parrott. All rights reserved.
//

import Cocoa

let ReplacementsKey = "NSUserDictionaryReplacementItems"
let ReplacementOnKey = "on"
let ReplacementShortcutKey = "replace"
let ReplacementReplaceWithKey = "with"
let ReplacementAamojiMarker = "_aamoji"

class AamojiInserter: NSObject {
    
    var inserted: Bool? {
        get {
            if let replacements = _defaults.arrayForKey(ReplacementsKey) as? [[NSObject: NSObject]] {
                return replacements.filter({ self._replacementBelongsToAamoji($0) }).count > 0
            } else {
                return nil
            }
        }
        set(insertOpt) {
            if let insert = insertOpt {
                if let replacements = _defaults.arrayForKey(ReplacementsKey) as? [[NSObject: NSObject]] {
                    let withoutAamoji = replacements.filter({ !self._replacementBelongsToAamoji($0) })
                    let newReplacements: [[NSObject: NSObject]] = insert ? (withoutAamoji + aamojiEntries()) : withoutAamoji
                    var globalDomain = _defaults.persistentDomainForName(NSGlobalDomain)!
                    globalDomain[ReplacementsKey] = newReplacements
                    _defaults.setPersistentDomain(globalDomain, forName: NSGlobalDomain)
                    _defaults.synchronize()
                }
            }
        }
    }
    
    func aamojiEntries() -> [[NSObject: NSObject]] {
        let emojiInfoJson = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("emoji", ofType: "json")!)!
        let emojiInfo = NSJSONSerialization.JSONObjectWithData(emojiInfoJson, options: nil, error: nil) as! [[String: AnyObject]]
        
        var emojiByShortcut = [String: String]()
        var emojiShortcutPrecendences = [String: Double]()
        
        for emojiDict in emojiInfo {
            if let emoji = emojiDict["emoji"] as? String {
                for (shortcutUnprocessed, precedence) in _shortcutsAndPrecedencesForEmojiInfoEntry(emojiDict) {
                    if let shortcut = _processShortcutIfAllowed(shortcutUnprocessed) {
                        let existingPrecedence = emojiShortcutPrecendences[shortcut] ?? 0
                        if precedence > existingPrecedence {
                            emojiByShortcut[shortcut] = emoji
                            emojiShortcutPrecendences[shortcut] = precedence
                        }
                    }
                }
            }
        }
        
        let entries = Array(emojiByShortcut.keys).map() {
            (shortcut) -> [NSObject: NSObject] in
            let emoji = emojiByShortcut[shortcut]!
            return [ReplacementOnKey: 1, ReplacementShortcutKey: "aa" + shortcut, ReplacementReplaceWithKey: emoji, ReplacementAamojiMarker: true]
        }
        
        return entries
    }
    
    private func _shortcutsAndPrecedencesForEmojiInfoEntry(entry: [String: AnyObject]) -> [(String, Double)] {
        var results = [(String, Double)]()
        if let aliases = entry["aliases"] as? [String] {
            for alias in aliases {
                results.append((alias, 3))
            }
        }
        if let description = entry["description"] as? String {
            let words = description.componentsSeparatedByString(" ")
            if let firstWord = words.first {
                results.append((firstWord, 2))
            }
            for word in words {
                results.append((word, 1))
            }
        }
        if let tags = entry["tags"] as? [String] {
            for tag in tags {
                results.append((tag, 1.5))
            }
        }
        return results
    }
    
    private var _allowedCharsInShortcutStrings = NSCharacterSet(charactersInString: "abcdefghijklmnopqrstuvwxyz0123456789_:")
    private func _processShortcutIfAllowed(var shortcut: String) -> String? {
        shortcut = shortcut.lowercaseString
        if shortcut.containsOnlyCharactersFromSet(_allowedCharsInShortcutStrings) {
            return shortcut
        } else {
            return nil
        }
    }
    
    private var _defaults = NSUserDefaults()
    
    private func _replacementBelongsToAamoji(replacement: [NSObject: NSObject]) -> Bool {
        return (replacement[ReplacementAamojiMarker] as? Bool) ?? false
    }
}
