//
//  Extension.swift
//  Example
//
//  Created by William.Weng on 2025/3/13.
//

import UIKit
import WebKit
import SafariServices

// MARK: - Collection (override function)
extension Collection {

    /// [為Array加上安全取值特性 => nil](https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings)
    subscript(safe index: Index) -> Element? { return indices.contains(index) ? self[index] : nil }
}

// MARK: - Sequence (function)
extension Sequence {
    
    /// Array => JSON Data
    /// - ["name","William"] => {"name","William"} => 5b226e616d65222c2257696c6c69616d225d
    /// - Returns: Data?
    func _jsonData(options: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions()) -> Data? {
        return JSONSerialization._data(with: self, options: options)
    }
    
    /// Array => JSON Data => [T]
    /// - Parameter type: 要轉換成的Array類型
    /// - Returns: [T]?
    func _jsonClass<T: Decodable>(for type: [T].Type) -> [T]? {
        let array = self._jsonData()?._class(type: type.self)
        return array
    }
}

// MARK: - JSONSerialization (static function)
extension JSONSerialization {
    
    /// [JSONObject => JSON Data](https://medium.com/彼得潘的-swift-ios-app-開發問題解答集/利用-jsonserialization-印出美美縮排的-json-308c93b51643)
    /// - ["name":"William"] => {"name":"William"} => 7b226e616d65223a2257696c6c69616d227d
    /// - Parameters:
    ///   - object: Any
    ///   - options: JSONSerialization.WritingOptions
    /// - Returns: Data?
    static func _data(with object: Any, options: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions()) -> Data? {
        
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: options)
        else {
            return nil
        }
        
        return data
    }
}

// MARK: - Int (function)
extension Int {
    
    /// Int -> Bool
    /// - Returns: Bool
    func _bool() -> Bool {
        return Bool(truncating: self as NSNumber)
    }
}

// MARK: - String (function)
extension String {
    
    /// 去除空白及換行字元
    /// - Returns: Self
    func _removeWhitespacesAndNewlines() -> Self { return trimmingCharacters(in: .whitespacesAndNewlines) }
    
    /// 文字 => Base64文字
    /// => Hello World -> SGVsbG8gV29ybGQ=
    /// - Parameter options: Data.Base64EncodingOptions
    /// - Returns: String?
    func _base64String(options: Data.Base64EncodingOptions = []) -> String? {
        return data(using: .utf8)?._base64String()
    }
    
    /// String => Data
    /// - Parameters:
    ///   - encoding: 字元編碼
    ///   - isLossyConversion: 失真轉換
    /// - Returns: Data?
    func _data(using encoding: String.Encoding = .utf8, isLossyConversion: Bool = false) -> Data? {
        let data = self.data(using: encoding, allowLossyConversion: isLossyConversion)
        return data
    }
    
    /// Base64文字 => Data
    /// - Parameter options: Data.Base64DecodingOptions = []
    /// - Returns: Data?
    func _base64Decoding(options: Data.Base64DecodingOptions = []) -> Data? {
        return Data(base64Encoded: self, options: options)
    }
    
    /// [文字壓縮 => Base64文字](https://zh.wikipedia.org/zh-tw/LZMA)
    /// - Parameters:
    ///   - encoding: 字元編碼
    ///   - isLossyConversion: 失真轉換
    ///   - algorithm: 壓縮演算法
    ///   - options: Base64編碼選項
    /// - Returns: Result<String, Error>
    func _compressed(using encoding: String.Encoding = .utf8, isLossyConversion: Bool = false, algorithm: NSData.CompressionAlgorithm, options: Data.Base64EncodingOptions = []) -> Result<String, Error> {
        
        guard let data = _data(using: encoding, isLossyConversion: isLossyConversion) else { return .failure(CustomError.other("編碼錯誤")) }
        
        let result = data._compressed(algorithm: algorithm)
        
        switch result {
        case .failure(let error): return .failure(error)
        case .success(let data): return .success(data._base64String(options: options))
        }
    }
    
    /// [Base64文字解壓縮 => 文字](https://developer.apple.com/documentation/foundation/nsdata/base64encodingoptions)
    /// - Parameters:
    ///   - algorithm: 解壓縮演算法
    ///   - options: Base64解碼選項
    ///   - encoding: 文字編碼
    /// - Returns: Data?
    func _decompressed(algorithm: NSData.CompressionAlgorithm, options: Data.Base64DecodingOptions = [], using encoding: String.Encoding = .utf8) -> Result<String, Error> {
        
        guard let data = _base64Decoding(options: options) else { return .failure(CustomError.other("解碼錯誤")) }
        
        let result = data._decompressed(algorithm: algorithm)
        
        switch result {
        case .failure(let error): return .failure(error)
        case .success(let data):
            guard let string = data._string(using: .utf8) else { return .failure(CustomError.other("解碼錯誤")) }
            return .success(string)
        }
    }
}

