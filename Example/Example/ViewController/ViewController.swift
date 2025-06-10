//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2025/3/13.
//
//

import UIKit
import JavaScriptCore
import WebKit
import SafariServices
import WWHUD
import WWPrint
import WWNetworking
import WWEventSource
import WWKeyboardShadowView
import WWExpandableTextView
import WWSideMenuViewController

// MARK: - ViewController
final class ViewController: WWItemViewController {
    
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var myWebView: WKWebView!
    @IBOutlet weak var connentView: UIView!
    @IBOutlet weak var chatButton: UIButton!
    @IBOutlet weak var keyboardConstraintHeight: NSLayoutConstraint!
    @IBOutlet weak var keyboardShadowView: WWKeyboardShadowView!
    @IBOutlet weak var expandableTextView: WWExpandableTextView!
    
    private var responseString: String = ""
    private var tempView: UIView?
    private var firstTimestamp: Int?
    private var lastBotTimestamp: Int?
    private var currentFontSize = 20.0
    
    private var isChatting = false {
        
        didSet {

            let imageName = !isChatting ? "Play" : "Stop"
            
            DispatchQueue.main.async {
                self.expandableTextView.updateHeight()
                self.chatButton.setImage(UIImage(named: imageName), for: .normal)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initSetting()
    }
        
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        initKeyboardShadowViewSetting()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }
    
    @IBAction func generateLiveDemo(_ sender: UIButton) {
        view.endEditing(true)
        
        if !isChatting { generateLiveAction(isRandom: false); return }
        
        if let lastBotTimestamp {
            refreashWebSlaveCell(with: myWebView, responseString: Constant.userErrorMessage)
            Task { await updateMessage(role: .bot, message: Constant.userErrorMessage, timestamp: lastBotTimestamp) }
        }
        
        isChatting = false
        responseString = ""
        WWEventSource.shared.disconnect()
    }
    
    @IBAction func randomMenu(_ sender: UIButton) {
        
        displayHUD()
        
        Task {
            let result = await menuArray(count: 10)
            
            switch result {
            case .failure(let error): displayErrorHUD(error)
            case .success(let info):
                dismissHUD()
                displayMenu(title: info.title, menuArray: info.menuArray, error: info.error)
            }
        }
    }
}

// MARK: - @objc
private extension ViewController {
    
    @objc
    func handlePinchGesture(_ pinch: UIPinchGestureRecognizer) {
        
        guard pinch.view != nil else { return }
        
        let slowedScale = 1.0 + (pinch.scale - 1.0) * 0.2
        var fontSize = currentFontSize * slowedScale
        
        fontSize = (fontSize * 100).rounded() / 100
        
        if (fontSize < Constant.fontSizeRange.lower) { fontSize = Constant.fontSizeRange.lower }
        if (fontSize > Constant.fontSizeRange.upper) { fontSize = Constant.fontSizeRange.upper }
        if (fontSize == currentFontSize) { return }
        
        currentFontSize = fontSize
        
        Task { await fontSizeSetting(with: myWebView, fontSize: currentFontSize) }
        
        switch pinch.state {
        case .began, .changed: pinch.scale = 1.0
        case .ended, .cancelled, .possible, .failed: break
        @unknown default: fatalError()
        }
    }
    
    @objc
    func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        _ = displayMenu(with: .right)
    }
}

// MARK: - WKNavigationDelegate
extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        
        displayHUD()
        
        Task {
            await currentFontSize(with: myWebView)
            await restoreMessage(with: myWebView, isTop: false)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        
        guard let url = navigationAction.request.url else { return .cancel }
        
        if (url.scheme == "file") { return .allow }
        
        DispatchQueue.main.async { _ = url._openUrlWithInside(delegate: self) }
        return .cancel
    }
}

