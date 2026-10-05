# 仓库开发约定

## 语言与工程边界

- 文档、提交说明和新增代码注释优先使用中文。
- 保持 HarmonyOS 7 / API 26、Stage 模型、ArkTS / ArkUI，以及应用包名 com.gyg.harmonyledger。
- 先定位负责该功能的页面、组件、服务或数据仓库；只改完成功能所需的文件。
- 页面状态由 pages/ 管理；components/ 提供受控 UI；services/ 放 OCR、解析和统计计算；data/ 放 ArkData 访问；model/ 放共享类型和格式化逻辑。
- Index.ets 是当前应用流程协调入口。扩展能力放在 extensionability/，启动与前后台生命周期放在 entryability/。

## 必须保留的行为

- 账本数据库名 harmony_ledger.db、ledger_entries 表和既有字段属于兼容契约。修改前先说明数据迁移影响。
- 金额以整数分存储；不要用浮点数保存账目金额。
- OCR 记录必须由用户复核。没有可靠日期的记录不入账；只有日期时不要虚构时分；商户使用识别出的原文。
- 微信、支付宝、工商银行截图解析规则分别维护；未知来源应要求用户确认，不能静默猜测。
- 截图识别的重复项按既有规则核对。通知自动记账按方向、金额和交易分钟查重；命中时不新增条目，只在既有分类为“其他”时更新为明确分类。
- 通知归档与自动入账使用独立失败路径；通知标题和正文属于敏感本地数据。
- 不增加账号、上传或云同步，除非先修改并批准产品方案。

## 隐私与本机配置

不要提交真实账单、OCR 文本、截图、数据库、CSV 导出、HAP、证书、私钥、签名口令或含凭据的构建配置。签名配置只保存在本机。notification-mock-apps/ 是独立工程，保持在本仓库之外。

## 构建与核对

在 PowerShell 中设置本机 DevEco Studio 安装目录和 HarmonyOS SDK 26 后执行：

~~~powershell
$env:DEVECO_SDK_HOME = '<HarmonyOS SDK 26 路径>'
& '<DevEco Studio 路径>\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default assembleHap
~~~

构建后检查输出和 git diff --check。代码功能变更应在可用的 HarmonyOS 7 / API 26 真机上核对受影响流程；真机不可用时如实记录未完成项。默认签名配置留空，发布前必须在本机完成签名并核对安装包。
