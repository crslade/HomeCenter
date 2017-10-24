//
//  ViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/23/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    
    var container: NSPersistentContainer? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        HomeFetcher.fetchAllRooms() {[weak self]  (rooms, error) in
            if let error = error {
                print("Error: \(error)")
            } else if let rooms = rooms {
                self?.updateDatabase(with: rooms)
            } else {
                print("No rooms")
            }
        }
    }
    
    private func updateDatabase(with rooms: [Any]) {
        container?.performBackgroundTask {[weak self] (context) in
            for room in rooms {
                if let roomData = room as? [String: Any] {
                    _ = try? Room.findOrCreateRoom(matching: roomData, in: context)
                }
            }
            try? context.save()
            self?.printDBStats()
        }
    }
    
    private func printDBStats() {
        if let context = container?.viewContext {
            context.perform { [weak self] in
                if let roomCount = try? context.count(for: Room.fetchRequest()) {
                    print("\(roomCount) rooms")
                }
                self?.printRooms()
            }
        }
    }
    
    private func printRooms() {
        if let context = container?.viewContext {
            context.perform {
                if let rooms: [Room] = try? context.fetch(Room.fetchRequest()) {
                    for room in rooms {
                        print("\(room.name!):\(room.uuid!)")
                    }
                }
            }
        }
    }

}