// MARK: - WKScriptMessageHandler
extension ViewController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard message.name == Constant.scriptMessageKey,
              let dictionary = message.body as? [String: Any],
              let type = dictionary["type"] as? String,
              let scriptType = ScriptType(rawValue: type)
        else {
            return
        }
        
        switch scriptType {
        case .pullToRefresh: pullToRefreshAction(with: myWebView, isTop: true)
        case .menuClickAction: menuClickAction(with: dictionary)
        case .menuPromptAction: menuPromptAction(with: dictionary)
        }
    }
}

// MARK: - SFSafariViewControllerDelegate
extension ViewController: SFSafariViewControllerDelegate {}

// MARK: - WWEventSource.Delegate
extension ViewController: WWEventSource.Delegate {
    
    func serverSentEventsConnectionStatus(_ eventSource: WWEventSource, result: Result<WWEventSource.ConnectionStatus, any Error>) {
        sseStatusAction(eventSource: eventSource, result: result)
    }
    
    func serverSentEventsRawData(_ eventSource: WWEventSource, result: Result<WWEventSource.RawInformation, any Error>) {
        
        switch result {
        case .failure(let error): displayErrorHUD(error)
        case .success(let rawInformation): sseRawString(eventSource: eventSource, rawInformation: rawInformation)
        }
    }
    
    func serverSentEvents(_ eventSource: WWEventSource, eventValue: WWEventSource.EventValue) {
        wwPrint(eventValue)
    }
}

// MARK: - WWKeyboardShadowView.Delegate
extension ViewController: WWKeyboardShadowView.Delegate {
    
    func keyboardViewChange(_ view: WWKeyboardShadowView, status: WWKeyboardShadowView.DisplayStatus, information: WWKeyboardShadowView.KeyboardInformation, height: CGFloat) -> Bool {
        return true
    }
    
    func keyboardView(_ view: WWKeyboardShadowView, error: WWKeyboardShadowView.CustomError) {
        displayErrorHUD(error)
    }
}

// MARK: - 小工具 for WebView
private extension ViewController {
    
    /// 初始化設定
    func initSetting() {
        title = Constant.chatModel
        initExpandableTextViewSetting()
        initWebView()
        initGestureRecognizer()
    }
    
    /// 鍵盤高度功能設定
    func initKeyboardShadowViewSetting() {
        keyboardConstraintHeight.constant = view.safeAreaInsets.bottom
        keyboardShadowView.configure(target: self, keyboardConstraintHeight: keyboardConstraintHeight)
        keyboardShadowView.register()
    }
    
    /// 初始化設定可變高度的TextView (最高3行)
    func initExpandableTextViewSetting() {
        expandableTextView.configure(lines: 3, gap: 21)
        expandableTextView.setting(font: .systemFont(ofSize: 20), textColor: .white, backgroundColor: .white.withAlphaComponent(0.2), borderWidth: 1, borderColor: .white)
    }
    
    /// WebView初始設定
    func initWebView() {
        
        _ = myWebView._loadFile(filename: "index.html")
        
        myWebView.navigationDelegate = self
        myWebView.backgroundColor = .clear
        myWebView.scrollView.backgroundColor = .clear
        myWebView.isOpaque = false
        
        _  = myWebView._addScriptMessageKeys(delegate: self, keys: [Constant.scriptMessageKey])
    }
    
    /// 初始化文字雙指縮放功能 + 邊緣滑動選單功能
    func initGestureRecognizer() {

        let pipPinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(Self.handlePinchGesture(_:)))
        let edgePan = UIScreenEdgePanGestureRecognizer._build(target: self, edges: .left, action: #selector(Self.handleEdgePan(_:)))
        
        view.addGestureRecognizer(pipPinchGesture)
        view.addGestureRecognizer(edgePan)
    }
    
    /// 顯示HUD
    func displayHUD() {
        guard let loadingGifUrl = Constant.loadingGifUrl else { return }
        WWHUD.shared.display(effect: .gif(url: loadingGifUrl), height: 192, backgroundColor: .black.withAlphaComponent(0.3))
    }
    
