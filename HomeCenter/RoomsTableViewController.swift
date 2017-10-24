//
//  RoomsTableViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/24/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class RoomsTableViewController: FetchedResultsTableViewController {

    // MARK: Public API
    
    var container: NSPersistentContainer? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer {
        didSet { updateUI() }
    }
    
    // MARK: Lifecycle Methods and data
    
    private var fetchedResultsController: NSFetchedResultsController<Room>? {
        didSet {
            do {
                if let frc = fetchedResultsController {
                    frc.delegate = self
                    try frc.performFetch()
                }
                tableView.reloadData()
            } catch {
                self.presentErrorAlert(with: "Fetched results controller error")
                print("FetchedResultsController perform failed: \(error)")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshRooms()
        updateUI()
    }
    
    // MARK: UI
    
    private func updateUI() {
        if let context = container?.viewContext {
            let request: NSFetchRequest<Room> = Room.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(
                key: "name",
                ascending: true,
                selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
            )]
            fetchedResultsController = NSFetchedResultsController<Room>(
                fetchRequest: request,
                managedObjectContext: context,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            
        }
    }
    
    @IBAction func refreshRequested(_ sender: UIRefreshControl) {
        refreshRooms()
    }
    
    // MARK: API Data Manager
    
    private func refreshRooms() {
        HomeFetcher.fetchAllRooms { [weak self] (jsonData, error) in
            if let error = error {
                print("Error: \(error)")
                self?.presentErrorAlert(with: "Error downloading data from API")
            } else if let roomsData = jsonData {
                self?.updateDatabase(with: roomsData)
            } else {
                self?.presentErrorAlert(with: "Didn't fetch any rooms")
                print("HomeFetcher didn't error or return a result - Why?")
            }
            DispatchQueue.main.async {
                self?.refreshControl?.endRefreshing()
            }
        }
    }
    
    
    private func updateDatabase(with rooms: [Any]) {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = container?.viewContext //makes sure viewContext gets notified about changes, so the fetched result controller will update.
        context.perform { [weak self] in
            if Thread.isMainThread {
                print("Main Thread")
            } else {
                print("Background thread")
            }
            for room in rooms {
                if let roomData = room as? [String: Any] {
                    _ = try? Room.findOrCreateRoom(matching: roomData, in: context)
                }
            }
            do {
                try context.save()
                print("Context Saved")
            } catch {
                print("Error Saving Context: \(error)")
            }
            self?.printDBStats()
        }
    }
    
    private func printDBStats() {
        if let context = container?.viewContext {
            context.perform { 
                if let roomCount = try? context.count(for: Room.fetchRequest()) {
                    print("\(roomCount) rooms")
                }
            }
        }
    }
    
    //MARK: UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.RoomCell, for: indexPath)
        
        if let room = fetchedResultsController?.object(at: indexPath) {
            cell.textLabel?.text = room.name ?? "<No Name>"
        }
        
        return cell
    }
    
    private struct Storyboard {
        static let RoomCell = "Room Cell"
    }
    

}

extension RoomsTableViewController
{
    // MARK: UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController?.sections?.count ?? 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sections = fetchedResultsController?.sections, sections.count > 0 {
            return sections[section].numberOfObjects
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let sections = fetchedResultsController?.sections, sections.count > 0 {
            return sections[section].name
        } else {
            return nil
        }
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return fetchedResultsController?.sectionIndexTitles
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return fetchedResultsController?.section(forSectionIndexTitle: title, at: index) ?? 0
    }
}
