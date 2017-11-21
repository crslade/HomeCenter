//
//  UIViewControllerUtilities.swift
//  HomeCenter
//
//  Created by Christopher Slade on 10/24/17.
//  Copyright © 2017 Christopher Slade. All rights reserved.
//

import UIKit

extension UIViewController {
    var contentViewController: UIViewController? {
        if let navController = self as? UINavigationController {
            return navController.visibleViewController
        } else {
            return self
        }
    }
    
    func presentErrorAlert(withMessage message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
