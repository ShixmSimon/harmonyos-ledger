# 本地记账

一个面向个人自用的 HarmonyOS 手机记账应用，最低目标为 HarmonyOS 7 / API 26。项目使用 ArkTS、ArkUI 和本地 ArkData，不提供账号、云同步或自建服务。

## 功能

- 手动新增、编辑和删除收入、支出。
- 按可配置起始日计算记账周期；可按月、年或自选日期范围查看收入、支出、结余、笔数、趋势与分类/商户/来源排行，并对照上一周期；排行可跳转到账目并按金额或时间排序。
- 手动选择微信支付、支付宝或工商银行账单列表截图，在设备本地 OCR 并逐笔复核后入账。也支持从其他应用的分享面板导入截图。
- 在用户授权通知访问后，从受支持的工商银行和中信银行通知自动记账，并在本地查看通知历史。
- 将全部账目导出为 CSV，由用户通过系统保存选择器指定保存位置。

截图 OCR 生成的草稿须由用户逐条复核；授权后，受支持的银行通知会直接自动入账，可在账本和通知历史中核对。页面布局变化、文字模糊或缺少可靠日期时，截图交易可能不会生成草稿；无可靠日期的截图交易不入账。

## 隐私与数据

账目、通知归档及 OCR 过程只保存在或处理在设备本地。截图只在当前导入流程临时读取，不上传，也不长期保存。通知历史包含通知标题和正文，可能含有敏感信息。CSV 由用户主动导出到所选位置。卸载应用可能删除本地数据库，请定期导出备份。

## 开发环境

- DevEco Studio 与 HarmonyOS SDK 26。
- Stage 模型，ArkTS / ArkUI。
- 应用包名：com.gyg.harmonyledger。

在 DevEco Studio 中打开项目并选择 entry 模块的 default 产品，可直接构建。PowerShell 命令行构建示例：

~~~powershell
$devEcoStudioRoot = 'C:\path\to\DevEco Studio'
$env:DEVECO_SDK_HOME = Join-Path $devEcoStudioRoot 'sdk'
$hvigor = Join-Path $devEcoStudioRoot 'tools\hvigor\bin\hvigorw.bat'
& $hvigor --mode module -p product=default assembleHap
~~~

默认仓库配置不包含签名材料，命令行生成的是未签名 HAP。需要安装或发布时，可在本机 DevEco Studio 配置签名；DevEco Studio 可能会把签名项写入已跟踪的 `build-profile.json5`。请把签名配置留在本机专用的构建副本中，并在提交前检查 `git diff`，确认没有签名项、本机路径、证书、私钥或口令进入提交。构建产物位于 entry/build/default/outputs/default/。

## 项目文档

- [架构与数据流](docs/architecture.md)
- [OCR 与通知处理规则](docs/ocr-and-notifications.md)
- [仓库开发约定](AGENTS.md)
