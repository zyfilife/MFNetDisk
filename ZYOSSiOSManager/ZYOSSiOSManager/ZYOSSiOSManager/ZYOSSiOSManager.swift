//
//  ZYOSSiOSManager.swift
//  ZYOSSiOSManager
//
//  Created by 朱益锋 on 2017/7/8.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AliyunOSSiOS

enum ZYOSSiOSState: Int {
    case stoped = 0
    case waiting
    case loading
    case finished
    case failed
}

protocol ZYOSSiOSManagerDelegate: NSObjectProtocol {
    func zyOSSiOSManager(manager: ZYOSSiOSManager, state: ZYOSSiOSState)
}

class ZYOSSiOSManager {
    
    //单例
    static let sharedInstance = ZYOSSiOSManager()
    
    //客户端
    var client: OSSClient!
    
    //数组-用于缓存上传请求
    var arrayOfUploadRequest = [ZYResumableUploadRequest]()
    
    //数组-用于缓存下载请求
    var arrayOfDownloadRequest = [ZYResumableDownloadRequest]()
    
    var arrayOfUploadModel = [ZYUploadModel]()
    
    var arrayOfDownloadModel = [ZYDownloadModel]()
    
    //句柄-用于写入已经下载的Data
    var writeHandle: FileHandle?
    
    weak var delegate: ZYOSSiOSManagerDelegate?
    
    // MARK: - Init
    //_____________________________________________________________________
    
    init() {
        self.initOSSClient()
        self.prepareData()
    }
    
    func initOSSClient() {
        OSSLog.enable()
        let credential = OSSFederationCredentialProvider { () -> OSSFederationToken? in
            let token = OSSFederationToken()
            return token
        }
        let endPoint = ""
        if credential != nil {
            self.client = OSSClient(endpoint: endPoint, credentialProvider: credential!)
        }
    }
    
    func prepareData() {
        
        self.arrayOfUploadModel = self.getArrayOfUploadModelFromLocal()
        
        for model in arrayOfUploadModel {
            let request = self.initResumabelUploadRequest(model: model)
            self.arrayOfUploadRequest.append(request)
        }
    }
    
    // MARK: - Cache
    //_____________________________________________________________________
    
    func saveUploadModelAtLocal(model: ZYUploadModel) {
        
    }
    
    func getArrayOfUploadModelFromLocal() -> [ZYUploadModel] {
        return [ZYUploadModel]()
    }
    
    func updateUploadModelAtLocal(model: ZYUploadModel) {
        
    }
    
    func deleteUploadModelAtLocal(model: ZYUploadModel) {
        
    }
    
    // MARK: - ResumeUpload
    //_____________________________________________________________________
    
