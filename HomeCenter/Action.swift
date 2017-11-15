//
//  Action.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/14/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class Action: NSManagedObject {

    // MARK: - Initializer
    
    class func findOrCreateAction(matching actionData: [String: Any], in context: NSManagedObjectContext) throws -> Action? {
        guard let uuid = actionData[JsonKeys.uuid] as? String else {
            return nil
        }
        let request: NSFetchRequest<Action> = Action.fetchRequest()
        request.predicate = NSPredicate(format: "uuid = %@", uuid)
        var action: Action
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Action.findOrCreateRoom - database inconsistency")
                action = matches[0]
            } else {
                print("Creating new action")
                action = Action(context: context)
                action.uuid = uuid
            }
        } catch {
            print("Error fetching action in fonorcreateaction \(error)")
            throw error
        }
        //Write or updated values
        action.updateValues(with: actionData)
        return action
    }
    
    // MARK: - Sync Methods
    
    class func syncActions(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        HomeFetcher.fetchActions { (actionsData, error) in
            if let error = error {
                completionHandler(error)
                return
            } else if let actionsArray = actionsData {
                context.perform {
                    updateDatabase(with: actionsArray, in: context)
                    do {
                        try context.save()
                        print("Saved context")
                        completionHandler(nil)
                    } catch {
                        print("Error saving context")
                        completionHandler(error)
                    }
                }
            }
        }
    }
    
    private class func updateDatabase(with actionsArray: [Any], in context: NSManagedObjectContext) {
        var uuids: [String] = []
        for actionDict in actionsArray {
            if let actionData = actionDict as? [String: Any] {
                if let action = try? Action.findOrCreateAction(matching: actionData, in: context), let uuid = action?.uuid {
                    uuids.append(uuid)
                }
            }
        }
        //delete actions missing from API
        let request: NSFetchRequest<Action> = Action.fetchRequest()
        if let matches = try? context.fetch(request) {
            for action in matches {
                if let uuid = action.uuid, !uuids.contains(uuid) {
                    print("Action not in API results, deleting.")
                    context.delete(action)
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func updateValues(with actionData: [String: Any]) {
        if uuid == nil {
            uuid = actionData[JsonKeys.uuid] as? String
        }
        name = actionData[JsonKeys.name] as? String
        if let dateString = actionData[JsonKeys.updated] as? String {
            let formatter = ISO8601DateFormatter()
            updated_at = formatter.date(from: dateString)
        }
        if let commandsData = actionData[JsonKeys.commands] as? [Any] {
            addCommands(with: commandsData)
        }
    }
    
    func addCommands(with actionCommands: [Any]) {
        if let context = self.managedObjectContext {
            //Delete existing commands to refresh
            if let actionCommands = commands {
                for command in actionCommands {
                    if let command = command as? ActionCommand {
                        context.delete(command)
                    }
                }
            }
            //Recreate new commands
            for actionCommand in actionCommands {
                if let commandDict = actionCommand as? [String: Any] {
                    do {
                        if let command = try ActionCommand.findOrCreateCommand(matching: commandDict, in: context) {
                            addToCommands(command)
                        }
                    } catch {
                        print("Error creating action command: \(error)")
                    }
                }
            }
        }
    }
    
    private struct JsonKeys {
        static let name = "actionName"
        static let uuid = "uuid"
        static let updated = "updated_at"
        static let commands = "actionCommands"
    }
}
