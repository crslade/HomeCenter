//
//  ConditionViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 12/5/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit

class ConditionViewController: UIViewController {
    
    // MARK: - Public API
    
    var condition: Condition? { didSet { updateUI() } }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        // Do any additional setup after loading the view.
    }
    
    // MARK: - UI
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var comparisonLabel: UILabel!
    @IBOutlet weak var toleranceLabel: UILabel!
    @IBOutlet weak var actionLabel: UILabel!
    
    private func updateUI() {
        if let condition = condition {
            nameLabel?.text = condition.name ?? "<No Name>"
            typeLabel?.text = condition.comparisonType ?? ""
            comparisonLabel?.text = comparisonText()
            toleranceLabel?.text = condition.tolerance ?? "0"
            actionLabel?.text = condition.action?.name ?? ""
        }
    }
    
    private func comparisonText() -> String {
        var text = ""
        if let condition = condition {
            if let type = condition.comparisonType, type == "dynamic" {
                if let param = condition.parameter?.name, let comparison = condition.comparison, let compParam = condition.compParameter?.name {
                    text = "\(param) \(comparison) \(compParam)"
                }
            } else {
                if let param = condition.parameter?.name, let comparison = condition.comparison, let value = condition.comparisonValue {
                    text = "\(param) \(comparison) \(value)"
                }
            }
        }
        return text
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
