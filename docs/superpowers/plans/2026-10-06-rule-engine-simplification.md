# OCR 与通知规则引擎精简实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 允许用户通过 AI 生成的精简规则 JSON，在应用内添加常见 OCR 版式和通知格式，同时保留现有默认行为、已保存规则和入账复核保护。

**Architecture:** OCR 与通知解析仍留在现有服务中。新增带版本号的导入描述和本地校验层，再由 OCR、通知两个适配器分别编译成运行时规则。OCR 增加通用视觉行和起始锚点解析，工商银行保留兼容解析器。规则页面提供提示词复制、粘贴、样例本地预览和明确的保存确认。不增加 AI 服务或网络调用。

**Tech Stack:** ArkTS / ArkUI、ArkData Preferences、现有正则和解析引擎、Node.js 内置测试运行器与 `tests/register-ets-loader.mjs`、HarmonyOS 7 / API 26 构建和设备验证。

**Spec:** [OCR 与通知规则引擎精简设计](../specs/2026-10-06-rule-engine-simplification-design.md)

## Global Constraints

- 不改账本数据库结构，也不重新处理历史账目。
- 保留规则顺序、启用状态、自定义规则、空规则集和旧版 OCR/通知行为。损坏或未知版本的数据不得被默认规则覆盖。
- AI 提示词生成、粘贴 JSON 校验和样例预览全部在本地完成；预览样例不持久化，不向服务发送原文。
- 导入规则必须先展示给用户，并在成功预览后由用户明确确认保存。
- 对无法安全转译的旧规则继续使用工商银行及收据兼容解析路径。
- 新 OCR 来源使用现有字符串来源字段，并在草稿和来源手动选择界面展示配置的名称。
- 新导入格式和编辑器不得要求用户维护数字捕获组编号。
- 遵循仓库 ArkTS 约束；除非实现证明确有必要，不扩展下列文件清单。

## File Map

### 导入格式和适配器

- `entry/src/main/ets/services/ruleImport/RuleImportModels.ets`（新增）：OCR/通知导入信封、精简规则描述、可选预览样例、校验诊断和预览结果类型。
- `entry/src/main/ets/services/ruleImport/RuleImportEngine.ets`（新增）：JSON 解码、类型/版本检查、字段校验、正则编译检查和提示词生成。此模块不得访问 Preferences、网络 API 或 UI 状态。
- `entry/src/main/ets/services/ruleImport/OcrRuleImportAdapter.ets`（新增）：将精简 OCR 描述编译为 `OcrRule`，并在不保存的情况下运行预览样例。
- `entry/src/main/ets/services/ruleImport/NotificationRuleImportAdapter.ets`（新增）：将精简通知描述编译为 `NotificationRule`，并在不保存的情况下运行预览样例。
- `tests/rule-import-engine.test.mjs`（新增）：覆盖导入 JSON 校验、版本/类型错误、缺少必需字段、非法表达式、样例数据结构和提示词内容。

### OCR 运行时与配置

- `entry/src/main/ets/model/LedgerModels.ets`：将 `ImportSource` 放宽为配置驱动的字符串来源标识，同时保留现有内置标识。
- `entry/src/main/ets/model/OcrModels.ets`、`entry/src/main/ets/services/OcrImporter.ets`：将图片宽度带入已识别页和待确认来源页，供归一化列范围使用。
- `entry/src/main/ets/services/ocrRules/OcrRuleModels.ets`：增加显示名称、通用记录/字段/列配置，并保留解码旧版规则所需的兼容标识和字段。
- `entry/src/main/ets/services/ocrRules/OcrRuleEngine.ets`：默认规则、校验、唯一最高匹配数的来源选择、旧规则解码/迁移和通用表达式工具。
- `entry/src/main/ets/services/OcrSourceDetector.ets`：返回选中的规则/来源信息，不再假设来源只能来自固定联合类型。
- `entry/src/main/ets/services/OcrImportCoordinator.ets`：通用布局调用通用解析器，旧版收据规则继续调用 `ReceiptParser`，旧版工行规则继续调用 `IcbcParser`，并使用规则配置的展示名称。
- `entry/src/main/ets/services/GenericOcrParser.ets`（新增）：视觉行聚合、普通行或起始锚点记录分组、可选横向列筛选和字段提取。
- `entry/src/main/ets/pages/import/OcrImportView.ets`：从启用的 OCR 规则生成手动来源选项，替换写死的微信/支付宝/工行按钮。
- `entry/src/main/ets/components/ocr/OcrRuleEditor.ets`：编辑通用记录和字段模型，不显示捕获组编号；高级过滤仍可配置。
- `entry/src/main/ets/pages/ocr/OcrRuleSettingsView.ets`：显示动态来源并添加提示词/导入/预览流程。
- `tests/ocr-rule-engine.test.mjs`：更新固定来源和加权阈值断言，覆盖默认行为、通用版式、动态来源、歧义、迁移及手动选择。