    func initResumabelUploadRequest(model: ZYUploadModel) -> ZYResumableUploadRequest {
        let resumableUpload = ZYResumableUploadRequest()
        resumableUpload.bucketName = model.bucketName
        resumableUpload.objectKey = model.objectKey
        resumableUpload.uploadId = model.uploadId
        resumableUpload.uploadingFileURL = URL(fileURLWithPath: model.localPath!)
        resumableUpload.uploadModel = model
        resumableUpload.uploadProgress = { (byte, current, total) in
            let uploadModel = resumableUpload.uploadModel!
            uploadModel.state = .loading
            uploadModel.currentSize = Int(current)
            uploadModel.fileSize = Int(total)
            self.updateUploadModelAtLocal(model: uploadModel)
            
            DispatchQueue.main.async(execute: {
                self.delegate?.zyOSSiOSManager(manager: self, state: .loading)
            })
        }
        return resumableUpload
    }
    
    
    func creatResumeUploadRequest(uploadModel: ZYUploadModel, isStart: Bool=true) {
        
        if self.arrayOfUploadModel.contains(where: { (model) -> Bool in
            return uploadModel.md5code == model.md5code
        }) {
            print("\\______________________该文件已经在上传列表中")
            return
        }
        
        guard let md5code = uploadModel.md5code, let format = uploadModel.fileFormat, let _ = uploadModel.localPath else {
            return
        }
        
        let objectKey = md5code + format
        
        let bucketName = ""
        
        var uploadID: String?
        
        let task = OSSTask<AnyObject>(result: nil)
        
        task.continue({ (task) -> Any? in
            let value = UserDefaults.standard.string(forKey: objectKey)
            return OSSTask<AnyObject>(result: value as AnyObject)
        }).continue(successBlock: { (task) -> Any? in
            if let _ = task.result as? String {
                return task
            }else {
                let initM = OSSInitMultipartUploadRequest()
                initM.bucketName = bucketName
                initM.objectKey = objectKey
                initM.contentType = "application/octet-stream"
                return self.client.multipartUploadInit(initM) as! OSSTask<OSSInitMultipartUploadRequest>
            }
        }).continue(successBlock: { (task) -> Any? in
            if task.result!.isKind(of: OSSInitMultipartUploadResult.self) {
                uploadID = (task as! OSSTask<OSSInitMultipartUploadResult>).result?.uploadId
                print("\\__________________________新获取UploadID: \(uploadID!)")
            }else {
                uploadID = task.result as? String
                print("\\__________________________本地获取UploadID: \(uploadID!)")
            }
            UserDefaults.standard.set(uploadID, forKey: md5code)
            UserDefaults.standard.synchronize()
            return OSSTask(result: uploadID as AnyObject)
        }).waitUntilFinished()
        
        let newUploadModel = uploadModel
        newUploadModel.bucketName = bucketName
        newUploadModel.objectKey = objectKey
        newUploadModel.uploadId = uploadID
        
        //加入数据库
        self.saveUploadModelAtLocal(model: uploadModel)
        
        //加入上传列表
        self.arrayOfUploadModel.append(newUploadModel)
        
        let resumableUpload = self.initResumabelUploadRequest(model: newUploadModel)
        
        self.arrayOfUploadRequest.insert(resumableUpload, at: 0)
        
        DispatchQueue.main.async(execute: {
            self.delegate?.zyOSSiOSManager(manager: self, state: .waiting)
        })
        
        self.resumeUploadToNetDisk(resumableUpload: resumableUpload)
    }
    
    func resumeUploadToNetDisk(resumableUpload: ZYResumableUploadRequest) {
        
        let uploadModel = resumableUpload.uploadModel!
        
        let resumeableTask =  self.client.resumableUpload(resumableUpload) as! OSSTask<OSSResumableUploadResult>
        
        resumeableTask.continue({ (task) -> Any? in
            if let error = task.error as NSError? {
                print("\\__________________________上传失败，error: \(error)")
                uploadModel.state = ZYOSSiOSState.stoped
                uploadModel.speek = 0
                self.updateUploadModelAtLocal(model: uploadModel)
                
                if error.domain == OSSClientErrorDomain && error.code == OSSClientErrorCODE.codeCannotResumeUpload.rawValue {
                    if let objectKey = resumableUpload.objectKey {
                        UserDefaults.standard.removeObject(forKey: objectKey)
                    }
                    self.deleteUploadModelAtLocal(model: uploadModel)
                    if let localPath = uploadModel.localPath {
                        do {
                            try FileManager.default.removeItem(atPath: localPath)
                        }catch {
                            print("\\_______________移除文件失败：\(error)")
                        }
                    }
                    uploadModel.currentSize = 0
                    uploadModel.state = ZYOSSiOSState.failed
                    uploadModel.speek = 0
                    self.creatResumeUploadRequest(uploadModel: uploadModel)
                    DispatchQueue.main.async(execute: {
                        self.delegate?.zyOSSiOSManager(manager: self, state: .failed)
                    })
                    
                }else if error.domain == OSSClientErrorDomain && error.code == OSSClientErrorCODE.codeTaskCancelled.rawValue {
                    
                    DispatchQueue.main.async(execute: {
                        self.delegate?.zyOSSiOSManager(manager: self, state: .stoped)
                    })
                }
                return OSSTask<AnyObject>(result: nil)
            }else {
                print("\\__________________________上传成功")
                if let objectKey = resumableUpload.objectKey {
                    UserDefaults.standard.removeObject(forKey: objectKey)
                }
                uploadModel.state = ZYOSSiOSState.finished
                uploadModel.speek = 0
                self.updateUploadModelAtLocal(model: uploadModel)
                
                DispatchQueue.main.async(execute: {
                    self.delegate?.zyOSSiOSManager(manager: self, state: ZYOSSiOSState.finished)
                })
            }
            return nil
        })
    }
}
