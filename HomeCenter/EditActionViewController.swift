//
//  EditActionViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 11/15/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class EditActionViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Public API
    
    var action: Action? { didSet { updateUI()} }
    
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
    
    private var actionName: String {
        get {
            return action?.name ?? ""
        }
        set {
            managedObjectContext?.performAndWait {
                action?.name = newValue
            }
        }
    }
    
    private var actionCommands: [ActionCommand] {
        get {
            if let action = action, let commands = action.commands {
                return commands.allObjects as? [ActionCommand] ?? []
            } else {
                return []
            }
            
        }
    }
    
    private lazy var devices: [Device] = {
        if let context = managedObjectContext {
            var devices: [Device] = []
            context.performAndWait {
                let request: NSFetchRequest<Device> = Device.fetchRequest()
                if let matches = try? context.fetch(request) {
                    devices = matches
                }
            }
            return devices
        }
        return []
    }()
    
    private var selectedDevice: Device? {
        didSet {
            if let _ = selectedDevice {
                paramPicker?.reloadComponent(PickerComponentNumbers.paramComponent)
                if parameters.count > 0 {
                    selectedParam = parameters[0]
                }
            }
        }
    }
    
    private var selectedParam: Parameter? {
        didSet {
            //Change Keyboard Type
            if let param = selectedParam {
                if param.type == "number" {
                    valueTextField?.keyboardType = .numberPad
                } else {
                    valueTextField?.keyboardType = .asciiCapable
                }
            }
        }
    }
    
    private var parameters: [Parameter] {
        get {
            return selectedDevice?.parameters?.allObjects as? [Parameter] ?? []
        }
    }
    
    private var isAddingCommand = false { didSet { updateUI() } }
    
    private var managedObjectContext: NSManagedObjectContext? {
        get {
            return action?.managedObjectContext
        }
    }

    // MARK: - Outlets
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var nameTextField: UITextField! { didSet { nameTextField?.delegate = self }}
    @IBOutlet weak var paramPicker: UIPickerView! { didSet { paramPicker?.delegate = self; paramPicker?.dataSource = self }}
    @IBOutlet weak var valueTextField: UITextField! {didSet { valueTextField?.delegate = self } }
    @IBOutlet weak var pickerStackView: UIStackView!
    @IBOutlet weak var addCommandButton: UIButton!
    @IBOutlet weak var cancelAddCommandButton: UIButton!
    @IBOutlet weak var doneAddCommandButton: UIButton!
    @IBOutlet weak var commandsTableView: UITableView! { didSet { commandsTableView?.delegate = self; commandsTableView?.dataSource = self }}
    
    // MARK: - UI
    
    private func updateUI() {
        if isAddingCommand {
            pickerStackView?.isHidden = false
            cancelAddCommandButton?.isHidden = false
            doneAddCommandButton?.isHidden = false
            addCommandButton?.isHidden = true
        } else {
            pickerStackView?.isHidden = true
            cancelAddCommandButton?.isHidden = true
            doneAddCommandButton?.isHidden = true
            addCommandButton?.isHidden = false
        }
        commandsTableView?.reloadData()
    }
    
    // MARK: Keyboard
    
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
    
    // MARK: - Actions
    
    @IBAction func addCommandPressed() {
        selectedDevice = (devices.count > 0) ? devices[0] : nil
        paramPicker.selectRow(0, inComponent: PickerComponentNumbers.deviceComponent, animated: false)
        valueTextField?.text = ""
        isAddingCommand = true
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        valueTextField?.resignFirstResponder()
        isAddingCommand = false
    }
    
    @IBAction func donePressed() {
        valueTextField?.resignFirstResponder()
        addNewParam()
        isAddingCommand = false
        updateUI()
    }
    
    private func addNewParam() {
        if let context = managedObjectContext, let param = selectedParam, action != nil {
            context.performAndWait {
                let command = ActionCommand(context: context)
                command.paramID = param.uuid
                command.parameter = param
                command.action = action
                command.paramValue = valueTextField?.text
            }
        }
    }
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == PickerComponentNumbers.deviceComponent {
            return devices.count
        } else {
            return parameters.count
        }
    }
    
    // MARK: - UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == PickerComponentNumbers.deviceComponent {
            return devices[row].name ?? "<No Name>"
        } else {
            return parameters[row].name ?? "<No Name>"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        valueTextField?.resignFirstResponder()
        if component == PickerComponentNumbers.deviceComponent {
            selectedDevice = devices[row]
        } else {
            selectedParam = parameters[row]
        }
    }
    
    private struct PickerComponentNumbers {
        static let deviceComponent = 0
        static let paramComponent = 1
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //print("Count is \(actionCommands.count)")
        return actionCommands.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.commandCell, for: indexPath)
        
        let command = actionCommands[indexPath.row]
        if let param = command.parameter, let paramName = param.name, let deviceName = param.device?.name, let setValue = command.paramValue {
            cell.textLabel?.text = "Set \(deviceName):\(paramName) to \(setValue)"
        } else {
            cell.textLabel?.text = "Incomplete command"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") {[weak self] (rowAction, indexPath) in
            self?.deleteCommand(at: indexPath.row)
        }
        
        return [deleteAction]
    }
    
    func deleteCommand(at row: Int) {
        if let context = managedObjectContext {
            context.performAndWait {
                if let action = action {
                    let command = actionCommands[row]
                    action.removeFromCommands(command)
                    context.delete(command)
                }
            }
            commandsTableView?.reloadData()
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == nameTextField {
            actionName = nameTextField?.text ?? ""
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    private struct Storyboard {
        static let commandCell = "Action Command Cell"
    }
    
}
