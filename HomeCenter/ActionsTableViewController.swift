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
                    print("Error syncing actions: \(error)")
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

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let editAction = UITableViewRowAction(style: .default, title: "Edit") {[weak self] (rowAction, indexPath) in
            self?.editRow(at: indexPath)
        }
        editAction.backgroundColor = .blue
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") {[weak self] (rowAction, indexPath) in
            self?.deleteRow(at: indexPath)
        }
        let fireAction = UITableViewRowAction(style: .default, title: "Fire") {[weak self] (rowAction, indexPath) in
            self?.fireRow(at: indexPath)
        }
        fireAction.backgroundColor = .lightGray
        
        return [fireAction,editAction,deleteAction]
    }

    // MARK: - TableViewRowAction Handler Methods
    
    private func deleteRow(at indexPath: IndexPath) {
        print("Delete Row")
        if let action = fetchedResultsController?.object(at: indexPath), let context = action.managedObjectContext {
            action.delete(in: context) {[weak self] (error) in
                if let error = error {
                    print("Error deleting action: \(error)")
                    self?.presentErrorAlert(withMessage: "Error deleting device.")
                }
            }
        }
    }
    
    private func editRow(at indexPath: IndexPath) {
        print("Edit Row")
        if let action = fetchedResultsController?.object(at: indexPath) {
            performSegue(withIdentifier: Storyboard.AddEditActionSegue, sender: action)
        }
    }
    
    private func fireRow(at indexPath: IndexPath) {
        print("Fire Row")
        if let action = fetchedResultsController?.object(at: indexPath) {
            action.fire() {[weak self] (error) in
                if let error = error {
                    print("Error firing action: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Error Firing Action")
                    }
                } else {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Success", message: "Action Fired", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    

    // MARK: - UISplitViewControllerDelegate
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    // MARK: - Navigation
    
    @IBAction func cancelEditAction(segue: UIStoryboardSegue) {
        print("Cancel Edit Action")
         container?.viewContext.rollback()
    }
    
    @IBAction func doneEditAction(segue: UIStoryboardSegue) {
        print("Done Edit Action")
        if let action = (segue.source as? EditActionViewController)?.action, let context = action.managedObjectContext {
            action.saveToAPI() {[weak self] (error) in
                context.perform {
                    if let error = error {
                        context.rollback()
                        print("Error saving to API: \(error)")
                        DispatchQueue.main.async {
                            self?.presentErrorAlert(withMessage: "Error Saving changes locally.")
                        }
                    } else {
                        do {
                            try context.save()
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
        if segue.identifier == Storyboard.ActionDetailSegue, let dvc = segue.destination.contentViewController as? ActionTableViewController {
            if let cell = sender as? UITableViewCell, let indexPath = tableView?.indexPath(for: cell) {
                dvc.action = fetchedResultsController?.object(at: indexPath)
            }
        }
        if segue.identifier == Storyboard.AddEditActionSegue, let dvc = segue.destination.contentViewController as? EditActionViewController {
            if let action = sender as? Action {
                dvc.action = action
            } else if let context = container?.viewContext {
                dvc.action = Action(context: context)
            }
        }

    }

    private struct Storyboard {
        static let ActionCell = "Action Cell"
        static let ActionDetailSegue = "Show Action"
        static let AddEditActionSegue = "Add Edit Action"
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
