//
//  HomeFetcher.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/23/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit

class HomeFetcher: NSObject
{
    // MARK: - API URL and KEY
    
    class func APIvaluesSet() -> Bool {
        if let _ = KeychainAccess.retrieveAPIKey(), let _ = KeychainAccess.retrieveAPIUrl() {
            return true
        }
        return false
    }
    
    // MARK: - Rooms
    
    class func fetchRooms(completionHandler: @escaping ([Any]?, Error?) -> Void) {
        fetchArray(for: "/rooms", with: completionHandler)
    }
    
    class func deleteRoom(withUUID uuid: String, with completionHandler: @escaping (Error?) -> Void) {
        sendDelete(for: "/rooms/"+uuid, with: completionHandler)
    }
    
    class func addRoom(_ roomData: String, with completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        sendRequest(withData: roomData, toPath: "/rooms", withMethod: "POST", with: completionHandler) 
    }
    
    class func editRoom(withID uuid: String, roomData: String, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        sendRequest(withData: roomData, toPath: "/rooms/"+uuid, withMethod: "PATCH", with: completionHandler)
    }
    
    // MARK: - Devices
    
    class func fetchDeviceJson(at fullURL: String, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        guard let url = URL(string: fullURL) else {
            print("Could not form URL")
            completionHandler(nil,HomeFetcherError.URLError("Could not create URL"))
            return
        }
        (URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Error downloading Data")
                completionHandler(nil, error)
            } else if let response = response as? HTTPURLResponse, let data = data {
                if response.statusCode == 200 {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let jsonDict = json as? [String: Any] {
                            completionHandler(jsonDict,nil)
                        } else {
                            print("Didn't get JSON object back")
                            completionHandler(nil, HomeFetcherError.DownloadError("Expected JSON Object"))
                        }
                    } catch {
                        print("JSON Parse Error: \(error)")
                        completionHandler(nil,error)
                    }
                } else {
                    completionHandler(nil,HomeFetcherError.DownloadError("Requset return response code \(response.statusCode)"))
                }
            }
        }).resume()
        
    }
    
    class func fetchDevices(for roomUUID: String, completionHandler: @escaping ([Any]?, Error?) -> Void) {
        fetchArray(for: "/rooms/\(roomUUID)/devices", with: completionHandler)
    }
    
    class func fetchDevices(completionHandler: @escaping ([Any]?, Error?) -> Void) {
        fetchArray(for: "/devices", with: completionHandler)
    }
    
    class func fetchDevice(for deviceUUID: String, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        sendRequest(withData: nil, toPath: "/devices/"+deviceUUID, withMethod: "GET", with: completionHandler)
    }
    
    class func addDevice(_ deviceData: String, with completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        sendRequest(withData: deviceData, toPath: "/devices", withMethod: "POST", with: completionHandler)
    }
    
    class func editDevice(with uuid: String, deviceData: String, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        sendRequest(withData: deviceData, toPath: "/devices/"+uuid, withMethod: "PATCH", with: completionHandler)
    }
    
    class func deleteDevice(withUUID uuid: String,with completionHandler: @escaping (Error?) -> Void) {
        sendDelete(for: "/devices/"+uuid, with: completionHandler)
    }
    
    // MARK: - Parameters
    
    class func editParameter(with uuid: String, paramData: String, completionHandler: @escaping (Error?) -> Void) {
        sendRequest(withData: paramData, toPath: "/parameters/"+uuid, withMethod: "PATCH") { (resultData, error) in
            if let error = error {
                completionHandler(error)
            } else if let _ = resultData {
                completionHandler(nil)
            } else {
                completionHandler(HomeFetcherError.DownloadError("No Data in result."))
            }
        }
    }
    
    // MARK: - Actions
    
    class func fetchActions(with completionHandler: @escaping ([Any]?, Error?) -> Void) {
        fetchArray(for: "/actions", with: completionHandler)
    }
    
    class func addAction(_ actionData: String, with completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        sendRequest(withData: actionData, toPath: "/actions", withMethod: "POST", with: completionHandler)
    }
    
    class func editAction(with uuid: String, actionData: String, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        sendRequest(withData: actionData, toPath: "/actions/"+uuid, withMethod: "PATCH", with: completionHandler)
    }
    
    class func deleteAction(withUUID uuid: String, with completionHandler: @escaping (Error?) -> Void) {
        sendDelete(for: "/actions/"+uuid, with: completionHandler)
    }
    
    class func fireAction(withUUID uuid: String, with completionHandler: @escaping (Error?) -> Void) {
        sendRequest(withData: nil, toPath: "/actions/"+uuid, withMethod: "POST") { (data, error) in
            if let error = error {
                completionHandler(error)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    //expects object back, not an array
    private class func sendRequest(withData data: String?, toPath path: String, withMethod method: String, with completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        guard let apiUrl = KeychainAccess.retrieveAPIUrl(), let apiKey = KeychainAccess.retrieveAPIKey() else {
            completionHandler(nil,HomeFetcherError.MissingAPIValues("Missing API URL/KEY"))
            return
        }
        guard let url = URL(string: apiUrl+path) else {
            print("Could not form url.")
            completionHandler(nil,HomeFetcherError.URLError("Could not create URL."))
            return
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.httpMethod = method
        if let data = data {
            request.httpBody = data.data(using: .utf8)
        }
        (URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(nil, error)
            } else if let response = response as? HTTPURLResponse, let data = data {
                if response.statusCode == 200 {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let jsonDict = json as? [String:  Any] {
                            completionHandler(jsonDict,nil)
                        } else {
                            print("Didn't get an object back")
                            completionHandler(nil, HomeFetcherError.DownloadError("Expected JSON Object"))
                        }
                    } catch {
                        print("JSON Parse Error")
                        completionHandler(nil,error)
                    }
                } else {
                    if let datastr = String(data: data, encoding: .utf8) {
                        print("Data: \(datastr)")
                    }
                    completionHandler(nil,HomeFetcherError.APIError("API gave error: \(response.statusCode)"))
                }
            } else {
                completionHandler(nil,HomeFetcherError.DownloadError("Unknown Error"))
            }
        }).resume()
        
    }
    
    private class func fetchArray(for path: String, with completionHandler: @escaping ([Any]?, Error?) -> Void) {
        guard let apiUrl = KeychainAccess.retrieveAPIUrl(), let apiKey = KeychainAccess.retrieveAPIKey() else {
            completionHandler(nil,HomeFetcherError.MissingAPIValues("Missing API URL/KEY"))
            return
        }
        guard let url = URL(string: apiUrl+path) else {
            print("Could not form url")
            completionHandler(nil,HomeFetcherError.URLError("Could not create URL"))
            return
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        (URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(nil,error)
            } else if let _ = response, let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data)
                    if let jsonArray = json as? [Any] {
                        completionHandler(jsonArray, nil)
                    } else {
                        completionHandler([],HomeFetcherError.DownloadError("Expected an array"))
                    }
                } catch {
                    completionHandler(nil,error)
                }
            } else {
                completionHandler(nil,HomeFetcherError.DownloadError("Unknown Error"))
            }
        }).resume()
    }
    
    private class func sendDelete(for path: String, with completionHandler: @escaping (Error?)-> Void) {
        guard let apiUrl = KeychainAccess.retrieveAPIUrl(), let apiKey = KeychainAccess.retrieveAPIKey() else {
            completionHandler(HomeFetcherError.MissingAPIValues("Missing API URL/KEY"))
            return
        }
        guard let url = URL(string: apiUrl+path) else {
            completionHandler(HomeFetcherError.URLError("Could not create URL"))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        (URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(error)
            } else if let response = response as? HTTPURLResponse, let _ = data {
                if response.statusCode == 200 {
                    completionHandler(nil)
                } else {
                    completionHandler(HomeFetcherError.APIError("API Sent Error with code \(response.statusCode)"))
                }
            } else {
                print("No response or data??")
                completionHandler(HomeFetcherError.DownloadError("Couldn't get a response."))
            }
        }).resume()
    }

}

// MARK: Errors

enum HomeFetcherError : Error {
    case URLError(String)
    case MissingAPIValues(String)
    case DownloadError(String)
    case APIError(String)
}
