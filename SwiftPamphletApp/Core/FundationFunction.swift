//
//  BaseFunction.swift
//  PresentSwiftUI
//
//  Created by Ming Dai on 2021/11/9.
//

import Foundation
import SwiftUI
import Combine
import Network

// MARK: - Web
func wrapperHtmlContent(content: String, codeStyle: String = "lioshi.min") -> String {
    let reStr = """
<html lang="zh-Hans" data-darkmode="auto">
\(SPC.rssStyle())
<body>
    <main class="container">
        <article class="article heti heti--classic">
        \(content)
        </article>
    </main>
</body>
\(SPC.rssFooterJS())
</html>
"""
    // <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.4.0/styles/\(codeStyle).css">
    // writeToDownload(fileName: "a.html", content: reStr)
    return reStr
}

// MARK: - 时间
func howLongAgo(date: Date) -> String {
    let simplifiedChinese = Locale(identifier: "zh_Hans")
    return date.formatted(.relative(presentation: .named,
                                    unitsStyle: .wide).locale(simplifiedChinese))
}
func howLongFromNow(timeStr: String) -> String {
    let iso8601String = timeStr
    let formatter = ISO8601DateFormatter()
    let date = formatter.date(from: iso8601String) ?? .now
    return howLongAgo(date: date)
}

// MARK: - 网络
// 网络状态检查 network state check
final class Nsck: ObservableObject {
    static let shared = Nsck()
    private(set) lazy var pb = mkpb()
    @Published private(set) var pt: NWPath

    private let monitor: NWPathMonitor
    private lazy var sj = CurrentValueSubject<NWPath, Never>(monitor.currentPath)
    private var sb: AnyCancellable?

    init() {
        monitor = NWPathMonitor()
        pt = monitor.currentPath
        monitor.pathUpdateHandler = { [weak self] path in
            self?.pt = path
            self?.sj.send(path)
        }
        monitor.start(queue: DispatchQueue.main)
    }

    deinit {
        monitor.cancel()
        sj.send(completion: .finished)
    }

    private func mkpb() -> AnyPublisher<NWPath, Never> {
        return sj.eraseToAnyPublisher()
    }
}

// 跳到浏览器中显示网址内容
func gotoWebBrowser(urlStr: String) {
    if !urlStr.isEmpty {
        let validUrlStr = validHTTPUrlStrFromUrlStr(urlStr: urlStr)
        NSWorkspace.shared.open(URL(string: validUrlStr)!)
    } else {
        print("error: url is empty!")
    }
}

// 检查地址是否有效
func validHTTPUrlStrFromUrlStr(urlStr: String) -> String {
    let httpPrefix = "http://"
    let httpsPrefix = "https://"
    if (urlStr.hasPrefix(httpPrefix) || urlStr.hasPrefix(httpsPrefix)) {
        return urlStr
    }
    return httpsPrefix + urlStr
}

// 网页的相对地址转绝对地址
func urlWithSchemeAndHost(url: URL, urlStr: String) -> String {
    var schemeStr = ""
    var hostStr = ""
    if let scheme = url.scheme, let host = url.host {
        schemeStr = scheme
        hostStr = host
    }
    
    if urlStr.hasPrefix("http") {
        return urlStr
    } else {
        var slash = ""
        if urlStr.hasPrefix("/") == false {
            slash = "/"
        }
        return "\(schemeStr)://\(hostStr)\(slash)\(urlStr)"
    }
}

// MARK: - 文件 - 沙盒
// 获取沙盒Document目录路径
func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

// 保存数据到沙盒中
func saveDataToSandbox(data: Data, fileName: String) {
    let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
    do {
        try data.write(to: fileURL)
        print("文件保存成功：\(fileURL.path)")
    } catch {
        print("保存文件时出错：\(error)")
    }
}
// 删除沙盒中的文件
func deleteFileFromSandbox(fileName: String) {
    let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
    do {
        try FileManager.default.removeItem(at: fileURL)
        print("文件删除成功：\(fileURL.path)")
    } catch {
        print("删除文件时出错：\(error)")
    }
}

// MARK: - 文件 - 系统和 Bundle
// just for test
func writeToDownload(fileName: String, content: String) {
    try! content.write(toFile: "/Users/mingdai/Downloads/\(fileName)", atomically: true, encoding: String.Encoding.utf8)
}

// 从Bundle中读取并解析JSON文件生成Model
func loadBundleJSONFile<T: Decodable>(_ filename: String) -> T {

    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: loadBundleData(filename))
    } catch {
        fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
    }
}

// 从 Bundle 中取出 Data
func loadBundleData(_ filename: String) -> Data {
    let data: Data
    guard let file = Bundle.main.url(forResource: filename, withExtension: nil) else {
        fatalError("Couldn't find \(filename) in main bundle.")
    }
    do {
        data = try Data(contentsOf: file)
        return data
    } catch {
        fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
    }
}
// 从 Bundle 中取出 String
func loadBundleString(_ filename: String) -> String {
    let d = loadBundleData(filename)
    return String(decoding: d, as: UTF8.self)
}

// 读取指定路径下文件内容
func loadFileContent(path: String) -> String {
    do {
        return try String(contentsOfFile: path, encoding: String.Encoding.utf8)
    } catch {
        return ""
    }
}

// MARK: - 基础
// decoder
// extension 

extension NSPasteboard {
    func copyText(_ text: String) {
        self.clearContents()
        self.setString(text, forType: .string)
    }
}

// base64
extension String {
    func base64Encoded() -> String? {
        return self.data(using: .utf8)?.base64EncodedString()
    }

    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
// 用于 SwiftData，让布尔值可排序
extension Bool: Comparable {
    public static func <(lhs: Self, rhs: Self) -> Bool {
        // the only true inequality is false < true
        !lhs && rhs
    }
}

// MARK: - 调试
func showSwiftDataStoreFileLocation() {
    guard let urlApp = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last else { return }

    let url = urlApp.appendingPathComponent("default.store")
    if FileManager.default.fileExists(atPath: url.path) {
        print("swiftdata db at \(url.absoluteString)")
    }
}

extension View {
    func debug() -> Self {
        print(Mirror(reflecting: self).subjectType)
        return self
    }
}