### 通知运行时与配置

- `entry/src/main/ets/services/notificationRules/NotificationRuleModels.ets`：为新规则增加语义捕获，同时保留旧版规则数字捕获映射。
- `entry/src/main/ets/services/notificationRules/NotificationRuleEngine.ets`：新规则使用语义字段，旧规则沿用原捕获映射、默认拦截条件及首条匹配规则行为。
- `entry/src/main/ets/services/NotificationRuleStore.ets`：保存校验后的新格式，并保留现有 Preferences 键和安全迁移行为。
- `entry/src/main/ets/components/notifications/NotificationRuleEditor.ets`：新规则编辑语义捕获；必要时保留旧规则兼容编辑方式。
- `entry/src/main/ets/pages/notifications/NotificationRuleSettingsView.ets`：添加通知提示词/导入/预览流程。
- `tests/notification-rule-engine.test.mjs`：覆盖命名语义捕获、缺少金额/方向、默认规则和拦截词、旧规则解析及迁移。

### 文档

- `docs/ocr-and-notifications.md`：说明精简 JSON、样例预期、本地预览和保存步骤、通用 OCR 分组、动态来源及旧规则兼容。
- `docs/architecture.md`：更新导入适配器和规则预览数据流，不改变现有数据职责边界。

## Interfaces

外部精简格式使用统一的带版本号信封，与内部持久化运行时规则分开。OCR 样例如下：

```json
{
  "schemaVersion": 1,
  "kind": "ocr",
  "rule": {
    "name": "示例钱包",
    "source": { "id": "example-wallet", "name": "示例钱包", "patterns": ["Example Wallet"] },
    "record": { "mode": "row" },
    "fields": {
      "amount": "金额[:：]\\s*([+-]?\\s*[¥￥]?\\s*[\\d,.]+)",
      "date": "日期[:：]\\s*((?:20\\d{2}[-/.年])?\\d{1,2}[-/.月]\\d{1,2}日?)",
      "direction": "(收入|支出)",
      "merchant": "商户[:：]\\s*(.+)"
    },
    "incomeKeywords": ["收入"],
    "expenseKeywords": ["支出"],
    "defaultCategory": "其他",
    "columns": { "amount": { "left": 0.65, "right": 0.98 } }
  },
  "examples": [
    { "input": "...", "expected": { "amount": "12.34", "direction": "expense" } }
  ]
}
```

锚点模式将 `record` 写为 `{"mode":"anchor","anchor":"交易[:：]"}`；每个匹配锚点开启一条记录块，块持续到下一个匹配锚点或输入结束。`columns` 可按字段指定 `left`/`right` 的 0 到 1 归一化横坐标。

通知规则示例：

```json
{
  "schemaVersion": 1,
  "kind": "notification",
  "rule": {
    "name": "示例支付",
    "sourceKeywords": ["ExamplePay", "example.pay"],
    "bodyPattern": "(?<direction>收入|支出).*?(?<amount>[¥￥]?[\\d,.]+)(?:元)?(?:.*?(?<merchant>.+))?",
    "incomeText": "收入",
    "expenseText": "支出",
    "dateFormat": "",
    "dateStrategy": "delivery-time",
    "defaultMerchant": "示例支付",
    "defaultCategory": "其他"
  },
  "examples": [
    { "input": "支出 1,031.10元 示例商户", "expected": { "amount": "1,031.10", "direction": "expense" } }
  ]
}
```