    /// 顯示錯誤HUD
    func displayErrorHUD(_ error: Error) {
        wwPrint(error)
        guard let errorGifUrl = Constant.errorGifUrl else { return }
        WWHUD.shared.flash(effect: .gif(url: errorGifUrl), height: 192, backgroundColor: .black.withAlphaComponent(0.3), animation: 1.0)
    }
    
    /// 取消HUD
    func dismissHUD() {
        guard let loadingGifUrl = Constant.loadingGifUrl else { return }
        WWHUD.shared.flash(effect: .gif(url: loadingGifUrl), height: 192, backgroundColor: .black.withAlphaComponent(0.3), animation: 1.0)
    }
}

// MARK: - 小工具
private extension ViewController {
    
    /// 及時回應 (SSE)
    /// - Parameters:
    ///   - prompt: 提問文字
    func liveGenerate(prompt: String) {
        
        let json = """
        {
          "model": "\(Constant.chatModel)",
          "prompt": "\(prompt)",
          "stream": true
        }
        """
        
        _ = WWEventSource.shared.connect(httpMethod: .POST, delegate: self, urlString: Constant.liveGenerateUrlString, httpBodyType: .string(json))
    }
    
    /// 問問題 (執行SSE串流)
    func generateLiveAction(isRandom: Bool) {
        
        let prompt = expandableTextView.text._removeWhitespacesAndNewlines()
        if (prompt.isEmpty) { return }
        
        if (isRandom) { generateLiveAction(webView: myWebView, prompt: prompt, question: prompt); return }
        similarMenuAction(with: myWebView, prompt: prompt)
    }
    
    /// 相似度選單處理
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - prompt: 提問問題
    func similarMenuAction(with webView: WKWebView, prompt: String) {
        
        displayUserMessage(webView: webView)
        
        Task {
            
            let result = await menuArray(prompt: prompt)
            
            switch result {
            case .failure(let error): displayErrorHUD(error)
            case .success(let info):
                if let error = info.error { displayMenu(title: info.title, menuArray: info.menuArray, error: error); return }
                generateLiveAction(webView: myWebView, prompt: prompt, question: prompt)
            }
        }
    }
}

// MARK: - SSE (Server Sent Events - 單方向串流)
private extension ViewController {
    
    /// SSE狀態處理
    /// - Parameters:
    ///   - eventSource: WWEventSource
    ///   - result: Result<WWEventSource.Constant.ConnectionStatus, any Error>
    func sseStatusAction(eventSource: WWEventSource, result: Result<WWEventSource.ConnectionStatus, any Error>) {
        
        switch result {
        case .failure(let error):
            DispatchQueue.main.async { [unowned self] in responseString = ""; isChatting = false; displayErrorHUD(error) }
            
        case .success(let status):
            
            switch status {
            case .connecting: DispatchQueue.main.async { [unowned self] in expandableTextView.text = ""; isChatting = true }
            case .open: break
            case .closed:
                
                isChatting = false
                
                guard let botTimestamp = lastBotTimestamp,
                      !responseString.isEmpty
                else {
                    return
                }
                
                Task {
                    await self.updateMessage(role: .bot, message: responseString, timestamp: botTimestamp)
                    responseString = ""
                }
            }
        }
    }
    
    /// SSE資訊處理
    /// - Parameters:
    ///   - eventSource: WWEventSource
    ///   - rawInformation: WWEventSource.RawInformation
    func sseRawString(eventSource: WWEventSource, rawInformation: WWEventSource.RawInformation) {
        
        defer {
            DispatchQueue.main.async { [unowned self] in refreashWebSlaveCell(with: myWebView, responseString: responseString) }
        }
        
        if rawInformation.response.statusCode != 200 {
            responseString = rawInformation.data._string() ?? "\(rawInformation.response.statusCode)"; return
        }
        
        guard let jsonObject = rawInformation.data._jsonObject() as? [String: Any],
              let _response = jsonObject["response"] as? String
        else {
            return
        }
        
        responseString += _response
        wwPrint(responseString)
    }
}

// MARK: - SSE for 選單 (Server Sent Events - 單方向串流)
private extension ViewController {
    
