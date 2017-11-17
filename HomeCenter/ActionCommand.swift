//
//  ActionCommand.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/14/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class ActionCommand: NSManagedObject {
    
    // MARK: - Initializer
    
    class func findOrCreateCommand(matching commandData: [String: Any], in context: NSManagedObjectContext) throws -> ActionCommand? {
        guard let paramID = commandData[JsonKeys.paramID] as? String, let paramValue = commandData[JsonKeys.value] as? String else {
            print("Couldn't get paramId and paramValue")
            return nil
        }
        var command: ActionCommand?
        do {
            if let param = try Parameter.findParameter(for: paramID, in: context)  {
                command = ActionCommand(context: context)
                command!.paramID = paramID
                command!.paramValue = paramValue
                command!.parameter = param
            }
        } catch {
            print("Error find param: \(error)")
            throw error
        }
        return command
    }
    
    // MARK: - Utility Methods
    
    func convertToDict() -> [String: Any] {
        let dict: [String: Any] = [
            JsonKeys.paramID: self.paramID ?? "",
            JsonKeys.value: self.paramValue ?? ""
        ]
        
        return dict
    }
    
    private struct JsonKeys {
        static let paramID = "paramID"
        static let value = "paramValue"
    }
}
