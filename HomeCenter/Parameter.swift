//
//  Parameter.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/10/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class Parameter: NSManagedObject {

    // MARK: - Initialization
    
    class func findOrCreateParameter(matching paramData: [String: Any], in context: NSManagedObjectContext) throws -> Parameter? {
        guard let uuid = paramData[JsonKeys.uuid] as? String else {
            return nil
        }
        let request: NSFetchRequest<Parameter> = Parameter.fetchRequest()
        request.predicate = NSPredicate(format: "uuid = %@", uuid)
        
        var param: Parameter
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Parameter.findOrCreateDevice - database inconsistency")
                param = matches[0]
            } else {
                param = Parameter(context: context)
                param.uuid = uuid
            }
        } catch {
            throw error
        }
        param.updateValues(with: paramData)
        
        return param
    }
    
    private func updateValues(with paramData: [String: Any]) {
        if uuid == nil {
            uuid = paramData[JsonKeys.uuid] as? String
        }
        name = paramData[JsonKeys.name] as? String
        type = paramData[JsonKeys.type] as? String
        value = paramData[JsonKeys.value] as? String
        actions = paramData[JsonKeys.actions] as? String
        if let dateString = paramData[JsonKeys.updated] as? String {
            let formatter = ISO8601DateFormatter()
            updated_at = formatter.date(from: dateString)
        }
        
    }
    
    private struct JsonKeys {
        static let name = "paramName"
        static let uuid = "uuid"
        static let type = "paramType"
        static let actions = "paramActions"
        static let value = "paramValue"
        static let updated = "updated_at"
    }
}
