//
//  RoomsTableViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/24/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class RoomsTableViewController: FetchedResultsTableViewController, UISplitViewControllerDelegate {

    // MARK: - Public API
    
    var container: NSPersistentContainer? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer {
        didSet { updateUI() }
    }
    
    // MARK: - Lifecycle Methods and data
    
    private var needsAPIKeys: Bool = false
    
    private lazy var backgroundContext: NSManagedObjectContext? = {
        [weak self] in
            return container?.newBackgroundContext()
        }()
    
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
        // Enable Editing
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        //Make myself the split view controllers delagate.
        if let nvc = self.parent as? UINavigationController, let svc = nvc.parent as? UISplitViewController {
            svc.delegate = self
        } else {
            print("Can't find svc")
        }
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
    
    // MARK: - API Data Management
    
    private func refreshRooms() {
        if let bgContext = container?.newBackgroundContext() {
            self.refreshControl?.beginRefreshing()
            Room.syncRooms(in: bgContext) {[weak self] (error) in
                if let error = error {
                    print("Error syncing rooms: \(error)")
                    self?.presentErrorAlert(withMessage: "Could not sync rooms")
                }
                self?.printDBStats()
                DispatchQueue.main.async {
                    self?.refreshControl?.endRefreshing()
                }
            }
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
    
    //MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.RoomCell, for: indexPath)
        
        if let room = fetchedResultsController?.object(at: indexPath) {
            cell.textLabel?.text = room.name ?? "<No Name>"
            let deviceCount = room.devices?.count ?? 0
            cell.detailTextLabel?.text = (deviceCount == 1) ? "\(deviceCount) device" : "\(deviceCount) devices"
        }
        
        return cell
    }
    
   override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let editRowAction = UITableViewRowAction(style: .default, title: "Edit") {[weak self] (action, indexPath) in
            self?.editRow(at: indexPath)
        }
        editRowAction.backgroundColor = .blue
        let deleteRowAction = UITableViewRowAction(style: .destructive, title: "Delete") {[weak self] (action, indexPath) in
            self?.deleteRow(at: indexPath)
        }
        
        return [deleteRowAction, editRowAction]
    }
    
    
    // MARK: - TableViewAction Handlers
    
    func editRow(at indexPath: IndexPath) {
        print("Edit Row")
        if let room = fetchedResultsController?.object(at: indexPath) {
            performSegue(withIdentifier: Storyboard.AddEditRoomSegue, sender: room)
        }
    }
    
    func deleteRow(at indexPath: IndexPath) {
        print("Delete Row")
        if let room = fetchedResultsController?.object(at: indexPath), let context = backgroundContext {
            room.delete(in: context)  { [weak self] (error) in
                if let error = error {
                    print("Error deleting room: \(error)")
                    self?.presentErrorAlert(withMessage: "Error deleting room.")
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Storyboard.DeviceSegue, let cell = sender as? UITableViewCell {
            if let devicesTVC = segue.destination as? DevicesTableViewController {
                if let indexPath = tableView.indexPath(for: cell) {
                    print("Setting room")
                    devicesTVC.room = fetchedResultsController?.object(at: indexPath)
                }
            }
        }
        if segue.identifier == Storyboard.AddEditRoomSegue, let dvc = segue.destination.contentViewController as? EditRoomViewController {
            if let room = sender as? Room, let context = backgroundContext, let editRoom = context.object(with: room.objectID) as? Room {
               dvc.room = editRoom
            } else if let context = backgroundContext {
                dvc.room = Room(context: context)
            }
        }
    }
    
    @IBAction func unwindFromInfo(segue: UIStoryboardSegue) {
        if let _ = segue.source as? APIInfoViewController {
            needsAPIKeys = false
            refreshRooms()
        }
    }
    
    @IBAction func cancelEditRoom(segue: UIStoryboardSegue) {
        print("Canceled Add/Edit")
        backgroundContext?.reset()
    }
    
    @IBAction func doneEditRoom(segue: UIStoryboardSegue) {
        print("Done Adding/Editing Room")
        if let svc = segue.source as? EditRoomViewController, let room = svc.room {
            room.saveToAPI(with: { [weak self] (error) in
                if let error = error {
                    print ("Error saving edit to API: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Error Saving Changes to API.")
                    }
                    self?.backgroundContext?.perform {
                        self?.backgroundContext?.reset()
                    }
                } else {
                    self?.backgroundContext?.perform {
                        do {
                            try self?.backgroundContext?.save()
                        } catch {
                            print("Error saving context: \(error)")
                            DispatchQueue.main.async {
                                self?.presentErrorAlert(withMessage: "Error saving changes locally.")
                            }
                        }
                    }
                }
            })
        }
    }
    
    // MARK: - UISplitViewControllerDelegate
    
    //Makes it show masterVC instead of detail
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    private struct Storyboard {
        static let RoomCell = "Room Cell"
        static let DeviceSegue = "Show Room Devices"
        static let APISegue = "Get API Info"
        static let AddEditRoomSegue = "Add Edit Room"
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
