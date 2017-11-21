//
//  DeviceTableViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/13/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit

class DeviceTableViewController: UITableViewController {
    
    // MARK: - Public API
    
    var device: Device? {
        didSet {
            parameters = device?.parameters?.allObjects as? [Parameter]
            updateUI()
        }
    }
    
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - UI
    
    private var parameters: [Parameter]?
    
    func updateUI() {
        tableView?.reloadData()
    }
    
    @IBAction func refreshRequested() {
        refreshDevice()
    }
    
    // MARK: - API
    
    private func refreshDevice() {
        if let device = device {
            self.refreshControl?.beginRefreshing()
            print("Updating Device")
            device.updateFromApi() {[weak self] (error) in
                if let error = error {
                    print("Error refreshing device: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Error Refreshing Device.")
                        self?.refreshControl?.endRefreshing()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.tableView?.reloadData()
                        self?.refreshControl?.endRefreshing()
                    }
                }
            }
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
           return parameters?.count ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Device"
        } else {
            return "Parameters"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let deviceCell = tableView.dequeueReusableCell(withIdentifier: Storyboard.DeviceCell, for: indexPath)
            
            deviceCell.textLabel?.text = device?.name ?? "<No Name>"
            deviceCell.detailTextLabel?.text = device?.room?.name ?? "<No Room>"
            
            return deviceCell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.ParameterCell, for: indexPath)
            if let paramCell = cell as? ParameterTableViewCell, let param = parameters?[indexPath.row]  {
                paramCell.parameter = param
            }
            return cell
        }
    }
    
    private struct Storyboard {
        static let ParameterCell = "Parameter Cell"
        static let DeviceCell = "Device Title Cell"
    }
    

}
