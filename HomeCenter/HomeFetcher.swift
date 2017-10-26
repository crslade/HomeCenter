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
    class func APIvaluesSet() -> Bool {
        if let _ = KeychainAccess.retrieveAPIKey(), let _ = KeychainAccess.retrieveAPIUrl() {
            return true
        }
        return false
    }
    
    class func fetchRooms(completionHandler: @escaping ([Any]?, Error?) -> Void) {
        let path = "/rooms"
        fetchArray(for: path, with: completionHandler)
    }
    
    class func fetchDevices(for roomUUID: String, completionHandler: @escaping ([Any]?, Error?) -> Void) {
        let path = "/rooms/\(roomUUID)/devices"
        fetchArray(for: path, with: completionHandler)
    }
    
    class func fetchDevices(completionHandler: @escaping ([Any]?, Error?) -> Void) {
        let path = "/devices"
        fetchArray(for: path, with: completionHandler)
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
                    if let rooms = json as? [Any] {
                        completionHandler(rooms, nil)
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

}

// MARK: Errors

enum HomeFetcherError : Error {
    case URLError(String)
    case MissingAPIValues(String)
    case DownloadError(String)
}
