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
    // MARK: - Helper Variables
    var jsonUrl: String?
    var parameterData: [Any]?

    var loadedProperties: Bool = false
    
    // MARK: - Initialization
    
    class func findOrCreateDevice(matching deviceData: [String: Any], in context: NSManagedObjectContext) throws -> Device? {
        guard let uuid = deviceData[JsonKeys.uuid] as? String else {
            return nil
        }
        let request: NSFetchRequest<Device> = Device.fetchRequest()
        request.predicate = NSPredicate(format: "uuid = %@", uuid)
        
        var device: Device
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Device.findOrCreateDevice - database inconsistency")
                device = matches[0]
            } else {
                device = Device(context: context)
                device.uuid = uuid
            }
        } catch {
            throw error
        }
        //Write or update values
        device.updateValues(with: deviceData)
        
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
    
    func saveToAPI(with completionHandler: @escaping (Error?) -> Void) {
        do {
            if let deviceID = uuid, let deviceData = try convertToJson() {
                print("Should update device: \(deviceID)")
                HomeFetcher.editDevice(with: deviceID, deviceData: deviceData) { (deviceData, error) in
                    if let error = error {
                        completionHandler(error)
                    } else if let _ = deviceData {
                        print("Update succeeded")
                        completionHandler(nil)
                    }
                }
            } else if let deviceData = try convertToJson() {
                HomeFetcher.addDevice(deviceData) {[weak self] (deviceData, error) in
                    if let error = error {
                        completionHandler(error)
                    } else if let deviceDict = deviceData {
                        self?.managedObjectContext?.perform {
                            print("Updating device with id")
                            self?.updateValues(with: deviceDict)
                        }
                        completionHandler(nil)
                    } else {
                        print("No error or data in Device - savetoapi?? new")
                        completionHandler(HomeFetcherError.DownloadError("No Data"))
                    }
                }
            }
        } catch {
            print("Error converting to Json: \(error)")
            completionHandler(error)
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
    
    // MARK: - JSON Properties
    
    func loadJsonProperties(completionHandler: @escaping (Error?) -> Void) {
        if let url = jsonUrl {
            HomeFetcher.fetchDeviceJson(at: url) {[weak self] (jsonData, error) in
                if let error = error {
                    completionHandler(error)
                } else if let jsonDict = jsonData {
                    self?.name = jsonDict[JsonKeys.name] as? String
                    self?.type = jsonDict[JsonKeys.type] as? String
                    self?.parameterData = jsonDict[JsonKeys.parameters] as? [Any]
                    self?.loadedProperties = true
                    completionHandler(nil)
                } else {
                    print("No Error or data??")
                    completionHandler(HomeFetcherError.DownloadError("No Data"))
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func updateValues(with deviceData: [String: Any]) {
        if uuid == nil {
            uuid = deviceData[JsonKeys.uuid] as? String
        }
        name = deviceData[JsonKeys.name] as? String
        type = deviceData[JsonKeys.type] as? String
        if let dateString = deviceData[JsonKeys.updated] as? String {
            let formatter = ISO8601DateFormatter()
            updated_at = formatter.date(from: dateString)
        }
        //connect to room
        do {
            if let roomID = deviceData[JsonKeys.roomID] as? String, let context = managedObjectContext {
                if let room = try Room.findRoom(with: roomID, in: context) {
                    self.room = room
                }
            }
        } catch {
            print("Couldn't fetch room for device: \(error)")
        }
        if let paramsData = deviceData[JsonKeys.parameters] as? [Any] {
            updateParameters(with: paramsData)
        }
    }
    
    private func updateParameters(with paramsData: [Any]) {
        if let context = self.managedObjectContext {
            for paramData in paramsData {
                if let paramDict = paramData as? [String: Any] {
                    do {
                        if let param = try Parameter.findOrCreateParameter(matching: paramDict, in: context) {
                            param.device = self
                        }
                    } catch {
                        print("Failed to create parameter. \(error)")
                    }
                }
            }
        }
    }
    
    
    private func convertToJson() throws -> String? {
        var deviceDict: [String: Any] = [
            JsonKeys.name : self.name ?? "",
            JsonKeys.type : self.type ?? "",
            JsonKeys.roomID : self.room?.uuid as Any
        ]
        if let paramsData = parameterData {
            deviceDict[JsonKeys.parameters] = paramsData
        }
        let jsonData = try JSONSerialization.data(withJSONObject: deviceDict, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8)
    }
    
    private struct JsonKeys {
        static let name = "deviceName"
        static let uuid = "uuid"
        static let roomID = "roomID"
        static let type = "deviceType"
        static let parameters = "parameters"
        static let updated = "updated_at"
    }
    
}
