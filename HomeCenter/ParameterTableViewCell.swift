//
//  ParameterTableViewCell.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/13/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class ParameterTableViewCell: UITableViewCell, UITextFieldDelegate {
    
    //MARK: - Public API
    
    var parameter: Parameter? { didSet { updateUI() }}
    
    var paramValue: String {
        get {
            return parameter?.value ?? ""
        }
        set {
            parameter?.managedObjectContext?.performAndWait {
                parameter?.value = newValue
            }
        }
    }
    
    // MARK: - Outlets
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var actionsLabel: UILabel!
    @IBOutlet weak var valueTextField: UITextField! {
        didSet {
            valueTextField.delegate = self
            addDoneButton()
        }
    }
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    
    // MARK: - UI
    
    private func updateUI() {
        if let param = parameter {
            nameLabel?.text = param.name
            valueTextField?.text = paramValue
            if param.type == "number" {
                valueTextField?.keyboardType = .numberPad
            } else {
                valueTextField?.keyboardType = .asciiCapable
                
            }
            if param.actions == "read" {
                actionsLabel?.text = "Read Only"
                valueTextField?.isEnabled = false
            } else {
                actionsLabel?.text = ""
                valueTextField?.isEnabled = true
            }
        }
    }
    
    private func addDoneButton() {
        let toolbar = UIToolbar.init()
        toolbar.sizeToFit()
        let doneBtn = UIBarButtonItem.init(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
        toolbar.items = [doneBtn]
        valueTextField?.inputAccessoryView = toolbar
    }
    
    @objc func donePressed() {
        valueTextField?.resignFirstResponder()
    }
    
    // MARK: - UITextFieldDelegate
    
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        paramValue = valueTextField?.text ?? ""
                self.activityIndicator?.startAnimating()
        parameter?.saveToAPI() { (error) in
            if let error = error {
                print("Error saving: \(error)")
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator?.stopAnimating()
                }
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

}
