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

    // MARK: - Initialization
    
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
        device.name = deviceData[JsonKeys.name] as? String
        device.type = deviceData[JsonKeys.type] as? String
        if let dateString = deviceData[JsonKeys.updated] as? String {
            let formatter = ISO8601DateFormatter()
            device.updated_at = formatter.date(from: dateString)
        }
        do {
            if let roomID = deviceData[JsonKeys.roomID] as? String {
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
    
    // MARK: - Syncing Methods
    
    class func syncDevices(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        HomeFetcher.fetchDevices { (devicesData, error) in
            if let error = error {
                completionHandler(error)
                return
            } else if let devicesDict = devicesData {
                context.perform {
                    updateDatabase(with: devicesDict, in: context)
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
    
    private class func updateDatabase(with devicesDictionary: [Any], in context: NSManagedObjectContext) {
        var uuids: [String] = []
        for deviceDict in devicesDictionary {
            if let deviceData = deviceDict as? [String: Any] {
                if let device = try? Device.findOrCreateDevice(matching: deviceData, in: context), let uuid = device?.uuid {
                    uuids.append(uuid)
                }
            }
        }
        // Delete devices not in API results
        let request: NSFetchRequest<Device> = Device.fetchRequest()
        if let matches = try? context.fetch(request) {
            for device in matches {
                if let uuid = device.uuid, !uuids.contains(uuid) {
                    print("Device not in API Results, deleting: \(uuid)")
                    context.delete(device)
                }
            }
        }
    }
    
    func delete(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        let objectID = self.objectID
        if let uuid = self.uuid {
            HomeFetcher.deleteDevice(withUUID: uuid) { (error) in
                if let error = error {
                    completionHandler(error)
                } else {
                    context.perform {
                        let device = context.object(with: objectID)
                        context.delete(device)
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
    
    
    private struct JsonKeys {
        static let name = "deviceName"
        static let uuid = "uuid"
        static let roomID = "roomID"
        static let type = "deviceType"
        static let updated = "updated_at"
    }
    
}
