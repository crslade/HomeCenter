//
//  Device.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/23/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class Device: NSManagedObject
{

    class func findOrCreateDevice(matching deviceData: [String: Any], in context: NSManagedObjectContext) throws -> Device? {
        guard let uuid = deviceData["uuid"] as? String else {
            return nil
        }
        let request: NSFetchRequest<Device> = Device.fetchRequest()
        request.predicate = NSPredicate(format: "uuid = %@", uuid)
        
        var device: Device
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Room.findOrCreateDevice - database inconsistency")
                device = matches[0]
            } else {
                device = Device(context: context)
                device.uuid = uuid
            }
        } catch {
            throw error
        }
        //Write or update values
        device.name = deviceData[jsonKeys.name] as? String
        device.type = deviceData[jsonKeys.type] as? String
        if let dateString = deviceData[jsonKeys.updated] as? String {
            let formatter = ISO8601DateFormatter()
            device.updated_at = formatter.date(from: dateString)
        }
        do {
            print("\(deviceData[jsonKeys.roomID])")
            if let roomID = deviceData[jsonKeys.roomID] as? String {
               print("\(roomID)")
                if let room = try Room.findRoom(with: roomID, in: context) {

                    device.room = room
                }
            }
        } catch {
            print("Couldn't fetch room")
            throw error
        }
        
        return device
    }
    
    private struct jsonKeys {
        static let name = "deviceName"
        static let uuid = "uuid"
        static let roomID = "roomID"
        static let type = "deviceType"
        static let updated = "updated_at"
    }
    
}
