//
//  APIClient.swift
//  Photobook
//
//  Created by Jaime Landazuri on 16/11/2017.
//  Copyright © 2017 Kite.ly. All rights reserved.
//

import Foundation
import UIKit
import SDWebImage

enum APIClientError: Error {
    case generic
    case parsing(details: String)
    case connection
    case server(code: Int, message: String)
}

enum APIContext {
    case none
    case photobook
    case pig
    case kite
}

/// Network client for all interaction with the API
class APIClient: NSObject {
    
    // Notification keys
    static let backgroundSessionTaskFinished = Notification.Name("ly.kite.sdk.APIClientBackgroundSessionTaskFinished")
    static let backgroundSessionAllTasksFinished = Notification.Name("ly.kite.sdk.APIClientBackgroundSessionAllTaskFinished")
    
    // Storage constants
    private struct Storage {
        static let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        static let uploadTasksFile: String = { return documentsDirectory.appending("/Photobook/PBUploadTasks.dat") }()
    }
    
    private struct Constants {
        static let backgroundSessionBaseIdentifier = "ly.kite.sdk.backgroundSession"
        static let errorDomain = "ly.kite.sdk.APIClient.APIClientError"
    }
    
    // Available methods
    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }
    
    // Image types
    private enum ImageType: String {
        case jpeg
        case png
    }
    
    /// The environment of the app, live vs test
    static var environment: Environment = .live
    
    private static let prefix = "APIClient-AssetUploader-"
    
    var imageUploadIdentifierPrefix: String { return APIClient.prefix }
    
    private func baseURLString(for context: APIContext) -> String {
        switch context {
        case .none: return ""
        case .photobook: return "https://photobook-builder.herokuapp.com"
        case .pig: return "https://image.kite.ly/"
        case .kite: return "https://api.kite.ly/"
        }
    }

    
    /// Shared client
    static let shared: APIClient = {
        let apiClient = APIClient()
        NotificationCenter.default.addObserver(apiClient, selector: #selector(savePendingTasks), name: .UIApplicationWillTerminate, object: nil)
        NotificationCenter.default.addObserver(apiClient, selector: #selector(savePendingTasks), name: .UIApplicationDidEnterBackground, object: nil)
        
        return apiClient
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Url session for regular tasks
    private let urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: OperationQueue.main)
    
    // Url session for background upload tasks
    private lazy var backgroundUrlSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Constants.backgroundSessionBaseIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60 //7 days timeout
        return URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }()
    
    // Completion handler to execute when the app has been woken up by finished tasks
    private var backgroundSessionCompletionHandler: (()->())? = nil
    
    // Dictionary with upload task identifiers keys and semantic references
    private var taskReferences: [Int: String] = {
        if let references = NSKeyedUnarchiver.unarchiveObject(withFile: Storage.uploadTasksFile) as? [Int: String] {
            return references
        }
        return [Int: String]()
    }()
    
    private func createFileWith(imageData: Data, imageName: String, boundaryString: String) -> URL {
        
        let directoryUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileUrl = directoryUrl.appendingPathComponent(NSUUID().uuidString)
        let filePath = fileUrl.path
        
        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
        let fileHandle = FileHandle(forWritingAtPath: filePath)!
        
        let imageType = self.imageType(forFileName: imageName)
        
        var header = ""
        header += "--\(boundaryString)\r\n"
        header += "Content-Disposition: form-data; charset=utf-8; name=\"file\"; filename=\"\(imageName).\(imageType)\"\r\n"
        header += "Content-Type: image/\(imageType)\r\n\r\n"
        let headerData = header.data(using: .utf8, allowLossyConversion: false)!
        
        let footer = "\r\n--\(boundaryString)--\r\n"
        let footerData = footer.data(using: .utf8, allowLossyConversion: false)!
        
        fileHandle.write(headerData)
        fileHandle.write(imageData)
        fileHandle.write(footerData)
        fileHandle.closeFile()
        
        return fileUrl
    }
    
    private func imageData(withImage image: UIImage, imageName: String) -> Data? {
        let imageType = self.imageType(forFileName: imageName)
        return imageData(withImage: image, forType: imageType)
    }

    private func imageData(withImage image: UIImage, forType imageType: ImageType) -> Data? {
        let imageData:Data
        
        switch imageType {
        case .jpeg:
            guard let data = UIImageJPEGRepresentation(image, 0.8) else {
                return nil
            }
            imageData = data
        case .png:
            guard let data = UIImagePNGRepresentation(image) else {
                return nil
            }
            imageData = data
        }
        
        return imageData
    }
    
    private func imageType(forFileName fileName:String) -> ImageType {
        if fileName.lowercased().hasSuffix(".png") {
            return .png
        }
        return .jpeg
    }
    
    // MARK: Background tasks
    
    /// Called when the app is launched by the system by pending tasks
    ///
    /// - Parameter completionHandler: The completion handler provided by the system and that should be called when the event handling is done.
    func recreateBackgroundSession(_ completionHandler: (()->Void)? = nil) {
        self.backgroundSessionCompletionHandler = completionHandler
        
        // Trigger lazy initialisation
        _ = backgroundUrlSession
    }
    
    /// Save semantic references for pending upload tasks to disk
    @objc func savePendingTasks() {
        if taskReferences.isEmpty {
            try? FileManager.default.removeItem(atPath: Storage.uploadTasksFile)
            return
        }

        let saved = NSKeyedArchiver.archiveRootObject(taskReferences, toFile: Storage.uploadTasksFile)
        if !saved {
            print("Upload Tasks: Error saving pending tasks to disk")
            return
        }
        
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var fileUrl = URL(fileURLWithPath: Storage.uploadTasksFile)
        try? fileUrl.setResourceValues(resourceValues)
    }
    
    func hasPendingBackgroundTasks(_ completion: @escaping (Bool) -> Void) {
        backgroundUrlSession.getAllTasks { (tasks) in
            let hasTasks = tasks.count > 0
            completion(hasTasks)
        }
    }
    
    // MARK: Generic dataTask handling
    
    private func dataTask(context: APIContext, endpoint: String, parameters: [String : Any]?, headers: [String : String]?, method: HTTPMethod, completion: @escaping (AnyObject?, APIClientError?) -> ()) {
        
        var request = URLRequest(url: URL(string: baseURLString(for: context) + endpoint)!)
        
        request.httpMethod = method.rawValue
        
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        for header in headers ?? [:] {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }
        
        switch method {
        case .get:
            if let parameters = parameters {
                var components = URLComponents(string: request.url!.absoluteString)
                var items = [URLQueryItem]()
                for (key, value) in parameters {
                    var itemValue = ""
                    if let value = value as? String {
                        itemValue = value
                    } else if let value = value as? Int {
                        itemValue = String(value)
                    } else {
                        fatalError("API client: Unsupported parameter type")
                    }
                    
                    let item = URLQueryItem(name: key, value: itemValue)
                    items.append(item)
                }
                components?.queryItems = items
                request.url = components?.url
            }
        case .post:
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let parameters = parameters {
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                } catch let error {
                    print(error.localizedDescription)
                }
            }
        default:
            fatalError("API client: Unsupported HTTP method")
        }
        
        urlSession.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                let error = error as NSError?
                switch error!.code {
                case Int(CFNetworkErrors.cfurlErrorBadServerResponse.rawValue):
                    completion(nil, .server(code: 500, message: ""))
                case Int(CFNetworkErrors.cfurlErrorSecureConnectionFailed.rawValue) ..< Int(CFNetworkErrors.cfurlErrorUnknown.rawValue):
                    completion(nil, .connection)
                default:
                    completion(nil, .server(code: error!.code, message: error!.localizedDescription))
                }
                return
            }
            
            guard let data = data else {
                completion(nil, .parsing(details: "DataTask: Missing data for \(request.url?.absoluteString ?? "")"))
                return
            }
            
            // Attempt parsing to JSON
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                // Check if there's an error in the response
                if let responseDictionary = json as? [String: AnyObject],
                    let errorDict = responseDictionary["error"] as? [String : AnyObject],
                    let errorMessage = (errorDict["message"] as? [AnyObject])?.last as? String {
                    completion(nil, .server(code: (response as? HTTPURLResponse)?.statusCode ?? 0, message: errorMessage))
                } else {
                    completion(json as AnyObject, nil)
                }
            } else if let image = UIImage(data: data) { // Attempt parsing UIImage
                completion(image, nil)
            } else { // Parsing error
                var details = "DataTask: Bad data for \(request.url?.absoluteString ?? "")"
                if let stringData = String(data: data, encoding: String.Encoding.utf8) {
                    details = details + ": " + stringData
                }
                completion(nil, .parsing(details: details))
            }
            }.resume()
    }

    // MARK: - Public methods
    func post(context: APIContext, endpoint: String, parameters: [String : Any]? = nil, headers: [String : String]? = nil, completion:@escaping (AnyObject?, APIClientError?) -> ()) {
        dataTask(context: context, endpoint: endpoint, parameters: parameters, headers: headers, method: .post, completion: completion)
    }
    
    func get(context: APIContext, endpoint: String, parameters: [String : Any]? = nil, headers: [String : String]? = nil, completion:@escaping (AnyObject?, APIClientError?) -> ()) {
        dataTask(context: context, endpoint: endpoint, parameters: parameters, headers: headers, method: .get, completion: completion)
    }
    
    func put(context: APIContext, endpoint: String, parameters: [String : Any]? = nil, headers: [String : String]? = nil, completion:@escaping (AnyObject?, APIClientError?) -> ()) {
        dataTask(context: context, endpoint: endpoint, parameters: parameters, headers: headers, method: .put, completion: completion)
    }
    
    func uploadImage(_ data: Data, imageName: String, completion: @escaping (AnyObject?, Error?) -> ()) {
        let boundaryString = "Boundary-\(NSUUID().uuidString)"
        let fileUrl = createFileWith(imageData: data, imageName: imageName, boundaryString: boundaryString)
    
        var request = URLRequest(url: URL(string: baseURLString(for: .pig) + "upload/")!)
        
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundaryString)", forHTTPHeaderField:"content-type")
        
        URLSession.shared.uploadTask(with: request, fromFile: fileUrl) { (data, response, error) in
            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            
            DispatchQueue.main.async { completion(json as AnyObject, nil) }
            
        }.resume()
    }
    
    func uploadImage(_ image: UIImage, imageName: String, completion: @escaping (AnyObject?, Error?) -> ()) {
        
        guard let imageData = imageData(withImage: image, imageName: imageName) else {
            print("Image Upload: cannot read image data")
            completion(nil, nil)
            return
        }
        
        uploadImage(imageData, imageName: imageName, completion: completion)
    }
    
    func uploadImage(_ data: Data, imageName: String, reference: String?) {
        let boundaryString = "Boundary-\(NSUUID().uuidString)"
        let fileUrl = createFileWith(imageData: data, imageName: imageName, boundaryString: boundaryString)
        
        var request = URLRequest(url: URL(string: baseURLString(for: .pig) + "upload/")!)
        
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundaryString)", forHTTPHeaderField:"content-type")
        
        let dataTask = backgroundUrlSession.uploadTask(with: request, fromFile: fileUrl)
        if reference != nil {
            taskReferences[dataTask.taskIdentifier] = imageUploadIdentifierPrefix + reference!
            savePendingTasks()
        }
        
        dataTask.resume()
    }
    
    func uploadImage(_ image: UIImage, imageName: String, reference: String?) {
        
        guard let imageData = imageData(withImage: image, imageName: imageName) else {
            print("Image Upload: cannot read image data")
            return
        }
        
        uploadImage(imageData, imageName: imageName, reference: reference)
    }
    
    func uploadImage(_ file: URL, reference: String?) {
        guard let fileData = try? Data(contentsOf: file) else {
            print("File Upload: cannot read file data")
            return
        }

        let imageName = file.lastPathComponent
        
        uploadImage(fileData, imageName: imageName, reference: reference)
    }
    
    func downloadImage(_ imageUrl: URL, completion: @escaping ((UIImage?, Error?) -> Void)) {
        SDWebImageManager.shared().loadImage(with: imageUrl, options: [], progress: nil, completed: { image, _, error, _, _, _ in
            DispatchQueue.main.async {
                completion(image, error)
            }
        })
    }
    
    func pendingBackgroundTaskCount(_ completion: @escaping ((Int)->Void)) {
        backgroundUrlSession.getAllTasks { completion($0.count) }
    }
    
    func cancelBackgroundTasks(_ completion: @escaping () -> Void) {
        backgroundUrlSession.getAllTasks { (tasks) in
            for task in tasks {
                task.cancel()
            }
            completion()
        }
    }
}