    /// 顯示選單
    /// - Parameters:
    ///   - title: String?
    ///   - menuArray: [Any]
    ///   - error: Any?
    func displayMenu(title: String?, menuArray: [Any], error: Any?) {
        
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        alertController.popoverPresentationController?.sourceView = menuButton
        
        var indices: [Int] = []
        
        for (_, menu) in menuArray.enumerated() {
            
            guard let menu = menu as? [String: Any],
                  let _index_ = menu["_index_"] as? Int,
                  let title = menu["user_q"] as? String,
                  let question = menu["gpt_q"] as? String
            else {
                return
            }
            
            indices.append(_index_)
            
            alertController.addAction(UIAlertAction(title: title, style: .default) { _ in
                self.expandableTextView.text = question
                self.displayUserMessage(webView: self.myWebView)
                self.generateLiveAction(isRandom: true)
            })
        }
        
        if let error { errorMessageAction(error, indices: indices); return }
        present(alertController, animated: true)
    }
    
    /// 顯示相似度不足的補充選單 for WebView
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - timestamp: Int
    ///   - menus: [Any]
    func displayWebMenu(with webView: WKWebView, timestamp: Int, menus: [Any]) async {
        await appendMenu(with: webView, timestamp: timestamp, menus: menus)
    }
    
    /// 產生隨機選單
    /// - Parameters:
    ///   - count: 選單數量
    ///   - prompt: 問題語句
    ///   - threshold: 相似度 (0.0 ~ 1.0)
    /// - Returns: Result<(title: String, menuArray: [Any], error: Any?), Error>
    func menuArray(count: Int = 3, threshold: Float = 0.7, prompt: String? = nil) async -> Result<(title: String, menuArray: [Any], error: Any?), Error> {
        
        let input = prompt ?? ""
        
        let dict: [String : Any] = [
            "input": input,
            "count": count,
            "threshold": threshold
        ]
        
        let apiType = WebApiType.menu
        let result = await WWNetworking.shared.request(httpMethod: .POST, urlString: apiType.url(), httpBodyType: .dictionary(dict))
        
        return parseMenuArray(input: input, result: result)
    }
    
    /// [選單錯誤訊息處理](https://tw.piliapp.com/emoji/list/)
    /// - Parameters:
    ///   - error: Any?
    ///   - indices: 自動補上的選單編號
    func errorMessageAction(_ error: Any?, indices: [Int]) {
        
        guard let error = error as? [String: Any],
              let message = error["message"] as? String
        else {
            return
        }
        
        let role: RoleType = .bot
        
        appendRole(with: myWebView, role: role, name: Constant.chatModel, message: message, indices: indices) { [weak self] dict in
            
            guard let this = self,
                  let botTimestamp = dict["timestamp"] as? Int
            else {
                return
            }
            
            let dictionary = ["indices": indices, "timestamp": botTimestamp]
            
            Task {
                await this.storeMessage(role: role, name: Constant.chatModel, message: message, timestamp: botTimestamp, indices: "\(indices)")
                this.menuClickAction(with: dictionary)
            }
        }
    }
    
    /// 加上使用者的文字顯示
    /// - Parameters:
    ///   - tableView: WKWebView
    func displayUserMessage(webView: WKWebView) {
        
        let role: RoleType = .user
        let prompt = expandableTextView.text._removeWhitespacesAndNewlines()
        
        appendRole(with: webView, role: role, name: Constant.userName, message: prompt) { [weak self] dict in
            
            guard let userTimestamp = dict["timestamp"] as? Int,
                  let this = self
            else {
                return
            }
            
            Task { await this.storeMessage(role: role, name: Constant.userName, message: prompt, timestamp: userTimestamp) }
        }
    }
}

// MARK: - SSE for WKWebView (Server Sent Events - 單方向串流)
private extension ViewController {
    
