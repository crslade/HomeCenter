//
//  ConditionsTableViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 12/1/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class ConditionsTableViewController: FetchedResultsTableViewController, UISplitViewControllerDelegate {

    // MARK: - Public API
    
    var container: NSPersistentContainer? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer {
        didSet { updateUI() }
    }
    
    // MARK: - Lifcycle Methods
    
    private var fetchedResultsController: NSFetchedResultsController<Condition>? {
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
        if let nvc = self.parent as? UINavigationController, let svc = nvc.parent as? UISplitViewController {
            svc.delegate = self
        }
        updateUI()
        refreshConditions()
    }
    
    // MARK: - UI
    
    private func updateUI() {
        if let context = container?.viewContext {
            let request: NSFetchRequest<Condition> = Condition.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            ]
            fetchedResultsController = NSFetchedResultsController<Condition>(
                fetchRequest: request,
                managedObjectContext: context,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
        }
    }
    
    @IBAction func refreshRequested() {
        refreshConditions()
    }
    
    // MARK: - API Data Management
    
    private func refreshConditions() {
        if let bgContext = container?.newBackgroundContext() {
            self.refreshControl?.beginRefreshing()
            Condition.syncConditions(in: bgContext) {[weak self] (error) in
                if let error = error {
                    print("Error syncing conditions: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Could not sync conditions.")
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
                if let conditionCount = try? context.count(for: Condition.fetchRequest()) {
                    print("\(conditionCount) conditions")
                }
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.ConditionCell, for: indexPath)
        
        if let condition = fetchedResultsController?.object(at: indexPath) {
            cell.textLabel?.text = condition.name ?? "<No Name>"
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
        
        return [editAction,deleteAction]
    }
    
    // MARK: - TableViewRowAction Handler Methods
    
    private func editRow(at indexPath: IndexPath) {
        print("Edit Row")
        if let condition = fetchedResultsController?.object(at: indexPath) {
            performSegue(withIdentifier: Storyboard.AddEditConditionSegue, sender: condition)
        }
    }
    
    private func deleteRow(at indexPath: IndexPath) {
        print("Delete Row")
        if let condtion = fetchedResultsController?.object(at: indexPath), let context = condtion.managedObjectContext {
            condtion.delete(in: context) {[weak self] (error) in
                if let error = error {
                    print("Error deleting condition: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Error deleting condition")
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Storyboard.SelectConditionSegue, let dvc = segue.destination.contentViewController as? ConditionViewController {
            if let cell = sender as? UITableViewCell, let indexPath = tableView?.indexPath(for: cell) {
                dvc.condition = fetchedResultsController?.object(at: indexPath)
            }
        }
        if segue.identifier == Storyboard.AddEditConditionSegue, let dvc = segue.destination.contentViewController as? EditConditionViewController {
            if let condition = sender as? Condition {
                dvc.condition = condition
            } else if let context = container?.viewContext {
                dvc.condition = Condition(context: context)
            }
        }
    }

    @IBAction func cancelEditCondition(segue: UIStoryboardSegue) {
        print("Cancel Edit Condition")
        container?.viewContext.rollback()
    }
    
    @IBAction func doneEditCondition(segue: UIStoryboardSegue) {
        print("Done Edit Condition")
        if let condition = (segue.source as? EditConditionViewController)?.condition, let context = condition.managedObjectContext {
            condition.saveToPI() {[weak self] (error) in
                context.perform {
                    if let error = error {
                        context.rollback()
                        print("Error saveing to API: \(error)")
                        DispatchQueue.main.async {
                            self?.presentErrorAlert(withMessage: "Error saving condition.")
                        }
                    } else {
                        do {
                            try context.save()
                        } catch {
                            print("Error saving context: \(error)")
                            DispatchQueue.main.async {
                                self?.presentErrorAlert(withMessage: "Error saving changes locally.")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - UISplitViewControllerDelegate
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }

    private struct Storyboard {
        static let ConditionCell = "Condition Cell"
        static let SelectConditionSegue = "Show Condition"
        static let AddEditConditionSegue = "Add Edit Condition"
    }
    
}

extension ConditionsTableViewController
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