extension APIClient: URLSessionDelegate, URLSessionDataDelegate {
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let completionHandler = backgroundSessionCompletionHandler {
            completionHandler()
            backgroundSessionCompletionHandler = nil
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard var json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: AnyObject] else {
            if let stringData = String(data: data, encoding: String.Encoding.utf8) {
                print("API Error: \(stringData)")
            }
            NotificationCenter.default.post(name: APIClient.backgroundSessionTaskFinished, object: nil, userInfo: nil)
            return
        }
        
        // Add reference to response dictionary if there is one
        if let reference = taskReferences[dataTask.taskIdentifier] {
            taskReferences[dataTask.taskIdentifier] = nil
            
            json["task_reference"] = reference as AnyObject
        }
        
        NotificationCenter.default.post(name: APIClient.backgroundSessionTaskFinished, object: nil, userInfo: json)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard session.configuration.identifier != nil else { return }
        
        if error != nil {
            let error = error as NSError?
            
            var userInfo = [ "error": APIClientError.server(code: error!.code, message: error!.localizedDescription) ] as [String: AnyObject]
            
            // Add reference to response dictionary if there is one
            if let reference = taskReferences[task.taskIdentifier] {
                taskReferences[task.taskIdentifier] = nil

                userInfo["task_reference"] = reference as AnyObject
            }
            
            NotificationCenter.default.post(name: APIClient.backgroundSessionTaskFinished, object: nil, userInfo: userInfo)
        }
    }
}
