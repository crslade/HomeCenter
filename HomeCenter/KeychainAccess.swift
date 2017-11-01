//
//  KeychainAccess.swift
//  HomeCenter
//
//  Some code copied from Stackoverflow at: https://stackoverflow.com/questions/25513106/trying-to-use-keychainitemwrapper-by-apple-translated-to-swift
//  
//  Created by Christopher Slade on 10/26/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit
import Security

let kSecClassGenericPasswordValue = String(format: kSecClassGenericPassword as String)
let kSecClassValue = String(format: kSecClass as String)
let kSecAttrServiceValue = String(format: kSecAttrService as String)
let kSecValueDataValue = String(format: kSecValueData as String)
let kSecMatchLimitValue = String(format: kSecMatchLimit as String)
let kSecReturnDataValue = String(format: kSecReturnData as String)
let kSecMatchLimitOneValue = String(format: kSecMatchLimitOne as String)
let kSecAttrAccountValue = String(format: kSecAttrAccount as String)

class KeychainAccess {
    
    class func retrieveAPIKey() -> String? {
        return getPasscode(for: KeychainIdentifiers.APIKey)
    }
    
    class func retrieveAPIUrl() -> String? {
        return getPasscode(for: KeychainIdentifiers.APIUrl)
    }
    
    class func setAPIKey(with apiKey: String) {
        setPasscode(for:  KeychainIdentifiers.APIKey, with: apiKey)
    }
    
    class func setAPIUrl(with apiUrl: String) {
        setPasscode(for: KeychainIdentifiers.APIUrl, with: apiUrl)
    }
    
    class func clearAPIValues() {
        deletePasscode(identifier: KeychainIdentifiers.APIKey)
        deletePasscode(identifier: KeychainIdentifiers.APIUrl)
    }
    
    private struct KeychainIdentifiers {
        static let APIKey = "X-API-KEY"
        static let APIUrl = "API-URL"
    }
    
    private class func setPasscode(for identifier: String, with passcode: String) {
        if let dataFromString = passcode.data(using: String.Encoding.utf8) {
            let keychainQuery = [
                kSecClassValue: kSecClassGenericPasswordValue,
                kSecAttrServiceValue: identifier,
                kSecValueDataValue: dataFromString
                ] as CFDictionary
            SecItemDelete(keychainQuery)
            print(SecItemAdd(keychainQuery, nil))
        }
    }
    
    private class func getPasscode(for identifier: String) -> String? {
        let keychainQuery = [
            kSecClassValue: kSecClassGenericPasswordValue,
            kSecAttrServiceValue: identifier,
            kSecReturnDataValue: kCFBooleanTrue,
            kSecMatchLimitValue: kSecMatchLimitOneValue
            ] as  CFDictionary
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        var passcode: String?
        if (status == errSecSuccess) {
            if let retrievedData = dataTypeRef as? Data,
                let result = String(data: retrievedData, encoding: String.Encoding.utf8) {
                passcode = result as String
            }
        }
        else {
            print("Nothing was retrieved from the keychain. Status code \(status)")
        }
        return passcode
    }
    
    private class func deletePasscode(identifier: String) {
        let keychainQuery = [
            kSecClassValue: kSecClassGenericPasswordValue,
            kSecAttrServiceValue: identifier//,
            //kSecValueDataValue: ""
            ] as CFDictionary
        SecItemDelete(keychainQuery)
    }
}