    /// 顯示Markdown文字
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - responseString: String
    func refreashWebSlaveCell(with webView: WKWebView, responseString: String) {
        
        guard let base64String = responseString._base64String(),
              let botTimestamp = lastBotTimestamp
        else {
            return
        }
        
        let jsCode = """
            window.displayMarkdown("\(base64String)", \(botTimestamp))
        """
        
        webView._evaluateJavaScript(script: jsCode) { result in
            
            switch result {
            case .failure(let error): self.displayErrorHUD(error)
            case .success(_): break
            }
        }
    }
    
    /// 使用WKWebView去執行SSE問題
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - prompt: String
    ///   - question: String
    func generateLiveAction(webView: WKWebView, prompt: String, question: String) {
        
        let role: RoleType = .bot
        
        appendRole(with: webView, role: role, name: Constant.chatModel, message: "") { [weak self] dict in
            
            guard let botTimestamp = dict["timestamp"] as? Int,
                  let this = self
            else {
                return
            }
            
            Task {
                guard let botTimestamp = this.lastBotTimestamp else { return }
                await this.storeMessage(role: role, name: Constant.chatModel, message: Constant.botErrorMessage, timestamp: botTimestamp)
            }
            
            this.lastBotTimestamp = botTimestamp
            this.liveGenerate(prompt: question)
        }
    }
    
    /// 加上角色Cell
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - role: RoleType
    ///   - message: String
    ///   - result: ([String: Any]) -> Void
    ///   - name: String
    ///   - indices: [Int]
    func appendRole(with webView: WKWebView, role: RoleType, name: String, message: String = "", indices: [Int] = [], result: @escaping (([String: Any]) -> Void)) {
        
        let jsCode = """
            window.appendRole("\(role)", "\(name)", "\(message._base64String()!)", "\(indices)")
        """
        
        webView._evaluateJavaScript(script: jsCode) { _result_ in
            
            switch _result_ {
            case .failure(let error): self.displayErrorHUD(error)
            case .success(let dict):
                guard let dict = dict as? [String: Any] else { return }
                return result(dict)
            }
        }
    }
    
    /// 選原角色Cell
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - info: MessageInfoInformation
    ///   - message: 文字訊息
    func restoreRole(with webView: WKWebView, info: MessageInfoInformation, message: String, isTop: Bool) async {
        
        let jsCode = """
            window.restoreRole("\(info.role)", "\(info.name)", "\(message)", \(info.timestamp), "\(info.indices)", \(isTop))
        """
        
        _ = await webView._evaluateJavaScript(script: jsCode)
    }
    
    /// 取得畫面上對話框的數量
    func messageCount(with webView: WKWebView) async -> Int? {
        
        let jsCode = """
            window.messageCount()
        """
        
        let result = await webView._evaluateJavaScript(script: jsCode)
        
        switch result {
        case .failure(_): return nil
        case .success(let count): return (count as? Int)
        }
    }
    
    /// 滾到特定的Id位置
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - timestamp: Int
    ///   - fixHeight: Int
    func scrollToMessageId(with webView: WKWebView, timestamp: Int, fixHeight: Int) async {
        
        let jsCode = """
            window.scrollToMessageId(\(timestamp), \(fixHeight))
        """
        
        _ = await webView._evaluateJavaScript(script: jsCode)
    }
    
    /// 測試是否有選單項目內容
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - timestamp: timestamp
    /// - Returns: Bool
    func listItemsExists(with webView: WKWebView, timestamp: Int) async -> Bool {
        
        let jsCode = """
            window.messageListItemsExists(\(timestamp))
        """
        
        let result = await webView._evaluateJavaScript(script: jsCode)
        
        switch result {
        case .failure(_): return false
        case .success(let isExists): return isExists as? Bool ?? false
        }
    }
    
    /// 在對話框中加入選單
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - timestamp: 當Id用的
    ///   - menus: 選單資訊
    func appendMenu(with webView: WKWebView, timestamp: Int, menus: [Any]) async {
        
        guard let jsonArray = menus._jsonData()?._string() else { return }
        
        let jsCode = """
            window.appendMenu(\(timestamp), \(jsonArray))
        """
        
        _ = await webView._evaluateJavaScript(script: jsCode)
    }
    
