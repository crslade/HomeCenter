//
//  Condition.swift
//  HomeCenter
//
//  Created by Christopher Slade on 12/1/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class Condition: NSManagedObject {
    
    //TODO - Sync all actions first??
    
    // MARK: - Initializer
    
    class func findOrCreateCondition(matching conditionData: [String: Any], in context: NSManagedObjectContext) throws -> Condition? {
        guard let uuid = conditionData["uuid"] as? String else {
            return nil
        }
        let request: NSFetchRequest<Condition> = Condition.fetchRequest()
        request.predicate = NSPredicate(format: "uuid = %@", uuid)
        var condition: Condition
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Condition.findOrCreateCondition - database inconsistency")
                condition = matches[0]
            } else {
                print("Creating new condition")
                condition = Condition(context: context)
                condition.uuid = uuid
            }
        } catch {
            print("Error fetching condition in findorcreatecondition: \(error)")
            throw error
        }
        condition.updateValues(with: conditionData)
        
        return condition
    }
    
    // MARK: - Sync Methods
    
    class func syncConditions(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        HomeFetcher.fetchConditions() { (conditionsData, error) in
            if let error = error {
                completionHandler(error)
                return
            } else if let conditionsArray = conditionsData {
                context.perform {
                    updateDatabase(with: conditionsArray, in: context)
                    do {
                        try context.save()
                        completionHandler(nil)
                    } catch {
                        print("Error saving context")
                        completionHandler(error)
                    }
                }
            }
        }
    }

    private class func updateDatabase(with conditionsArray: [Any], in context: NSManagedObjectContext) {
        var uuids: [String] = []
        for conditionData in conditionsArray {
            if let conditionDict = conditionData as? [String: Any] {
                if let condition = try? Condition.findOrCreateCondition(matching: conditionDict, in: context), let uuid = condition?.uuid {
                    uuids.append(uuid)
                }
            }
        }
        // Delete Conditions not in API results
        let request: NSFetchRequest<Condition> = Condition.fetchRequest()
        if let matches = try? context.fetch(request) {
            for condition in matches {
                if let uuid = condition.uuid, !uuids.contains(uuid) {
                    print("Condition not in API Results, deleting: \(uuid)")
                    context.delete(condition)
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func updateValues(with conditionData: [String: Any]) {
        if uuid == nil {
            uuid = conditionData[JsonKeys.uuid] as? String
        }
        name = conditionData[JsonKeys.name] as? String
        paramID = conditionData[JsonKeys.paramID] as? String
        if let pID = paramID, let context = managedObjectContext, let p = try? Parameter.findParameter(for: pID, in: context) {
                parameter = p
        }
        comparisonType = conditionData[JsonKeys.type] as? String
        comparison = conditionData[JsonKeys.comparison] as? String
        comparisonValue = conditionData[JsonKeys.comparisonValue] as? String
        comparisonParam = conditionData[JsonKeys.compParamID] as? String
        if let cID = comparisonParam, let context = managedObjectContext, let c = try? Parameter.findParameter(for: cID, in: context) {
            compParameter = c
        }
        actionID = conditionData[JsonKeys.actionID] as? String
        if let aID = actionID, let context = managedObjectContext, let a = try? Action.findAction(for: aID, in: context) {
            action = a
        }
        tolerance = conditionData[JsonKeys.tolerance] as? String
    }
    
    private struct JsonKeys {
        static let uuid = "uuid"
        static let name = "conditionName"
        static let paramID = "paramID"
        static let type = "comparisonType"
        static let comparison = "comparison"
        static let comparisonValue = "comparisonValue"
        static let compParamID = "comparisonParameter"
        static let tolerance = "tolerance"
        static let actionID = "actionID"
    }
}
