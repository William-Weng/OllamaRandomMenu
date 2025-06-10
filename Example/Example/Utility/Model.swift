//
//  Model.swift
//  Example
//
//  Created by William.Weng on 2025/5/7.
//

import UIKit

struct MessageInfoInformation: Codable {
    
    let role: String
    let name: String
    let content: String
    let indices: String
    let timestamp: Int
    let createDate: Int
}
