//
//  AddDeviceViewController.swift
//  HomeCenter
//
//  Created by Christopher Slade on 12/15/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

// TEST URL
//  https://gist.githubusercontent.com/crslade/c7dc7368d9073180460017ff1896e055/raw/2fadfd088acffbd8a79cc46a924be353c499d072/hvacAll.json

import UIKit
import CoreData

class AddDeviceViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: - Public API
    
    var container: NSPersistentContainer? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer
    
    // MARK: - Private Data
    
    var devicesJson: [Any]?
    var actionsJson: [Any]?
    var conditionsJson: [Any]?
    
    var devices: [Device] = []
    var actions: [Action] = []
    var conditions: [Condition] = []
    
    // MARK: - Outlets
    
    @IBOutlet weak var jsonURL: UITextField! { didSet { jsonURL.delegate = self } }
    @IBOutlet weak var loadPropertiesButton: UIButton!
    @IBOutlet weak var deviceCount: UILabel!
    @IBOutlet weak var actionCount: UILabel!
    @IBOutlet weak var conditionCount: UILabel!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    // MARK: - Data
    
    private func loadData() {
        if let urlString = jsonURL?.text {
            HomeFetcher.fetchDeviceJson(at: urlString) {[weak self] (deviceData, error) in
                if let error = error {
                    print("Error Fetching JSON: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Error Downloading JSON, check URL.")
                    }
                } else if let deviceDict = deviceData {
                    print("JSON: \(deviceDict)")
                    self?.devicesJson = deviceDict[JsonKeys.devices] as? [Any]
                    self?.actionsJson = deviceDict[JsonKeys.actions] as? [Any]
                    self?.conditionsJson = deviceDict[JsonKeys.conditions] as? [Any]
                    DispatchQueue.main.async { [weak self] in
                        //disable cancel, too late to cancel
                        self?.cancelButton.isEnabled = false
                        self?.updateUI()
                    }
                    self?.container?.performBackgroundTask() { (context) in
                        self?.createAndSaveProperties(in: context)
                    }
                }
            }
        }
    }
    
    private func createAndSaveProperties(in context: NSManagedObjectContext) {
        if devicesJson != nil, actionsJson != nil, conditionsJson != nil {
            createDevices(in: context) { [weak self] (error) in
                if let error = error {
                    print("Error creating devices: \(error)")
                    DispatchQueue.main.async {
                        self?.presentErrorAlert(withMessage: "Error Creating Devices.")
                    }
                } else {
                    self?.createActions(in: context) { [weak self] (error) in
                        if let error = error {
                            print("Error creating actions: \(error)")
                            self?.presentErrorAlert(withMessage: "Error Creating Actions.")
                        } else {
                            //create conditions here.
                            DispatchQueue.main.async {
                                self?.updateUI()
                            }
                            context.perform {
                                do {
                                    try context.save()
                                } catch {
                                    print("Error saving context: \(error)")
                                    DispatchQueue.main.async {
                                        self?.presentErrorAlert(withMessage: "Error saving data locally.")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func createActions(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        if actionsJson != nil, let actionDict = actionsJson!.popLast() {
            if let action = actionDict as? [String: Any], let actionName = action[JsonKeys.actionName] {
                if let commands = action[JsonKeys.commands] as? [Any] {
                    var newAction: [String: Any] = [JsonKeys.actionName : actionName]
                    var newCommands: [Any] = []
                    for commandDict in commands {
                        if var command = commandDict as? [String: Any] {
                            if let paramName = command[JsonKeys.paramID] as? String, let paramValue = command[JsonKeys.paramValue] {
                                let paramId = findParamId(for: paramName)
                                if paramId != "" {
                                    let newCommand: [String: Any] = [JsonKeys.paramID: paramId, JsonKeys.paramValue: paramValue]
                                    newCommands.append(newCommand)
                                } else {
                                    completionHandler(HomeFetcherError.MissingAPIValues("Param not found."))
                                    return
                                }
                            }
                        }
                    }
                    newAction[JsonKeys.commands] = newCommands
                    //print("\(newAction)")
                    context.perform { [weak self] in
                        let action = Action(context: context)
                        action.applyJson(with: newAction)
                        action.saveToAPI(){ (error) in
                            if let error = error {
                                completionHandler(error)
                                return
                            } else {
                                print("Action Saved")
                                self?.actions.append(action)
                                self?.createActions(in: context, with: completionHandler)
                            }
                        }
                    }
                }
            }
        } else {
            completionHandler(nil)
        }
    }
    
    private struct JsonKeys {
        static let devices = "devices"
        static let actions = "actions"
        static let conditions = "conditions"
        static let deviceName = "deviceName"
        static let actionName = "actionName"
        static let commands = "actionCommands"
        static let paramID = "paramID"
        static let paramValue = "paramValue"
    }
    
    private func findParamId(for name: String) -> String {
        for dev in devices {
            if let devParams = dev.parameters {
                for param in devParams {
                    if let parameter = param as? Parameter, let paramName = parameter.name, name == paramName, let uuid = parameter.uuid {
                        return uuid
                    }
                }
            }
        }
        return ""
    }
    
    private func createDevices(in context: NSManagedObjectContext, with completionHandler: @escaping (Error?) -> Void) {
        if devicesJson != nil, let devDict = devicesJson!.popLast() {
            if let dev = devDict as? [String: Any] {
                let name = dev[JsonKeys.deviceName] ?? "<No Name>"
                print(name)
                context.perform {
                    let device = Device(context: context)
                    device.applyJsonProperties(with: dev)
                    device.saveToAPI() { [weak self] (error) in
                        if let error = error {
                            completionHandler(error)
                        } else {
                            print("Adding device")
                            self?.devices.append(device)
                            self?.createDevices(in: context, with: completionHandler)
                        }
                    }
                }
            }
        } else {
            //basis case call the closure with no error
            completionHandler(nil)
        }
    }
    
    // MARK: UI
    
    private func updateUI() {
        deviceCount?.text = "\(devices.count)"
        actionCount?.text = "\(actions.count)"
        conditionCount?.text = "\(conditions.count)"
    }
    
    // MARK: - Actions
    
    @IBAction func loadPropertiesPressed() {
        loadData()
    }
    
    // MARK: - UITextFieldDelegate
    
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

}