通知规则还可选填 `entrySource`；省略时由应用根据规则名称生成账目来源。`dateStrategy` 使用 `format`、`infer-year` 或 `delivery-time`。`date`、`merchant`、`category` 捕获可选，并配置收入/支出关键词及缺省商户/分类。OCR 表达式内部固定取第一个捕获组，精简描述不包含数字组号。样例可选且只用于当前预览。

稳定模块接口：

```ts
parseRuleImport(text: string, expectedKind: RuleImportKind): RuleImportParseResult
createOcrRule(description: CompactOcrRule, existingRules: OcrRule[]): OcrRule
previewOcrRule(rule: OcrRule, examples: RuleImportExample[]): RuleImportPreview[]
createNotificationRule(description: CompactNotificationRule, existingRules: NotificationRule[]): NotificationRule
previewNotificationRule(rule: NotificationRule, examples: RuleImportExample[]): RuleImportPreview[]
```

`parseRuleImport` 返回已校验的类型化描述和临时样例，或带字段路径的错误。适配器只返回运行时规则和预览结果。设置页只有在用户确认预览、且现有保存流程成功后，才将新规则追加到规则集。

## Implementation Tasks

### 1. 添加版本化导入描述和本地校验器

- [x] 在 `RuleImportModels.ets` 和 `RuleImportEngine.ets` 定义导入类型及校验器。
- [x] 定义并校验上述 OCR 字段；`record.mode` 取 `row` 或 `anchor`，锚点模式必须提供锚点表达式。字段表达式取第一个捕获组；可选列范围使用 0 到 1 的归一化左右边界。
- [x] 定义并校验通知来源关键词、命名正文捕获、方向词、日期策略和可选商户/分类缺省值。必须包含语义 `amount` 和 `direction` 捕获，拒绝重复或未知捕获名称。
- [x] 校验 JSON 结构、`schemaVersion === 1`、目标 `kind`、必填字段、表达式语法、范围边界和可选样例。把解析异常转成具体字段错误，不将原始异常直接显示在界面。
- [x] 为两类规则添加提示词生成器。提示词说明精简格式，只要求根据样例可判断的信息，并附一个不包含运行时字段的有效小样例。
- [x] 在 `tests/rule-import-engine.test.mjs` 覆盖有效 OCR/通知 JSON、错误类型/版本、错误 JSON、缺少必需捕获、非法正则/范围、未知捕获名和提示词内容。
- [x] 执行 `node --import ./tests/register-ets-loader.mjs --test tests/rule-import-engine.test.mjs`；预期导入格式和校验测试全部通过。

### 2. OCR 来源动态化并安全迁移已保存规则

- [x] 更新 `OcrRuleModels.ets`，表达来源 id/名称、无权重来源匹配式和通用记录配置，同时保留解码旧版格式所需字段。
- [x] 更新 `OcrRuleEngine.ets` 默认规则，用新模型保持微信、支付宝和工行当前行为；移除用户可配的分数门槛/分差，只有唯一最高匹配数时才自动选中来源。
- [x] 更新 `selectOcrRule` 和 `OcrSourceDetector.detect`，返回选中规则（含展示名称和来源 id）；自动识别零匹配或并列时不选来源。用户手动选择后，只在该来源 id 下尝试规则。
- [x] 将版本 1 数据解码为兼容形式，保留规则顺序、启用状态、正则和收据/工行解析器选择；完整验证成功后才写入新版本。空集合保持为空，损坏或未知格式明确报错。
- [x] 更新 `OcrRuleStore.ets` 和所有来源类型调用处，使用新规则存储版本，但不改 Preferences 键或账本数据库结构。
- [x] 更新 `tests/ocr-rule-engine.test.mjs`，覆盖动态来源 id、并列歧义、唯一最高匹配、手动来源限制、旧规则迁移与幂等重载、损坏数据拒绝和内置来源行为。
- [x] 执行 `node --import ./tests/register-ets-loader.mjs --test tests/ocr-rule-engine.test.mjs`；预期旧规则行为保留，动态来源 id 往返保存正确。

