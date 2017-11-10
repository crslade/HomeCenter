//
//  EditDeviceViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/7/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class EditDeviceViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {

    // MARK: Public API
    
    var device: Device? { didSet { updateUI() } }
    
    var deviceName: String? {
        get { return device?.name ?? "" }
        set {
            device?.managedObjectContext?.performAndWait {
                device?.name = newValue
            }
        }
    }
    
    var deviceType: String? {
        get { return device?.type ?? "" }
    }
    
    var jsonUrl: String? {
        get { return device?.jsonUrl ?? "" }
        set {
            device?.jsonUrl = newValue
        }
    }
    
    var deviceRoom: Room? {
        get { return device?.room }
        set {
            device?.managedObjectContext?.performAndWait {
                device?.room = newValue
            }
        }
    }
    
    var propertyCount: Int {
        get { return 0 }
    }
    
    var isNew: Bool {
        get {
            if let _ = device?.uuid {
                return false
            } else {
                return true
            }
        }
    }
    
    
    // MARK: - Outlets
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var nameTextField: UITextField! { didSet { nameTextField?.delegate = self } }
    @IBOutlet weak var jsonURLTextField: UITextField! { didSet { jsonURLTextField?.delegate = self } }
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadPropertiesControls: UIStackView!
    @IBOutlet weak var roomPicker: UIPickerView! { didSet { roomPicker?.dataSource = self; roomPicker?.delegate = self; roomPicker?.showsSelectionIndicator = true } }
    @IBOutlet weak var editDeviceControls: UIStackView!
    @IBOutlet weak var deviceTypeLabel: UILabel!
    @IBOutlet weak var propertiesCountLabel: UILabel!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    // MARK: - Lifecycle Methods and Data
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Listen to Keyboard Notifications
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard(notification:)), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard(notification:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
        //Tap Gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        updateUI()
    }
    
    private lazy var rooms: [Room] = {
        if let context = device?.managedObjectContext {
            let request: NSFetchRequest<Room> = Room.fetchRequest()
            request.sortDescriptors = [ NSSortDescriptor(key: "name", ascending: true)]
            if var matches = try? context.fetch(request) {
                return matches
            }
        }
        return []
    }()

    private func positionOf(room: Room?) -> Int {
        if let room = room {
            var pos = 0
            for rm in rooms {
                pos += 1
                if rm == room {
                    return pos
                }
            }
        }
        return 0
    }
    
    // MARK: - UI
    
    private func updateUI() {
        print("Updating UI")
        
        //Set right title
        if isNew {
            self.navigationItem.title =  "Add Device"
            jsonURLTextField?.text = jsonUrl
        } else {
            self.navigationItem.title =  "Edit Device"
            device?.loadedProperties = true
        }
        //Show/Hide controls
        if let dev = device, dev.loadedProperties {
            loadPropertiesControls?.isHidden = true
            editDeviceControls?.isHidden = false
            doneButton?.isEnabled = true
        } else if let _ = device {
            doneButton?.isEnabled = false
            loadPropertiesControls?.isHidden = false
            editDeviceControls?.isHidden = true
        }
        //Update Labels and Fields
        nameTextField?.text = deviceName
        deviceTypeLabel?.text = deviceType
        propertiesCountLabel?.text = "\(propertyCount)"
        roomPicker?.selectRow(positionOf(room: device?.room), inComponent: 0, animated: false)
    }

    @objc func adjustForKeyboard(notification: Notification) {
        if notification.name == Notification.Name.UIKeyboardWillHide {
            scrollView?.contentInset.bottom = 0
        } else if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            scrollView?.contentInset.bottom = keyboardSize.height
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextFieldDidEndEditingReason) {
        print("Ended Editing")
        if textField == nameTextField {
            deviceName = textField.text
        }
        if textField == jsonURLTextField {
            jsonUrl = textField.text
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    // MARK: - UIPickerViewDelegate
    
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if row == 0 {
            return "<No Room>"
        } else {
            return rooms[row-1].name ?? "<Room Has No Name>"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row == 0 {
            deviceRoom = nil
        } else {
            deviceRoom = rooms[row - 1]
        }
    }
    
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return rooms.count+1
    }
    
    // MARK: - Actions
    
    @IBAction func loadJson() {
        self.activityIndicator?.startAnimating()
        jsonUrl = self.jsonURLTextField?.text
        device?.loadJsonProperties() {[weak self] (error) in
            if let error = error {
                print("Error getting data: \(error)")
                DispatchQueue.main.async {
                    self?.activityIndicator?.stopAnimating()
                    self?.presentErrorAlert(withMessage: "Error Downloading Properties.")
                }
            } else {
                DispatchQueue.main.async {
                    self?.activityIndicator?.stopAnimating()
                    self?.updateUI()
                }
            }
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Storyboard.DoneEditSegue {
            deviceName = nameTextField?.text
            jsonUrl = jsonURLTextField?.text
        }
    }

    struct Storyboard {
        static let DoneEditSegue = "Done Edit"
    }

}
