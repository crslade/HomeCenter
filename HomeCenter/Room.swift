//
//  Room.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/23/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class Room: NSManagedObject {
    
    class func findOrCreateRoom(matching roomData: [String: Any], in context: NSManagedObjectContext) throws -> Room? {
        guard let uuid = roomData[jsonKeys.uuid] as? String else {
            return nil
        }
        let request: NSFetchRequest<Room> = Room.fetchRequest()
        request.predicate = NSPredicate(format: "uuid = %@", uuid)
        
        var room: Room
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Room.findOrCreateRoom - database inconsistency")
                room = matches[0]
            } else {
                room = Room(context: context)
                room.uuid = uuid
            }
        } catch {
            throw error
        }
        //Write or update values
        room.name = roomData[jsonKeys.name] as? String
        if let dateString = roomData[jsonKeys.updated] as? String {
            let formatter = ISO8601DateFormatter()
            room.updated_at = formatter.date(from: dateString)
        }
        
        return room
    }
    
    private struct jsonKeys {
        static let name = "roomName"
        static let uuid = "uuid"
        static let updated = "updated_at"
    }
    
}
