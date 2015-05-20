//
//  AamojiInserter.swift
//  aamoji
//
//  Created by Nate Parrott on 5/19/15.
//  Copyright (c) 2015 Nate Parrott. All rights reserved.
//

import Cocoa
import SQLite

let ReplacementsKey = "NSUserDictionaryReplacementItems"
let ReplacementOnKey = "on"
let ReplacementShortcutKey = "replace"
let ReplacementReplaceWithKey = "with"

class AamojiInserter: NSObject {
    
    var inserted: Bool? {
        get {
            if let replacements = _defaults.arrayForKey(ReplacementsKey) as? [[NSObject: NSObject]] {
                for replacement in replacements {
                    if let shortcut = replacement[ReplacementShortcutKey] as? String {
                        if _allShortcuts.contains(shortcut) {
                            return true
                        }
                    }
                }
                return false
            } else {
                return nil
            }
        }
        set(insertOpt) {
            if let insert = insertOpt {
                if let replacements = _defaults.arrayForKey(ReplacementsKey) as? [[NSObject: NSObject]] {
                    if insert {
                        _insertReplacements()
                    } else {
                        _deleteReplacements()
                    }
                    /*let withoutAamoji = replacements.filter({ !self._replacementBelongsToAamoji($0) })
                    let newReplacements: [[NSObject: NSObject]] = insert ? (withoutAamoji + aamojiEntries()) : withoutAamoji
                    var globalDomain = _defaults.persistentDomainForName(NSGlobalDomain)!
                    globalDomain[ReplacementsKey] = newReplacements
                    _defaults.setPersistentDomain(globalDomain, forName: NSGlobalDomain)
                    _defaults.synchronize()*/
                }
            }
        }
    }
    
    private func _insertReplacements() {
        // make the change in sqlite:
        let db = Database(_pathForDatabase())
        var pk = db.scalar("SELECT max(Z_PK) FROM 'ZUSERDICTIONARYENTRY'") as? Int ?? 0
        let timestamp = Int64(NSDate().timeIntervalSince1970)
        for entry in aamojiEntries() {
            // key, timestamp, with, replace
            let replace = entry[ReplacementShortcutKey] as! String
            let with = entry[ReplacementReplaceWithKey] as! String
            db.run("INSERT INTO 'ZUSERDICTIONARYENTRY' VALUES(?,1,1,0,0,0,0,?,NULL,NULL,NULL,NULL,NULL,?,?,NULL)", [pk, timestamp, with, replace])
            pk++
        }
        
        // make the change in nsuserdefaults:
        let existingReplacementEntries = _defaults.arrayForKey(ReplacementsKey) as! [[NSObject: NSObject]]
        _setReplacementsInUserDefaults(existingReplacementEntries + aamojiEntries())
    }
    
    private func _deleteReplacements() {
        // make the change in sqlite:
        let db = Database(_pathForDatabase())
        for entry in aamojiEntries() {
            let shortcut = entry[ReplacementShortcutKey] as! String
            db.run("DELETE FROM 'ZUSERDICTIONARYENTRY' WHERE ZSHORTCUT = ?", [shortcut])
        }
        
        // make the change in nsuserdefaults:
        let existingReplacementEntries = _defaults.arrayForKey(ReplacementsKey) as! [[NSObject: NSObject]]
        let withoutAamojiEntries = existingReplacementEntries.filter({ !self._allShortcuts.contains($0[ReplacementShortcutKey] as! String) })
        _setReplacementsInUserDefaults(withoutAamojiEntries)
    }
    
    private func _pathForDatabase() -> String {
        let library = NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true).first as! String
        let container1 = library.stringByAppendingPathComponent("Dictionaries/CoreDataUbiquitySupport")
        let contents = NSFileManager.defaultManager().contentsOfDirectoryAtPath(container1, error: nil) as! [String]
        let userName = NSUserName()
        let matchingDirname = contents.filter({ $0.startsWith(userName) }).first!
        let container2 = container1.stringByAppendingPathComponent(matchingDirname).stringByAppendingPathComponent("UserDictionary")
        // find the active icloud directory first, then fall back to local:
        var subdir = "local"
        for child in NSFileManager.defaultManager().contentsOfDirectoryAtPath(container2, error: nil) as! [String] {
            let containerDir = container2.stringByAppendingPathComponent(child).stringByAppendingPathComponent("container")
            if NSFileManager.defaultManager().fileExistsAtPath(containerDir) {
                subdir = child
            }
        }
        let path = container2.stringByAppendingPathComponent(subdir).stringByAppendingPathComponent("store/UserDictionary.db")
        return path
    }
    
    private func _setReplacementsInUserDefaults(replacements: [[NSObject: NSObject]]) {
        var globalDomain = _defaults.persistentDomainForName(NSGlobalDomain)!
        globalDomain[ReplacementsKey] = replacements
        _defaults.setPersistentDomain(globalDomain, forName: NSGlobalDomain)
        _defaults.synchronize()
    }
    
    private lazy var _allShortcuts: Set<String> = {
        let entries = self.aamojiEntries()
        return Set(entries.map({ $0[ReplacementShortcutKey] as! String }))
    }()
    
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
            return [ReplacementOnKey: 1, ReplacementShortcutKey: "aa" + shortcut, ReplacementReplaceWithKey: emoji]
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
}
