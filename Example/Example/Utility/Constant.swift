//
//  Constant.swift
//  Example
//
//  Created by William.Weng on 2025/5/7.
//

import Foundation

enum Constant {
    
    static let liveGenerateUrlString = "http://127.0.0.1:11434/api/generate"
    static let userErrorMessage = "使用者中斷連線…😅"
    static let botErrorMessage = "網路連線中斷…😭"
    static let userName = "William"
    static let chatModel = "gemma3:1b"
    static let scriptMessageKey = "menuAction"
    static let compressionAlgorithm: NSData.CompressionAlgorithm = .lzma
    static let loadingGifUrl = Bundle.main.url(forResource: "Loading", withExtension: ".gif")
    static let errorGifUrl = Bundle.main.url(forResource: "Error", withExtension: ".gif")
    static let fontSizeRange = (lower: 10.0, upper: 30.0)
}

enum WebApiType {
    
    static let baseUrl: String = "http://127.0.0.1:54321"
    
    case menu
    case search
    case message
    
    func url() -> String {
        switch self {
        case .menu: return "\(Self.baseUrl)/menu"
        case .search: return "\(Self.baseUrl)/menu/search"
        case .message: return "\(Self.baseUrl)/message"
        }
    }
}

enum RoleType: String {
    case user
    case bot
}

enum CustomError: Error {
    case other(_ message: String)
}

enum ScriptType: String {
    case pullToRefresh
    case menuClickAction
    case menuPromptAction
}
