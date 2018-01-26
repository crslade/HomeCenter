//
//  EditConditionViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 12/5/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import CoreData

class EditConditionViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {

    // MARK: - Public api
    
    var condition: Condition? { didSet { updateUI() } }
    
    
    // MARK: - Lifecycle Methods and Data
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard(notification:)), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard(notification:)), name: Notification.Name.UIKeyboardDidHide, object: nil)
        //Tap Gesture to dismiss kayboard and pickers
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardAndPickers))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        updateUI()
    }
    
    private var manaagedObjectContext: NSManagedObjectContext? {
        get {
            return condition?.managedObjectContext
        }
    }
    
    private var conditionName: String {
        get {
            return condition?.name ?? ""
        }
        set {
            manaagedObjectContext?.performAndWait {
                condition?.name = newValue
            }
        }
    }
    
    private var parameterName: String {
        get {
            if let param = condition?.parameter, let devName = param.device?.name, let paramName = param.name {
                return "\(devName) -> \(paramName)"
            } else {
                return ""
            }
        }
    }
    
    private var actionName: String {
        get {
            if let actionName = condition?.action?.name {
                return actionName
            } else {
                return ""
            }
        }
    }
    
    private var comparisonType: String {
        get {
            if let condition = condition, condition.comparisonType == nil {
                condition.comparisonType = "static"
            }
            return condition?.comparisonType ?? "static"
        }
        set {
            manaagedObjectContext?.performAndWait {
                condition?.comparisonType = newValue
            }
        }
    }
    
    private var comparison: String {
        get {
            return condition?.comparison ?? "="
        }
        set {
            manaagedObjectContext?.performAndWait {
                condition?.comparison = newValue
            }
        }
    }
    
    private var tolerance: String {
        get {
            return condition?.tolerance ?? ""
        }
        set {
            manaagedObjectContext?.performAndWait {
                condition?.tolerance = newValue
            }
        }
    }
    
    private var compValue: String {
        get {
            return condition?.comparisonValue ?? ""
        }
        set {
            manaagedObjectContext?.performAndWait {
                condition?.comparisonValue = newValue
            }
        }
    }
    
    private var compParamName: String {
        get {
            if let param = condition?.compParameter, let devName = param.device?.name, let paramName = param.name {
                return "\(devName) -> \(paramName)"
            } else {
                return ""
            }
        }
    }

    // MARK: - UI and Outlets
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var nameTextField: UITextField! {
        didSet {
            nameTextField?.delegate = self
            nameTextField?.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        }
        
    }
    @IBOutlet weak var toleranceTextField: UITextField! {
        didSet {
            toleranceTextField?.delegate = self
            toleranceTextField?.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        }
    }
    @IBOutlet weak var typeSegmentedControl: UISegmentedControl! {
        didSet {
            typeSegmentedControl?.addTarget(self, action: #selector(typeSegmentChanged), for: .valueChanged)
        }
    }
    @IBOutlet weak var parameterTextField: UITextField! { didSet {parameterTextField?.delegate = self } }
    @IBOutlet weak var actionTextField: UITextField! { didSet { actionTextField?.delegate = self } }
    @IBOutlet weak var parameterPicker: UIPickerView! { didSet { parameterPicker?.delegate = self; parameterPicker?.dataSource = self } }
    @IBOutlet weak var actionPicker: UIPickerView! { didSet {actionPicker?.delegate = self; actionPicker?.dataSource = self }}
    @IBOutlet weak var comparisonSegmentedControl: UISegmentedControl! {
        didSet {
            comparisonSegmentedControl?.addTarget(self, action: #selector(comparisonSegmentChanged), for: .valueChanged)
        }
    }
    @IBOutlet weak var staticStackView: UIStackView!
    @IBOutlet weak var dynamicStackView: UIStackView!
    @IBOutlet weak var compValueTextField: UITextField! {
        didSet {
            compValueTextField?.delegate = self
            compValueTextField?.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        }
    }
    @IBOutlet weak var compParamenterTextField: UITextField! { didSet {compParamenterTextField?.delegate = self} }
    
    private var isPickingParameter: Bool = false { didSet{ updateUI() } }
    private var isPickingAction: Bool = false { didSet{ updateUI() } }
    
    private enum EditingParameter {
        case parameter
        case compParameter
    }
    private var editingParameter: EditingParameter = .parameter
    
    private func updateUI() {
        //set values
        nameTextField?.text = conditionName
        parameterTextField?.text = parameterName
        toleranceTextField?.text = tolerance
        actionTextField?.text = actionName
        compParamenterTextField?.text = compParamName
        updateDisplayType()
        updateComparison()
        //state
        parameterPicker?.isHidden = !isPickingParameter
        actionPicker?.isHidden = !isPickingAction
    }
    
    private func updateDisplayType() {
        if comparisonType == "static" {
            typeSegmentedControl?.selectedSegmentIndex = SegmentSelections.staticComparison
            staticStackView?.isHidden = false
            dynamicStackView?.isHidden = true
        } else {
            typeSegmentedControl?.selectedSegmentIndex = SegmentSelections.dynamicComparison
            dynamicStackView?.isHidden = false
            staticStackView?.isHidden = true
        }
    }
    
    private func updateComparison() {
        switch comparison {
        case ">":
            comparisonSegmentedControl?.selectedSegmentIndex = SegmentSelections.greaterComp
        case "<":
            comparisonSegmentedControl?.selectedSegmentIndex = SegmentSelections.lessComp
        default:
            comparisonSegmentedControl?.selectedSegmentIndex = SegmentSelections.equalComp
        }
    }
    
    @objc func typeSegmentChanged() {
        comparisonType = (typeSegmentedControl?.selectedSegmentIndex == SegmentSelections.staticComparison) ? "static" : "dynamic"
        updateUI()
    }
    
    @objc func comparisonSegmentChanged() {
        switch comparisonSegmentedControl?.selectedSegmentIndex ?? 0 {
        case SegmentSelections.greaterComp:
            comparison = ">"
        case SegmentSelections.lessComp:
            comparison = "<"
        default:
            comparison = "="
        }
    }
    
    struct SegmentSelections {
        static let staticComparison = 0
        static let dynamicComparison = 1
        static let equalComp = 0
        static let greaterComp = 1
        static let lessComp = 2
    }
    
    // MARK: - Keyboard and Pickers
    
    @objc func dismissKeyboardAndPickers() {
        view?.endEditing(true)
        dismissPickers()
    }
    
    @objc func adjustForKeyboard(notification: Notification) {
        if notification.name == Notification.Name.UIKeyboardWillHide {
            scrollView?.contentInset.bottom = 0
        } else if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            scrollView?.contentInset.bottom = keyboardSize.height
        }
    }
    
    private func dismissPickers() {
        isPickingAction = false
        isPickingParameter = false
    }
    
    private func setSelectedAction() {
        if let currentAction = condition?.action {
            var pos = 0
            for action in actions {
                if action == currentAction {
                   actionPicker.selectRow(pos, inComponent: 0, animated: false)
                }
                pos += 1
            }
        }
    }
    
    private func setSelectedParameter() {
        let param = (editingParameter == .parameter) ? condition?.parameter : condition?.compParameter
        if let currentParam = param, let currentDevice = currentParam.device {
            //selectDevice
            var pos = 0
            for device in devices {
                if currentDevice == device {
                    parameterPicker.selectRow(pos, inComponent: PickerComponentNumbers.deviceComponent, animated: false)
                    selectedDevice = device
                }
                pos += 1
            }
            //selectParam
            pos = 0
            for param in parameters {
                if currentParam == param {
                    parameterPicker.selectRow(pos, inComponent: PickerComponentNumbers.paramComponent, animated: false)
                }
                pos += 1
            }
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    //Decides if it should show a keyboard or picker
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == parameterTextField {
            if editingParameter == .parameter {
                isPickingParameter = !isPickingParameter
            } else {
                isPickingParameter = true
            }
            editingParameter = .parameter
            isPickingAction = false
            setSelectedParameter()
            view?.endEditing(true)
            return false
        } else if textField == actionTextField {
            isPickingAction = !isPickingAction
            isPickingParameter = false
            setSelectedAction()
            view?.endEditing(true)
            return false
        } else if textField == compParamenterTextField {
            if editingParameter == .compParameter {
                isPickingParameter = !isPickingParameter
            } else {
                isPickingParameter = true
            }
            editingParameter = .compParameter
            isPickingAction = false
            setSelectedParameter()
            view?.endEditing(true)
            return false
        } else {
            dismissPickers()
            return true
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        if textField == nameTextField {
            conditionName = nameTextField?.text ?? ""
        }
        if textField == toleranceTextField {
            tolerance = toleranceTextField?.text ?? ""
        }
        if textField == compValueTextField {
            compValue = compValueTextField?.text ?? ""
        }
    }
    
    // MARK: - UIPickerViewDataSource
    
    private lazy var devices: [Device] = {
        var devices: [Device] = []
        if let context = manaagedObjectContext {
            context.performAndWait {
                let request: NSFetchRequest<Device> = Device.fetchRequest()
                if let matches = try? context.fetch(request) {
                    devices = matches
                }
            }
        }
        return devices
    }()
    
    private lazy var actions: [Action] = {
        var actions: [Action] = []
        if let context = manaagedObjectContext {
            context.performAndWait {
                let request: NSFetchRequest<Action> = Action.fetchRequest()
                if let matches = try? context.fetch(request) {
                    actions = matches
                }
            }
        }
        return actions
    }()
    
    private var selectedDevice: Device? {
        didSet {
            if let _ = selectedDevice {
                parameterPicker?.reloadComponent(PickerComponentNumbers.paramComponent)
            }
        }
    }
    
    private var parameters: [Parameter] {
        get {
            return selectedDevice?.parameters?.allObjects as? [Parameter] ?? []
        }
    }
    
    private var selectedParam: Parameter? {
        didSet {
            manaagedObjectContext?.performAndWait {
                if editingParameter == .parameter {
                    condition?.parameter = selectedParam
                } else {
                    condition?.compParameter = selectedParam
                }
            }
            updateUI()
        }
    }
    
    private var selectedAction: Action? {
        didSet {
            condition?.action = selectedAction
            updateUI()
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        if pickerView == parameterPicker {
            return 2
        } else {
            return 1
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == parameterPicker {
            if component == PickerComponentNumbers.deviceComponent {
                return devices.count
            } else {
                return parameters.count
            }
        } else {
            return actions.count
        }
    }
    
    // MARK: UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == parameterPicker {
            if component == PickerComponentNumbers.deviceComponent {
                return devices[row].name ?? "<No Name>"
            } else {
                return parameters[row].name ?? "<No Name>"
            }
        } else {
            return actions[row].name ?? "<No Name>"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == parameterPicker {
            if component == PickerComponentNumbers.deviceComponent {
                selectedDevice = devices[row]
            } else {
                selectedParam = parameters[row]
            }
        } else {
            selectedAction = actions[row]
        }
    }
    
    private struct PickerComponentNumbers {
        static let deviceComponent = 0
        static let paramComponent = 1
    }

}
