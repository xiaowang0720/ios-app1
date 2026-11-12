# 随手记

一款面向 iOS 15.0 及以上版本的 SwiftUI 应用。点右上角加号新增记录，点一条记录编辑，向左滑动删除。导出 CSV 时可通过系统的「文件」界面选择保存位置。

## 在 Mac 上试用

1. 用 Xcode 打开 `OfflineNotes.xcodeproj`。
2. 连接 iPhone，在 `Signing & Capabilities` 里选择自己的 Team。若 Xcode 提示标识符已被占用，换一个自己专用的 Bundle Identifier。
3. 选中 iPhone，点击 Run。新建一条含有中文、逗号、引号和换行的记录，退出再打开应用，检查记录是否保留，再导出 CSV。

## 从 Windows 发起云端构建

1. 把本目录里的文件上传到你自己的 GitHub 私有仓库根目录，包含隐藏的 `.github` 目录。
2. 在 GitHub 打开 **Actions → Build iPhone app → Run workflow**。
3. 构建成功后，在该次运行的 **Artifacts** 下载 `OfflineNotes-unsigned`。压缩包里的 `.ipa` 是待签名包。常规设备安装需要用自己的有效证书和设备描述文件签名。
