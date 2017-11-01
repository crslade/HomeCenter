//
//  EditRoomViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/30/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit

class EditRoomViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Public API
    
    var room: Room? { didSet { updateUI()} }
    
    var roomName: String {
        get {
            return room?.name ?? ""
        }
        set {
            room?.managedObjectContext?.performAndWait { [weak self] in
                self?.room?.name = newValue
            }
        }
    }
    
    // MARK: - Outlets
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField! { didSet{ nameTextField.delegate = self }}
   
    
    // MARK: - Lifecycle Methods
    
    var isNew: Bool {
        get {
            if let _ = room?.uuid {
                return true
            } else {
                return false
            }
         }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    // MARK: - UI Methods
    
    private func updateUI() {
        titleLabel?.text = isNew ? "Add Room" : "Edit Room"
        nameTextField?.text = roomName
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidEndEditing(_ textField: UITextField) {
            roomName = nameTextField?.text ?? ""
    }
    
    
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Storyboard.doneEditingSegue {
            roomName = nameTextField?.text ?? ""
        }
     }
    
    struct Storyboard {
        static let doneEditingSegue = "Done Editing"
    }
}
