//
//  ActionsTableViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/14/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class ActionsTableViewController: FetchedResultsTableViewController, UISplitViewControllerDelegate {
    
    // MARK: - Public API
    
    var container: NSPersistentContainer? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer {
        didSet { updateUI() }
    }
    
    // MARK: - Lifecycle Methods and data
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshActions()
        if let nvc = self.parent as? UINavigationController, let svc = nvc.parent as? UISplitViewController {
            svc.delegate = self
        }
        updateUI()
    }

    private var fetchedResultsController: NSFetchedResultsController<Action>? {
        didSet {
            do {
                if let frc = fetchedResultsController {
                    frc.delegate = self
                    try frc.performFetch()
                }
            } catch {
                self.presentErrorAlert(withMessage: "Fetched Results Controller Error")
                print("FecthedResultsController perform failed: \(error)")
            }
        }
    }

    private lazy var scratchpadContext: NSManagedObjectContext = {
        let newContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        newContext.parent = self.container?.viewContext
        return newContext
        }()
    
    // MARK: - UI
    
    private func updateUI() {
        if let context = container?.viewContext {
            let request: NSFetchRequest<Action> = Action.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            ]
            fetchedResultsController = NSFetchedResultsController<Action>(
                fetchRequest: request,
                managedObjectContext: context,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
        }
    }
    
    @IBAction func refreshRequested() {
        refreshActions()
    }
    
    // MARK: - API Data Management
    
    private func refreshActions() {
        if let bgContext = container?.newBackgroundContext() {
            self.refreshControl?.beginRefreshing()
            Action.syncActions(in: bgContext) {[weak self] (error) in
                if let error = error {
                    print("Error syncing rooms: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Could not sync actions.")
                    }
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
                if let actionCount = try? context.count(for: Action.fetchRequest()) {
                    print("\(actionCount) actions")
                }
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.ActionCell, for: indexPath)
        
        if let action = fetchedResultsController?.object(at: indexPath) {
            cell.textLabel?.text = action.name ?? "<No Name>"
            let commandCount = action.commands?.count ?? 0
            cell.detailTextLabel?.text = (commandCount == 1) ? "1 commands" : "\(commandCount) commands"
        }

        return cell
    }



    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    // MARK: - UISplitViewControllerDelegate
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    // MARK: - Navigation
    
    @IBAction func cancelEditAction(segue: UIStoryboardSegue) {
        print("Cancel Edit Action")
        scratchpadContext.rollback()
//        if let editAction = (segue.source as? EditActionViewController)?.action {
//            scratchpadContext.perform { [weak self] in
//                self?.scratchpadContext.delete(editAction)
//            }
//        }
    }
    
    @IBAction func doneEditAction(segue: UIStoryboardSegue) {
        print("Done Edit Action")
        if let editAction = (segue.source as? EditActionViewController)?.action {
            editAction.saveToAPI() {[weak self] (error) in
                self?.scratchpadContext.perform {
                    if let error = error {
                        self?.scratchpadContext.rollback()
                        print("Error saving to API: \(error)")
                        DispatchQueue.main.async {
                            self?.presentErrorAlert(withMessage: "Error Saving changes locally.")
                        }
                    } else {
                        do {
                            try self?.scratchpadContext.save()
                            self?.container?.viewContext.performAndWait {
                                do {
                                    try self?.container?.viewContext.save()
                                } catch {
                                    print("Couldn't save view context: \(error)")
                                    DispatchQueue.main.async {
                                        self?.presentErrorAlert(withMessage: "Error saving changes locally.")
                                    }
                                }
                            }
                        } catch {
                            print("Coundn't save child context: \(error)")
                            DispatchQueue.main.async {
                                self?.presentErrorAlert(withMessage: "Error saving changes locally.")
                            }
                        }
                    }
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("Ident: \(segue.identifier!)")
        if segue.identifier == Storyboard.ActionDetailSegue, let dvc = segue.destination.contentViewController as? ActionTableViewController {
            if let cell = sender as? UITableViewCell, let indexPath = tableView?.indexPath(for: cell) {
                dvc.action = fetchedResultsController?.object(at: indexPath)
            }
        }
        if segue.identifier == Storyboard.AddActionSegue, let dvc = segue.destination.contentViewController as? EditActionViewController {
            dvc.action = Action(context: scratchpadContext)
        }
    }

    private struct Storyboard {
        static let ActionCell = "Action Cell"
        static let ActionDetailSegue = "Show Action"
        static let AddActionSegue = "Add Action"
    }
}

extension ActionsTableViewController
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
