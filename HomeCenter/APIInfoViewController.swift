//
//  APIInfoViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/26/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit

class APIInfoViewController: UIViewController, UITextFieldDelegate {

    // MARK: - PublicAPI
    
    var apiKey: String? = KeychainAccess.retrieveAPIKey()
    var apiUrl: String? = KeychainAccess.retrieveAPIUrl()
    
    
    // MARK: Outlets
    
    @IBOutlet weak var apiUrlTextField: UITextField! { didSet { apiUrlTextField.delegate = self }}
    @IBOutlet weak var apiKeyTextField: UITextField! { didSet { apiKeyTextField.delegate = self }}
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        apiUrlTextField.becomeFirstResponder()
    }
    
    // MARK: - UI Methods
    
    private func updateUI() {
        apiUrlTextField.text = apiUrl ?? ""
        apiKeyTextField.text = apiKey ?? ""
    }
    
    private func setAPIValues() {
        KeychainAccess.setAPIUrl(with: apiUrl ?? "")
        KeychainAccess.setAPIKey(with: apiKey ?? "")
    }

    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == apiUrlTextField {
            apiUrl = textField.text
        } else if textField == apiKeyTextField {
            apiKey = textField.text 
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Storyboard.unwindSegueIdentifier {
            apiUrl = apiUrlTextField.text
            apiKey = apiKeyTextField.text
            setAPIValues()
        }
    }

    // MARK: Constants
    
    private struct Storyboard {
        static let unwindSegueIdentifier = "Done Editing"
    }

}
