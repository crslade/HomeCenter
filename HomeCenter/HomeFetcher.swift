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
    private static let API_KEY = APIInfo.API_KEY
    
  
    class func fetchRooms(completionHandler: @escaping ([Any]?, Error?) -> Void) {
        let urlString = "\(APIInfo.API_PATH)/rooms"
        fetchArray(for: urlString, with: completionHandler)
    }
    
    class func fetchDevices(for roomUUID: String, completionHandler: @escaping ([Any]?, Error?) -> Void) {
        let urlString = "\(APIInfo.API_PATH)/rooms/\(roomUUID)/devices"
        fetchArray(for: urlString, with: completionHandler)
    }
    
    class func fetchDevices(completionHandler: @escaping ([Any]?, Error?) -> Void) {
        let urlString = "\(APIInfo.API_PATH)/devices"
        fetchArray(for: urlString, with: completionHandler)
    }
    
    private class func fetchArray(for urlString: String, with completionHandler: @escaping ([Any]?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            print("Could not form url")
            completionHandler(nil,HomeFetcherError.URLError("Could not create URL"))
            return
        }
        var request = URLRequest(url: url)
        request.setValue(API_KEY, forHTTPHeaderField: "X-API-KEY")
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
    case DownloadError(String)
}
