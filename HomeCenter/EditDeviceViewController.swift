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
    
    var deviceRoom: Room? {
        get { return device?.room }
        set {
            device?.managedObjectContext?.performAndWait {
                device?.room = newValue
            }
        }
    }
    
    var paramCount: Int {
        get {
                return device?.parameters?.count ?? 0
        }
    }
    
    
    
    // MARK: - Outlets
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var nameTextField: UITextField! { didSet { nameTextField?.delegate = self } }
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var roomPicker: UIPickerView! { didSet { roomPicker?.dataSource = self; roomPicker?.delegate = self; roomPicker?.showsSelectionIndicator = true } }
    @IBOutlet weak var deviceTypeLabel: UILabel!
    @IBOutlet weak var paramCountLabel: UILabel!
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
        self.navigationItem.title =  "Edit Device"
        //Update Labels and Fields
        nameTextField?.text = deviceName
        deviceTypeLabel?.text = deviceType
        paramCountLabel?.text = "\(paramCount)"
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
    

    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Storyboard.DoneEditSegue {
            deviceName = nameTextField?.text
        }
    }

    struct Storyboard {
        static let DoneEditSegue = "Done Edit"
    }

}
