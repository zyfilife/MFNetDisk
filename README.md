# ZYOSSiOSManager
### 前期准备
1.[OSS对象存储开发文档](https://help.aliyun.com/document_detail/31817.html?spm=5176.doc32055.6.539.FrDX0V)
2.[官方Demo](https://github.com/aliyun/alicloud-ios-demo?spm=5176.doc32055.2.4.uW81IT)
### 整理思路
#### 需求分析
1.支持暂停任务和继续任务
2.支持后台下载或上传
#### 业务逻辑
1.明确上传和下载要用到的请求类型
>断点续传
>`OSSResumableUploadRequest`
>断点下载
>`OSSGetObjectRequest`，配合其`range`属性

2.建立模型
>`UploadModel`
>`DownloadModel`

3.创建断点续传请求和断点下载请求的子类
>`ResumableUploadRequest`
>`ResumableDownloadRequest`

4.对于上传和下载的文件进行本地数据库缓存
>`FMDB`

5.上传和下载状态
>`LoadState`

6.创建下载管理类
>`LoadManager`

7.创建代理
>`LoadManagerUploadDelegate`
>`LoadManagerDownloadDelegate`

8.绑定到界面
>`UITableViewController`
>`UITableViewCell`

#### 业务流程
1.程序启动时
>创建`LoadManager`单例

2.在`LoadManager`构造方法中
>实例化`OSSClient`对象
>获取缓存的`arrayOfUploadModel`, `arrayOfDownloadModel`
>通过`arrayOfUploadModel`创建`arrayOfUploadRequest`
>通过`arrayOfDownloadModel`创建`arrayOfDownloadRequest`

3.在上传列表界面和下载列表界面加载时
>将`arrayOfUploadRequest`作为上传列表的数据源
>将`arrayOfDownloadRequest`作为下载列表的数据源

4.数据展示
>在`cell`里声明`request`属性， 将数据源的`request`传递给`cell`。
>在`cell`里通过`request`的`uploadModel`或者`downloadModel`进行数据展示

5.上传和下载
>在`LoadManager`中，通过`request`创建对应的`OSSTask`，使用`OSSTask`进行上传和下载
>在`cell`中，点击按钮，根据相应的状态，通过`request`来暂停任务或创建新的`OSSTask`来执行任务
