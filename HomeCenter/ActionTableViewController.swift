//
//  ActionTableViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/15/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit

class ActionTableViewController: UITableViewController {

    // MARK: - Public API
    
    var action: Action? {
        didSet {
            commands = action?.commands?.allObjects as? [ActionCommand]
            updateUI()
        }
    }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - UI
    
    private var commands: [ActionCommand]?
    
    private func updateUI() {
        self.title = action?.name ?? "Action"
        tableView.reloadData()
    }

    @IBAction func fireRequested(_ sender: UIBarButtonItem) {
        if let action = action {
            action.fire() {[weak self] (error) in
                if let error = error {
                    print("Error Firing Action: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Error firing action.")
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
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return action?.commands?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.CommandCell, for: indexPath)

        if let command = commands?[indexPath.row] {
            cell.textLabel?.text = (command.parameter?.device?.name ?? "No Device")+":"+(command.parameter?.name ?? "No Parameter")
            cell.detailTextLabel?.text = command.parameter?.value
        }
        
        return cell
    }



    // MARK: - Navigation

    @IBAction func cancelEditAction(segue: UIStoryboardSegue) {
        print("Cancel Edit Action")
    }
    
    @IBAction func doneEditAction(segue: UIStoryboardSegue) {
       print("Done Edit Action")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }

    
    private struct Storyboard {
        static let CommandCell = "Action Command Cell"
    }
    
}
