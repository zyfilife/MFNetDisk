//
//  ZYDownloadModel.swift
//  ZYOSSiOSManager
//
//  Created by 朱益锋 on 2017/7/8.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AliyunOSSiOS
import RealmSwift

class ZYDownloadModel: Object {
    var id: String?
    var name: String?
    var size:Int = 0
    var format: String?
    var filePath: String?
    var md5: String?
    var createDate: String?
    
    var downloadSpeek: Int=0
    var currentSize: Int=0
    var totalSize: Int=0
    
    var localFilePath: String? {
        if let md5 = self.md5, let format = self.format {
            return self.baseFilePath + "/" + md5 + format
        }
        return nil
    }
    
    var baseFilePath: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
    }
    
    var isAtLocal: Bool {
        get {
            if let path = self.localFilePath {
                return FileManager.default.fileExists(atPath: path)
            }
            return false
        }
        set {
            self.isAtLocal = newValue
        }
    }
    
    var state: ZYOSSiOSState = ZYOSSiOSState.stoped
    var speek: Int = 0
    
    var bucketName: String?
    var objectKey: String?
}

class ZYResumableDownloadRequest: OSSGetObjectRequest {
    var downloadModel: ZYDownloadModel?
}