### 3. 实现并验证通用 OCR 解析器

- [x] 新增 `GenericOcrParser.ets`，使用现有 `OcrLine` 坐标确定性地聚合视觉行，支持普通行模式和起始锚点记录块模式。
- [x] 对每条候选记录先应用可选列范围，再匹配字段。将图片宽度从 `OcrImporter.ets` 带入 `OcrRecognizedPage` 和 `UnclassifiedOcrPage`，使归一化 0–1 列边界能稳定映射到 OCR 坐标。金额/日期和可选时间/方向/商户/分类均按配置提取，固定取第一个捕获组。
- [x] 尽量复用现有日期校验、分转金额、方向关键词、分类映射、失败/退款/汇总过滤、查重和草稿构造逻辑。日期或金额无效、不可靠的记录不生成草稿。
- [x] 更新 `OcrImportCoordinator.ets`：新通用规则走新解析器，已保存的版本 1 收据/工行规则在安全转译前分别走 `ReceiptParser`/`IcbcParser`。不改变导入确认和查重行为。
- [x] 更新 `OcrRuleEngine.ets` 校验通用模式、锚点必需项、第一个捕获组、列范围及过滤配置。
- [x] 扩展 `tests/ocr-rule-engine.test.mjs`，覆盖至少一种列表/表格布局和一种多行锚点布局、横向列筛选、多条记录、汇总/失败/退款过滤、无效日期、缺少金额/方向、捕获组提取及 `1,031.10`、`12,345,678.90` 等带千分位金额。
- [x] 执行 `node --import ./tests/register-ets-loader.mjs --test tests/ocr-rule-engine.test.mjs`；预期现有默认样例和工行回归用例继续通过。

### 4. 接入 OCR 精简规则导入和动态手动来源选择

- [x] 添加 `OcrRuleImportAdapter.ets`：将有效 OCR 描述编译成启用状态的运行时规则，生成不冲突的 id；调用真实 OCR 解析器运行预期样例，但不触及 Preferences。
- [x] 更新 `OcrRuleSettingsView.ets`，加入复制提示词、粘贴/导入、错误展示、样例预览、编辑和明确确认保存流程。实现前确认 HarmonyOS 7/API 26 剪贴板 API；剪贴板不可用时保留文本输入入口。
- [x] 确保复制和导入只影响当前导入草稿。样例和预览结果不得交给 `saveOcrRules`，也不得写入 Preferences。
- [x] 更新 `OcrRuleEditor.ets`，编辑来源名称/id、简单来源表达式、行/锚点模式、常用字段正则和可选归一化列；失败/退款/汇总及分类映射放入折叠的高级配置。不显示分数阈值和组号。
- [x] 更新 `OcrImportView.ets`，按启用规则列出手动来源，显示其配置名称，并将所选来源 id 传给协调器。
- [x] 扩展 OCR 测试，验证适配器预览使用真实解析结果、预览未保存、动态手动来源可用、确认保存后重新加载仍存在。
- [x] 执行任务 3 的 OCR 测试命令；预期预览输出符合样例预期字段，保存后的规则 JSON 不含临时样例。

### 5. 添加通知语义捕获并兼容旧规则

