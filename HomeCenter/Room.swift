//
//  Room.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/23/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class Room: NSManagedObject
{
   
    // MARK: - Initializers
    
    class func findOrCreateRoom(matching roomData: [String: Any], in context: NSManagedObjectContext) throws -> Room? {
        guard let uuid = roomData[JsonKeys.uuid] as? String else {
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
                print("Creating new")
                room = Room(context: context)
                room.uuid = uuid
            }
        } catch {
            print("Error fetching rooms in findorcreatingroom: \(error)")
            throw error
        }
        //Write or update values
        room.updateValues(with: roomData)
        
        return room
    }
    
    class func findRoom(with uuid: String, in context: NSManagedObjectContext) throws -> Room? {
        let request: NSFetchRequest<Room> = Room.fetchRequest()
        request.predicate = NSPredicate(format: "uuid = %@", uuid)
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Room.findOrCreateRoom - database inconsistency")
               return matches[0]
            } else {
                return nil
            }
        } catch {
            throw error
        }
    }
    
    // MARK - Sync Methods
    
    class func syncRooms(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        HomeFetcher.fetchRooms { (roomsData, error) in
            if let error = error {
                completionHandler(error)
                return
            } else if let roomsDict = roomsData {
                context.perform {
                    updateDatabase(with: roomsDict, in: context)
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
    
    private class func updateDatabase(with roomsDictionary: [Any], in context: NSManagedObjectContext) {
        var uuids: [String] = []
        for roomDict in roomsDictionary {
            if let roomData = roomDict as? [String: Any] {
                if let room = try? Room.findOrCreateRoom(matching: roomData, in: context), let uuid = room?.uuid {
                    uuids.append(uuid)
                }
            }
        }
        //delete rooms missing from API
        let request: NSFetchRequest<Room> = Room.fetchRequest()
        if let matches = try? context.fetch(request) {
            for room in matches {
                if let uuid = room.uuid, !uuids.contains(uuid) {
                    print("Room not in API results, deleting.")
                    context.delete(room)
                }
            }
        }
    }
    
    func saveToAPI(with completionHandler: @escaping (Error?) -> Void)  {
        do {
            if let roomID = uuid, let roomData = try convertToJson() {
                HomeFetcher.editRoom(withID: roomID, roomData: roomData, completionHandler: { (roomData, error) in
                    if let error = error {
                        completionHandler(error)
                    } else if let _ = roomData {
                        completionHandler(nil)
                    } else {
                        print("No error or data in Room - saveToApi??")
                        completionHandler(HomeFetcherError.DownloadError("No Data"))
                    }
                })
            } else if let roomData = try convertToJson() {
                HomeFetcher.addRoom(roomData, with: {[weak self] (roomData, error) in
                    if let error = error {
                        completionHandler(error)
                    } else if let roomDict = roomData {
                        self?.managedObjectContext?.perform {
                            print("Updating room with id")
                            self?.updateValues(with: roomDict)
                        }
                        completionHandler(nil)
                    } else {
                        print("No error or data in Room - savetoapi??? new")
                        completionHandler(HomeFetcherError.DownloadError("No Data"))
                    }
                })
            }
        } catch {
            completionHandler(error)
        }
    }
    
    func delete(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        let objectID = self.objectID
        if let uuid = self.uuid {
            HomeFetcher.deleteRoom(withUUID: uuid) { (error) in
                if let error = error {
                    completionHandler(error)
                } else {
                    context.perform {
                        let room = context.object(with: objectID)
                        context.delete(room)
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
    }
    
    // MARK: - Utility Methods
    
    func updateValues(with roomData: [String: Any]) {
        if uuid == nil {
            uuid = roomData[JsonKeys.uuid] as? String
        }
        name = roomData[JsonKeys.name] as? String
        if let dateString = roomData[JsonKeys.updated] as? String {
            let formatter = ISO8601DateFormatter()
            updated_at = formatter.date(from: dateString)
        }
    }
    
    func convertToJson() throws -> String?  {
        let roomDict = [
            JsonKeys.name : self.name ?? ""
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: roomDict, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8)
    }
    
    private struct JsonKeys {
        static let name = "roomName"
        static let uuid = "uuid"
        static let updated = "updated_at"
    }
    
}
