//
//  DevicesTableViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/25/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class DevicesTableViewController: FetchedResultsTableViewController {
    
    // MARK: Public API
    
    var container: NSPersistentContainer? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer {
        didSet { updateUI() }
    }
    
    var room: Room? {
        didSet { updateUI() }
    }
    
    // MARK: Lifecycle Methods and Data
    
    private var fetchedResultsController: NSFetchedResultsController<Device>? {
        didSet {
            do {
                if let frc = fetchedResultsController {
                    frc.delegate = self
                    try frc.performFetch()
                }
            } catch {
                self.presentErrorAlert(withMessage: "Fetched Results Controller Error")
                print("FetchedResultsController perform failed: \(error)")
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshDevices()
        updateUI()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: UI
    
    @IBAction func refreshRequested(_ sender: UIRefreshControl) {
        refreshDevices()
    }
    
    func updateUI() {
        print("Updating UI")
        self.title = "Devices"
        if let context = container?.viewContext {
            let request: NSFetchRequest<Device> = Device.fetchRequest()
            if let rm = room {
                self.title = rm.name ?? "Room Devices"
                request.predicate = NSPredicate(format: "room = %@", rm)
            }
            request.sortDescriptors = [NSSortDescriptor(
                key: "name",
                ascending: true,
                selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
                )]
            fetchedResultsController = NSFetchedResultsController<Device>(
                fetchRequest: request,
                managedObjectContext: context,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
        }
    }
    
    // MARK: API Data Management
    
    private func refreshDevices() {
        self.refreshControl?.beginRefreshing()
        HomeFetcher.fetchDevices { [weak self] (jsonData, error) in
            if let error = error {
                print("Error: \(error)")
                self?.presentErrorAlert(withMessage: "Error downloading data from API")
            } else if let devicesData = jsonData {
                self?.updateDatabase(with: devicesData)
            } else {
                self?.presentErrorAlert(withMessage: "Didn't fetch any devices")
                print("HomeFetcher didn't error or return a result - Why?")
            }
            DispatchQueue.main.async {
                self?.refreshControl?.endRefreshing()
            }
        }
    }
    
    private func updateDatabase(with devicesData: [Any]) {
        container?.performBackgroundTask { [weak self] context in
            do {
                for device in devicesData {
                    if let deviceData = device as? [String: Any] {
                        _ = try Device.findOrCreateDevice(matching: deviceData, in: context)
                    }
                }
                try context.save()
                print("Context Saved")
            } catch {
                print("Error creating or saving context: \(error)")
            }
            self?.printDBStats()
        }
    }
    
    private func printDBStats() {
        if let context = container?.viewContext {
            context.perform {
                if let deviceCount = try? context.count(for: Device.fetchRequest()) {
                    print("\(deviceCount) devices")
                }
            }
        }
    }

    // MARKL UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.DeviceCell, for: indexPath)
        
        if let device = fetchedResultsController?.object(at: indexPath) {
            cell.textLabel?.text = device.name ?? "<No Name>"
            cell.detailTextLabel?.text = device.room?.name ?? ""
        }
        
        return cell
    }

    private struct Storyboard {
        static let DeviceCell = "Device Cell"
    }
    
}


extension DevicesTableViewController
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
