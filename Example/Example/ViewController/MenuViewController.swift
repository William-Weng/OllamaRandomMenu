//
//  MenuViewController.swift
//  Example
//
//  Created by William.Weng on 2025/5/21.
//

import UIKit
import WWPrint
import WWSideMenuViewController

final class SideMenuViewController: WWSideMenuViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initSettingWithSegue(delegate: self)
    }
}

extension SideMenuViewController: WWSideMenuViewControllerDelegate {
    
    func sideMenu(_ sideMenuController: WWSideMenuViewController, state: MenuState) {
        wwPrint(state)
    }
    
    func sideMenu(_ sideMenuController: WWSideMenuViewController, from previousViewController: UIViewController?, to nextViewController: UIViewController) {
        wwPrint("from: \(String(describing: previousViewController)) to: \(nextViewController)")
    }
}

final class MenuViewController: WWMenuViewController {
        
    @IBAction func dismissMenuAction(_ sender: UIButton) {
        _ = dismissMenu()
    }
}
