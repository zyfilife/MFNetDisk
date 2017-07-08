//
//  ZYUploadModel.swift
//  ZYOSSiOSManager
//
//  Created by 朱益锋 on 2017/7/8.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AliyunOSSiOS
import RealmSwift

class ZYUploadModel: Object {
    
    var fileName: String?
    var customFileName: String?
    var filePath:String?
    var md5code: String?
    var fileFormat: String?
    
    var fileSize: Int = 0
    
    var createDate: String?
    
    var localPath: String? {
        if let fileName = self.fileName {
            return NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, .userDomainMask, true).last! + "/" + fileName
        }else {
            return nil
        }
    }
    
    var currentSize: Int = 0
    
    var state: ZYOSSiOSState = .stoped
    
    var speek: Int = 0
    
    var appendPosition: Int64 = 0
    
    //Request_About
    var bucketName: String?
    var uploadId: String?
    var uploadingFilePath: String?
    var objectKey: String?
}

class ZYResumableUploadRequest: OSSResumableUploadRequest {
    var uploadModel: ZYUploadModel?
}
