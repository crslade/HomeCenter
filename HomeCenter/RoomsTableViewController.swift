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
    
    private var needsAPIKeys: Bool = false
    
    private var fetchedResultsController: NSFetchedResultsController<Room>? {
        didSet {
            do {
                if let frc = fetchedResultsController {
                    frc.delegate = self
                    try frc.performFetch()
                }
                tableView.reloadData()
            } catch {
                self.presentErrorAlert(withMessage: "Fetched results controller error")
                print("FetchedResultsController perform failed: \(error)")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if HomeFetcher.APIvaluesSet() {
            refreshRooms()
        } else {
            print("No API Key/URL Set")
            needsAPIKeys = true //Remeber to segue to get APIKeys in viewDidAppear
        }
        updateUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if needsAPIKeys {
            performSegue(withIdentifier: Storyboard.APISegue, sender: self)
        }
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
    
    // MARK: API Data Management
    
    private func refreshRooms() {
        self.refreshControl?.beginRefreshing()
        HomeFetcher.fetchRooms { [weak self] (jsonData, error) in
            if let error = error {
                print("Error: \(error)")
                self?.presentErrorAlert(withMessage: "Error downloading data from API")
            } else if let roomsData = jsonData {
                self?.updateDatabase(with: roomsData)
            } else {
                self?.presentErrorAlert(withMessage: "Didn't fetch any rooms")
                print("HomeFetcher didn't error or return a result - Why?")
            }
            DispatchQueue.main.async {
                self?.refreshControl?.endRefreshing()
            }
        }
    }
    
    
    private func updateDatabase(with rooms: [Any]) {
        container?.performBackgroundTask { [weak self] context in
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
            let deviceCount = room.devices?.count ?? 0
            cell.detailTextLabel?.text = (deviceCount == 1) ? "\(deviceCount) device" : "\(deviceCount) devices"
        }
        
        return cell
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Storyboard.DeviceSegue, let cell = sender as? UITableViewCell {
            if let devicesTVC = segue.destination as? DevicesTableViewController {
                if let indexPath = tableView.indexPath(for: cell) {
                    print("Setting room")
                    devicesTVC.room = fetchedResultsController?.object(at: indexPath)
                }
            }
         }
        //Nothing needs to be done to prepare for API Info Segue
    }
    
    @IBAction func unwindFromInfo(segue: UIStoryboardSegue) {
        if let settingsVC = segue.source as? APIInfoViewController {
            print("Coming back with url = \(settingsVC.apiUrl):\(settingsVC.apiKey)")
            needsAPIKeys = false
            refreshRooms()
        }
    }
    
    private struct Storyboard {
        static let RoomCell = "Room Cell"
        static let DeviceSegue = "Show Room Devices"
        static let APISegue = "Get API Info"
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