// MARK: - Data (function)
extension Data {
    
    /// Data => 字串
    /// - Parameter encoding: 字元編碼
    /// - Returns: String?
    func _string(using encoding: String.Encoding = .utf8) -> String? {
        return String(data: self, encoding: encoding)
    }
    
    /// [Data => JSON](https://blog.zhgchg.li/現實使用-codable-上遇到的-decode-問題場景總匯-下-cb00b1977537)
    /// - 7b2268747470223a2022626f6479227d => {"http": "body"}
    /// - Returns: Any?
    func _jsonObject(options: JSONSerialization.ReadingOptions = .allowFragments) -> Any? {
        let json = try? JSONSerialization.jsonObject(with: self, options: options)
        return json
    }
    
    /// [Data => Base64文字](https://zh.wikipedia.org/zh-tw/Base64)
    /// - Parameter options: Base64EncodingOptions
    /// - Returns: Base64EncodingOptions
    func _base64String(options: Base64EncodingOptions = []) -> String {
        return base64EncodedString(options: options)
    }
    
    /// Base64文字 => Data
    /// - Parameter options: Data.Base64DecodingOptions = []
    /// - Returns: Data?
    func _base64Decoding(options: Data.Base64DecodingOptions = []) -> Data? {
        return Data(base64Encoded: self, options: options)
    }
    
    /// Data => Class
    /// - Parameter type: 要轉型的Type => 符合Decodable
    /// - Returns: T => 泛型
    func _class<T: Decodable>(type: T.Type) -> T? {
        let modelClass = try? JSONDecoder().decode(type.self, from: self)
        return modelClass
    }
    
    /// 資料壓縮 (速度 - lz4 > lzfse > zlib > lzma)
    /// - Parameter algorithm: 壓縮演算法
    /// - Returns: Result<Data, Error>
    func _compressed(algorithm: NSData.CompressionAlgorithm = .lz4) -> Result<Data, Error> {
        
        let result = (self as NSData)._compressed(algorithm: algorithm)
        
        switch result {
        case .failure(let error): return .failure(error)
        case .success(let nsData): return .success(Data(referencing: nsData))
        }
    }
    
    /// 資料縮壓縮 (速度 - lz4 > lzfse > zlib > lzma)
    /// - Parameter algorithm: 解壓縮演算法
    /// - Returns: Result<Data, Error>
    func _decompressed(algorithm: NSData.CompressionAlgorithm = .lz4) -> Result<Data, Error> {
        
        let result = (self as NSData)._decompressed(algorithm: algorithm)
        
        switch result {
        case .failure(let error): return .failure(error)
        case .success(let nsData): return .success(Data(referencing: nsData))
        }
    }
}

// MARK: - NSData (function)
extension NSData {
    
    /// 資料壓縮 (速度 - lz4 > lzfse > zlib > lzma)
    /// - Parameter algorithm: 壓縮演算法
    /// - Returns: Result<NSData, Error>
    func _compressed(algorithm: NSData.CompressionAlgorithm = .lz4) -> Result<NSData, Error> {
        
        do {
            return try .success(compressed(using: algorithm))
        } catch {
            return .failure(error)
        }
    }
    
