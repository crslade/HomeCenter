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
                assert(matches.count == 1, "Action.findOrCreateCondition - database inconsistency")
                action = matches[0]
            } else {
                print("Creating new action")
                action = Action(context: context)
                action.uuid = uuid
            }
        } catch {
            print("Error fetching action in findorcreateaction \(error)")
            throw error
        }
        //Write or updated values
        action.updateValues(with: actionData)
        return action
    }
    
    class func findAction(for uuid: String, in context: NSManagedObjectContext) throws -> Action? {
        let request: NSFetchRequest<Action> = Action.fetchRequest()
        request.predicate = NSPredicate(format: "uuid = %@", uuid)
        
        var action: Action?
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Action.findAction - database inconsistency")
                action = matches[0]
            }
        } catch {
            print("Error fetching parameter: \(error)")
            throw error
        }
        
        return action
    }
    
    // MARK: - Data
    
    //Can set this with Json Data when creating. If set, when converting to Json, this will be used instead of the commands array
    var jsonCommands: [Any]?
    
    // MARK: - Sync Methods
    
    class func syncActions(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        // TODO: Sync Devices first??
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
    
    func saveToAPI(with completionHandler: @escaping (Error?) -> Void) {
        do {
            if let actionID = uuid, let deviceData = try convertToJson() {
                print("Should update action: \(actionID)")
                HomeFetcher.editAction(with: actionID, actionData: deviceData) { (retData, error) in
                    if let error = error {
                        completionHandler(error)
                    } else if let _ = retData {
                        print("Updated Succeeded")
                        completionHandler(nil)
                    }
                }
                completionHandler(nil)
            } else if let actionJson = try convertToJson() {
                print(actionJson)
                HomeFetcher.addAction(actionJson) {[weak self] (actionData, error) in
                    if let error = error {
                        completionHandler(error)
                    } else if let actionDict = actionData {
                        self?.managedObjectContext?.perform {
                            self?.updateValues(with: actionDict)
                        }
                        completionHandler(nil)
                    } else {
                        print("No error or data in Action - savetoapi?? new")
                        completionHandler(HomeFetcherError.DownloadError("No Data"))
                    }
                }
            }
        } catch {
            print("Error converting to Json: \(error)")
            completionHandler(error)
        }
    }
    
    func fire(with completionHandler: @escaping (Error?) -> Void) {
        if let actionID = uuid {
            HomeFetcher.fireAction(withUUID: actionID, with: completionHandler)
        } else {
            completionHandler(HomeFetcherError.MissingAPIValues("No UUID for action"))
        }
    }
    
    func delete(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        if let uuid = self.uuid {
            HomeFetcher.deleteAction(withUUID: uuid) { (error) in
                if let error = error {
                    completionHandler(error)
                } else {
                    context.perform {
                        context.delete(self)
                        do {
                            try context.save()
                            completionHandler(nil)
                        } catch {
                            print("Error Saving Context")
                            completionHandler(error)
                        }
                    }
                }
            }
        } else {
            completionHandler(HomeFetcherError.MissingAPIValues("No uuid to delete."))
        }
    }
    
    // MARK: - Utility Methods
    
    func applyJson(with actionData: [String: Any]) {
        self.name = actionData[JsonKeys.name] as? String
        self.jsonCommands = actionData[JsonKeys.commands] as? [Any]
    }
    
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
    
    private func convertToJson() throws -> String? {
        var commandArray: [Any] = []
        if let jsonCommands = jsonCommands {
            print("here")
            commandArray = jsonCommands
        } else if let commands = commands {
            for command in commands {
                if let command = command as? ActionCommand {
                    commandArray.append(command.convertToDict())
                }
            }
        }
        let actionDict: [String: Any] = [
            JsonKeys.name: self.name ?? "",
            JsonKeys.commands: commandArray
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: actionDict, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8)
    }
    
    private struct JsonKeys {
        static let name = "actionName"
        static let uuid = "uuid"
        static let updated = "updated_at"
        static let commands = "actionCommands"
    }
}