    /// [調整畫面文字大小](https://w3c.hexschool.com/blog/21985acb)
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - fontSize: 文字大小
    func fontSizeSetting(with webView: WKWebView, fontSize: Double) async {
        
        let jsCode = """
            window.fontSizeSetting(\(fontSize))
        """
        
        _ = await webView._evaluateJavaScript(script: jsCode)
    }
    
    /// [調整畫面文字大小](https://w3c.hexschool.com/blog/21985acb)
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - fontSize: 文字大小
    func currentFontSize(with webView: WKWebView) async {
        
        let jsCode = """
            window.currentFontSize()
        """
        
        let result = await webView._evaluateJavaScript(script: jsCode)
        
        switch result {
        case .failure(let error): wwPrint(error)
        case .success(let fontSize):
            guard let fontSize = fontSize as? Double else { return }
            currentFontSize = fontSize
        }
    }
}

// MARK: - API工具
private extension ViewController {
    
    /// 回復談話訊息
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - limit: 回傳筆數
    ///   - isTop: 是否滾到最上方
    func restoreMessage(with webView: WKWebView, limit: Int = 10, isTop: Bool) async {
        
        guard let count = await messageCount(with: webView) else { return }
        
        let paramaters = [
            "skip": "\(count)",
            "limit": "\(limit)"
        ]
        
        let apiType = WebApiType.message
        let result = await WWNetworking.shared.request(httpMethod: .GET, urlString: apiType.url(), paramaters: paramaters)
        
        switch result {
        case .failure(let error): displayErrorHUD(error)
        case .success(let info):
            
            dismissHUD()
            
            guard let data = info.data,
                  let jsonObject = data._jsonObject() as? [String: Any],
                  let array = jsonObject["result"] as? [Any],
                  let infos = array._jsonClass(for: [MessageInfoInformation].self)
            else {
                return
            }
            
            for index in 0..<infos.count {
                
                guard let info = infos[safe: index],
                      let message = try? info.content._decompressed(algorithm: Constant.compressionAlgorithm).get(),
                      let base64String = message._base64String()
                else {
                    return
                }
                
                await restoreRole(with: webView, info: info, message: base64String, isTop: isTop)
            }
            
            if let firstTimestamp = firstTimestamp {
                await scrollToMessageId(with: webView, timestamp: firstTimestamp, fixHeight: -111)
            }
            
            firstTimestamp = infos.last?.timestamp
        }
    }
    
    /// 儲存談話訊息
    /// - Parameters:
    ///   - role: 角色
    ///   - name: 顯示名稱
    ///   - message: 內容
    ///   - timestamp: 回傳的Timestamp
    ///   - indices: 因語意相似度錯誤產生的選單Id
    func storeMessage(role: RoleType, name: String, message: String, timestamp: Int, indices: String? = nil) async {
        
        guard let message = try? message._compressed(algorithm: Constant.compressionAlgorithm).get() else { return }
        
        let dict: [String : Any] = [
            "timestamp": timestamp,
            "role": role.rawValue,
            "name": name,
            "content": message,
            "indices": indices ?? "[]"
        ]
        
        let apiType = WebApiType.message
        let result = await WWNetworking.shared.request(httpMethod: .POST, urlString: apiType.url(), httpBodyType: .dictionary(dict))
        
        switch result {
        case .failure(let error): displayErrorHUD(error)
        case .success(let info):
            
            guard let data = info.data,
                  let jsonObject = data._jsonObject() as? [String: Any],
                  let result = jsonObject["result"] as? [String: String],
                  let id = result["id"]
            else {
                return
            }
            
            wwPrint("StoreMessageId = \(id)")
        }
    }
    