    /// 資料縮壓縮 (速度 - lz4 > lzfse > zlib > lzma)
    /// - Parameter algorithm: 解壓縮演算法
    /// - Returns: Result<NSData, Error>
    func _decompressed(algorithm: NSData.CompressionAlgorithm = .lz4) -> Result<NSData, Error> {
        
        do {
            return try .success(decompressed(using: algorithm))
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - NSAttributedString (function)
extension NSAttributedString {
    
    /// [Markdown轉成AttributedString](https://medium.com/彼得潘的-swift-ios-app-開發問題解答集/利用-attributedstring-或-nsattributedstring-實現多種樣式組合的文字-dba0794c09de)
    /// - Parameters:
    ///   - markdown: [String](https://fatbobman.com/zh/posts/attributedstring/)
    ///   - options: [AttributedString.MarkdownParsingOptions](https://medium.com/zrealm-ios-dev/自行實現-ios-nsattributedstring-html-render-a8c2d26cc734)
    ///   - baseURL: URL?
    /// - Returns: AttributedString
    static func _markdown(_ markdown: String, options: AttributedString.MarkdownParsingOptions, baseURL: URL?) throws -> NSAttributedString {
        return try NSAttributedString(markdown: markdown, options: options, baseURL: baseURL)
    }
}

// MARK: - UIScreenEdgePanGestureRecognizer (static function)
extension UIScreenEdgePanGestureRecognizer {
    
    /// [邊緣滑動手勢產生器 (單指)](https://medium.com/彼得潘的-swift-ios-app-開發問題解答集/開發-ios-app-的-gesture-手勢功能-uikit-版本-f6cb95075705)
    /// - Parameters:
    ///   - target: 要設定的位置
    ///   - action: 旋轉下去要做什麼？
    /// - Returns: UIScreenEdgePanGestureRecognizer
    static func _build(target: Any?, edges: UIRectEdge, action: Selector?) -> UIScreenEdgePanGestureRecognizer {
        
        let recognizer = UIScreenEdgePanGestureRecognizer(target: target, action: action)
        recognizer.edges = edges
        
        return recognizer
    }
}

// MARK: - URL
extension URL {
    
    /// 在APP內部開啟URL (SafariViewController) => window.webkit.messageHandlers.LinkUrl.postMessage("https://www.google.com")
    /// - Parameter urlString: URL網址
    func _openUrlWithInside(delegate: (UIViewController & SFSafariViewControllerDelegate)) -> SFSafariViewController {
        
        let safariViewController = SFSafariViewController(url: self)
        
        safariViewController.delegate = delegate
        safariViewController.modalTransitionStyle = .coverVertical
        safariViewController.modalPresentationStyle = .automatic
        
        delegate.present(safariViewController, animated: true)
        
        return safariViewController
    }
}

// MARK: - WKWebView
extension WKWebView {
    
    /// 載入本機HTML檔案
    /// - Parameters:
    ///   - filename: HTML檔案名稱
    ///   - bundle: Bundle位置
    ///   - directory: 資料夾位置
    ///   - readAccessURL: 允許讀取的資料夾位置
    /// - Returns: Result<WKNavigation?, Error>
    func _loadFile(filename: String, bundle: Bundle? = nil, inSubDirectory directory: String? = nil, allowingReadAccessTo readAccessURL: URL? = nil) -> WKNavigation? {
        
        guard let url = (bundle ?? .main).url(forResource: filename, withExtension: nil, subdirectory: directory) else { return nil }
        
        let readAccessURL: URL = readAccessURL ?? url.deletingLastPathComponent()
        
        return loadFileURL(url, allowingReadAccessTo: readAccessURL)
    }
    
    /// [執行JavaScript](https://andyu.me/2020/07/17/js-iife/)
    /// - Parameters:
    ///   - script: [JavaScript文字](https://lance.coderbridge.io/2020/08/05/why-use-IIFE/)
    ///   - result: Result<Any?, Error>
    func _evaluateJavaScript(script: String?, result: @escaping (Result<Any?, Error>) -> Void) {
        
        guard let script = script else { return }
        
        evaluateJavaScript(script) { data, error in
            if let error = error { result(.failure(error)); return }
            result(.success(data))
        }
    }
    
    /// [執行JavaScript - async](https://www.hackingwithswift.com/swift/5.5/continuations)
    /// - Parameter script: JavaScript程式碼
    /// - Returns: Result<Any?, Error>
    func _evaluateJavaScript(script: String?) async -> Result<Any?, Error> {
        
        await withCheckedContinuation { continuation in
            _evaluateJavaScript(script: script) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [加上網頁端要傳訊息給APP的名稱](https://ithelp.ithome.com.tw/articles/10207572)
    /// - userContentController(_:didReceive:)
    /// - window.webkit.messageHandlers.<key>.postMessage("Send message to Swift")
    /// - Parameters:
    ///   - delegate: WKScriptMessageHandler
    ///   - keys: 傳訊息給APP的Key => "ToApp"
    func _addScriptMessageKeys(delegate: WKScriptMessageHandler, keys: [String]?) -> Bool {
        
        guard let keys = keys, !keys.isEmpty, let keySet = Optional.some(Set(keys)) else { return false }
        
        keySet.forEach { (key) in configuration.userContentController.add(delegate, name: key) }
        return true
    }
}