- [x] 更新 `NotificationRuleModels.ets`，区分新规则语义捕获与已存规则数字捕获。
- [x] 更新 `NotificationRuleEngine.ets`：新规则要求命名 `amount`、`direction`，`date`/`merchant`/`category` 可选；方向仍需通过收入/支出关键词校验。旧规则继续使用原捕获映射和匹配行为。
- [x] 若 API 26 正则运行时对命名捕获组的支持与 Node 不同，则添加小型编译适配器，在内部解析语义名称到运行时捕获位置；精简格式和编辑器中都不暴露编号。
- [x] 幂等迁移已保存通知规则，不改写用户自定义旧正则。保留默认失败/取消/撤销/退款拦截、首条匹配规则所有权、来源关键词及来源/日期回退行为。
- [x] 按需更新 `NotificationRuleStore.ets` 进行已验证的版本迁移；不改 Preferences 键、通知归档或账本数据库结构。
- [x] 更新 `NotificationRuleEditor.ets`，新规则编辑语义字段，旧规则保留清晰的兼容编辑路径。
- [x] 扩展 `tests/notification-rule-engine.test.mjs`，覆盖语义捕获、可选字段、缺金额/方向拒绝、重复/缺失名称、旧规则、迁移往返、默认银行/钱包规则、失败/退款拦截及 `1,031.10`、`12,345,678.90` 等标准千分位金额。
- [x] 执行 `node --import ./tests/register-ets-loader.mjs --test tests/notification-rule-engine.test.mjs`；预期旧测试和新语义规则分别在对应路径解析正确。

### 6. 接入通知精简规则导入和预览

- [x] 添加 `NotificationRuleImportAdapter.ets`，将精简描述编译为通知运行时规则，并通过 `parseNotificationEntry` 对本地合成输入运行每个样例。
- [x] 更新 `NotificationRuleSettingsView.ets`，加入复制提示词、粘贴/导入、字段错误、样例预览和明确确认保存。
- [x] 预览只用当前通知元数据构造本地输入；不得归档预览内容或自动入账。仅在用户确认后通过 `saveNotificationRules` 保存规则。
- [x] 扩展通知测试，验证预览与期望输出比对、无效导入不保存、确认后重载保留规则、样例正文不出现在保存的规则数据中。
- [x] 执行任务 5 的通知测试命令；预期预览和正式通知处理调用相同的运行时解析器。

### 7. 更新说明文档并完成验证

- [x] 更新 `docs/ocr-and-notifications.md`，说明样例需提供的信息、复制提示词→交给外部 AI→粘贴 JSON→本地预览→明确保存的流程、OCR 行/锚点概念、通知命名字段、迁移行为和版式能力边界。
- [x] 更新 `docs/architecture.md` 的导入适配器与本地预览流程，确认文档未描述网络调用或数据库变更。
- [x] 执行 `node --import ./tests/register-ets-loader.mjs --test`；预期自动发现并运行全部 `tests/*.test.mjs`，规则和导航用例全部通过。
- [x] 按仓库文档中的 PowerShell 步骤构建 HAP：设置本机 `$env:DEVECO_SDK_HOME`，然后执行 `& $hvigor --mode module -p product=default assembleHap`，确认构建状态及产物。
- [x] 在可用的 API 26 设备上核对提示词复制/粘贴、有效/无效导入、OCR 行和锚点规则、动态手动来源、旧通知规则编辑、通知预览/保存。设备不可用时明确记录（已确认 `hdc list targets` 无设备目标，未完成真机交互验证）。
- [x] 执行 `git diff --check` 并确认无空白错误；再检查无数据库结构变化、网络调用、凭据、通知样例或 OCR 样例写入持久化数据。

## Review Focus

- **Preferences 安全：**任务 2 和 5 的测试证明迁移幂等，保留顺序/启用状态/自定义规则，空集合仍为空；损坏/未知数据报错且不恢复默认。
- **OCR 兼容与来源选择：**任务 2–4 的测试证明微信/支付宝/工行行为仍在、自定义来源可用、并列需手动选择、手动选择不会尝试其他来源。
- **记录分组与字段提取：**任务 3 的测试证明行/锚点、列、金额/日期/方向及失败/退款/汇总过滤有效；无效日期或金额不会生成草稿。
- **通知安全：**任务 5 的测试证明语义字段有效，字段不全或规则无效不会入账，默认规则继续拦截失败/取消/撤销/退款通知，旧数字组规则仍可读取。
- **AI 导入边界：**任务 1、4、6 的测试证明错误版本/类型/正则/捕获组产生明确错误，预览使用正式解析器，样例不持久化，只有明确确认才保存。
- **运行时/API 兼容：**任务 4、5、7 在 HarmonyOS 7 / API 26 目标上验证剪贴板和正则方案；Node 测试不能替代设备验证。