    /// 更新談話訊息
    /// - Parameters:
    ///   - role: 角色
    ///   - content: 內容
    ///   - timestamp: 回傳的Timestamp
    func updateMessage(role: RoleType, message: String, timestamp: Int) async {
        
        guard let message = try? message._compressed(algorithm: Constant.compressionAlgorithm).get() else { return }
        
        let dict: [String : Any] = [
            "role": "\(role)",
            "content": message,
            "timestamp": timestamp
        ]
        
        let apiType = WebApiType.message
        let result = await WWNetworking.shared.request(httpMethod: .PUT, urlString: apiType.url(), httpBodyType: .dictionary(dict))
        
        switch result {
        case .failure(let error): displayErrorHUD(error)
        case .success(let info):
            
            guard let data = info.data,
                  let jsonObject = data._jsonObject() as? [String: Any],
                  let result = jsonObject["result"] as? [String: String],
                  let count = result["count"]
            else {
                return
            }
            
            wwPrint("updateCount = \(count)")
        }
    }
    
    /// 解析選單
    /// - Parameters:
    ///   - input: String
    ///   - result: Result<WWNetworking.ResponseInformation, any Error>
    /// - Returns: Result<(title: String, menuArray: [Any], error: Any?), Error>
    func parseMenuArray(input: String, result: Result<WWNetworking.ResponseInformation, any Error>) -> Result<(title: String, menuArray: [Any], error: Any?), Error> {
        
        switch result {
        case .failure(let error): return .failure(error)
        case .success(let info):
            
            guard let data = info.data,
                  let jsonObject = data._jsonObject(),
                  let dict = jsonObject as? [String: Any?],
                  let error = dict["error"],
                  let result = dict["result"] as? [String: Any]
            else {
                return .failure(CustomError.other("回應格式錯誤"))
            }
            
            var key = (error != nil) ? "menu" : "question"
            if (input.isEmpty) { key = "menu" }
            let title = (key != "menu") ? "問題選單" : "隨機選單"
            
            guard let menuArray = result[key] as? [Any] else { return .failure(CustomError.other("回應格式錯誤")) }
            return .success((title, menuArray, error))
        }
    }
    
    /// 下拉更新功能
    /// - Parameters:
    ///   - webView: WKWebView
    ///   - isTop: Bool
    func pullToRefreshAction(with webView: WKWebView, isTop: Bool) {
        
        displayHUD()
        
        Task {
            await restoreMessage(with: myWebView, isTop: true)
            dismissHUD()
        }
    }
    
    /// 顯示相似度不足的補充選單
    /// - Parameter dictionary: [String: Any]
    func menuClickAction(with dictionary: [String: Any]) {
        
        guard let indices = dictionary["indices"] as? [Int],
              let timestamp = dictionary["timestamp"] as? Int
        else {
            return
        }
        
        Task {
            
            let isExists = await listItemsExists(with: myWebView, timestamp: timestamp)
            if (isExists) { return }
            
            let paramaters = ["indices": indices]
            let apiType = WebApiType.search
            
            displayHUD()
            
            _  = WWNetworking.shared.request(httpMethod: .POST, urlString: apiType.url(), httpBodyType: .dictionary(paramaters)) { [weak self] result in
                
                guard let this = self else { return }
                
                let _result_ = this.parseMenuArray(input: "", result: result)
                
                switch _result_ {
                case .failure(let error): this.displayErrorHUD(error)
                case .success(let info):
                    
                    Task {
                        await this.displayWebMenu(with: this.myWebView, timestamp: timestamp, menus: info.menuArray)
                        this.dismissHUD()
                    }
                }
            }
        }
    }
    
    /// 處理相似度不足的補充選單單項點擊功能
    /// - Parameter dictionary: [String: Any]
    func menuPromptAction(with dictionary: [String: Any]) {
        
        guard let prompt = dictionary["prompt"] as? String else { return }
        
        expandableTextView.text = prompt
        
        if !isChatting {
            appendRole(with: myWebView, role: .user, name: Constant.userName, message: prompt) { _ in self.generateLiveAction(isRandom: true) }
            return
        }
        
        isChatting = false
        WWEventSource.shared.disconnect()
    }
}

