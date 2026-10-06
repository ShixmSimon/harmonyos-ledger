# OCR 识别规则实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将通知规则纯逻辑模块改为 `.ets`，并为微信、支付宝和工行截图 OCR 增加可编辑、本机持久化的规则集。

**Architecture:** 通知和 OCR 保留独立的规则模型与引擎。OCR 规则驱动来源匹配及字段文本模板，账单列表和银行明细两种布局策略继续读取 `OcrLine` 坐标并关联相邻文字；所有解析结果仍交给现有复核流程。

**Tech Stack:** HarmonyOS 7 / API 26、ArkTS / ArkUI、ArkData Preferences、Node.js 22.23.2 内置测试运行器、DevEco Hvigor。

**Spec:** `docs/superpowers/specs/2026-10-06-ocr-recognition-rules-design.md`

## Global Constraints

- 使用 HarmonyOS 7 / API 26、Stage 模型和 ArkTS。
- 通知规则和 OCR 规则各自使用独立模型、引擎和 Preferences 名称。
- `harmony_ledger.db` 与 `ledger_entries` 表结构不变，不通过删除数据库处理兼容问题。
- OCR 缺少可靠日期时不得补造日期；失败、取消和撤销的交易不得入账；退款方向必须由用户确认。
- 截图只生成草稿；用户复核与确认仍是写入账本的唯一入口。
- OCR 继续保留 `OcrLine` 坐标及布局策略，金额仍以整数分保存。
- 新规则只使用现有 `wechat`、`alipay`、`icbc` 来源；新来源不在本次范围。
- 不引入第三方运行或测试依赖；Node 测试加载纯逻辑 `.ets` 文件时使用 Node 22 内置 TypeScript 类型剥离与模块钩子。
- 所有规则保存在本机 Preferences，不上传或记录新的敏感截图数据。

## Review Focus

- 来源分数相同或低于阈值时是否仍进入手动来源选择；Task 2 与 Task 3 覆盖。
- 非法正则及超出捕获组数量的编号是否被拒绝保存；Task 2 与 Task 4 覆盖。
- 微信/支付宝相邻行字段与工行明细块是否仍按坐标归属；Task 3 用合成坐标行覆盖。
- 用户保存的空规则集、禁用状态和规则排序是否在后续导入中生效且不被默认规则覆盖；Task 4 覆盖。
- 文件选择、分享导入和手动选择来源是否都传入同一份已加载规则；Task 4 覆盖。

---

### Task 1: 把通知规则纯逻辑模块迁移为 `.ets`

**Files:**
- Rename: `entry/src/main/ets/services/notificationRules/AmountParser.ts` → `AmountParser.ets`
- Rename: `entry/src/main/ets/services/notificationRules/NotificationRuleModels.ts` → `NotificationRuleModels.ets`
- Rename: `entry/src/main/ets/services/notificationRules/NotificationRuleEngine.ts` → `NotificationRuleEngine.ets`
- Modify: `entry/src/main/ets/model/LedgerModels.ets`
- Modify: `tests/notification-rule-engine.test.mjs`
- Create: `tests/register-ets-loader.mjs`

**Interfaces:**
- Consumes: Existing notification rule exports and `parseAmountFen` behavior.
- Produces: Existing imports resolve to `.ets` files; notification rule APIs and persisted JSON shape stay unchanged.

- [ ] **Step 1: Add the Node `.ets` loader and point the regression test at `.ets` modules**

Create the test-only loader with `registerHooks` and `stripTypeScriptTypes` from `node:module`, and update the existing test imports to `.ets` paths. Keep existing behavior assertions intact.

- [ ] **Step 2: Run the test before renaming production modules**

Run: `node --import ./tests/register-ets-loader.mjs --test ./tests/notification-rule-engine.test.mjs`
Expected: FAIL because the referenced `.ets` modules do not exist yet.

- [ ] **Step 3: Rename the modules and update imports**

Rename the three production files, update `NotificationRuleEngine.ets` type and value imports to extensionless local module paths, and keep `LedgerModels.ets` re-exporting `parseAmountFen` through its existing API.

- [ ] **Step 4: Run regression tests through the loader**

Teach the loader to resolve extensionless local imports to `.ets` files under the pure logic directories. Load only those modules as ES modules; keep the loader out of app runtime code.

Run: `node --import ./tests/register-ets-loader.mjs --test ./tests/notification-rule-engine.test.mjs`
Expected: PASS with the same notification rule and amount conversion behavior.

### Task 2: Define and validate OCR rules

**Files:**
- Create: `entry/src/main/ets/services/ocrRules/OcrRuleModels.ets`
- Create: `entry/src/main/ets/services/ocrRules/OcrRuleEngine.ets`
- Create: `tests/ocr-rule-engine.test.mjs`
- Modify: `tests/register-ets-loader.mjs`

**Interfaces:**
- Consumes: `ImportSource`, `DraftEntry`, `OcrLine`, and current defaults in `OcrSourceDetector.ets`, `ReceiptParser.ets`, and `IcbcParser.ets`.
- Produces:
  - `createDefaultOcrRules(): OcrRule[]` with one profile each for WeChat, Alipay, and ICBC; default source thresholds preserve the current minimum score 4 and margin 2.
  - `validateOcrRule(rule: OcrRule): OcrRuleValidationIssue | undefined`.
  - `decodeOcrRuleStore(value: string | undefined): OcrRuleLoadResult`, for `{ version: 1, rules: OcrRule[] }`; a missing value seeds defaults, an explicitly saved empty list remains empty, and malformed or unsupported data throws instead of reseeding.
  - `selectOcrRule(text: string, rules: OcrRule[], selectedSource?: ImportSource): OcrRule | undefined`, applying weighted matchers, threshold and margin, or restricting selection to the manually selected source.

- [ ] **Step 1: Add failing tests for defaults, selection, storage decoding, and validation**

Cover the three source defaults, weighted matching, low-score and ambiguous-source rejection, manual source restriction, malformed regexes, invalid capture groups, missing stored value, saved-empty value, and invalid serialized data.

- [ ] **Step 2: Run the OCR engine tests to confirm the APIs are missing**

Run: `node --import ./tests/register-ets-loader.mjs --test ./tests/ocr-rule-engine.test.mjs`
Expected: FAIL because the OCR rule modules and exports do not exist.

- [ ] **Step 3: Define the OCR rule model and defaults**

Define `OcrRule`, `OcrPattern` (`pattern` plus 1-based `groupIndex`), `OcrSourceMatcher` (`pattern` plus positive `weight`), `OcrCategoryMapping`, `OcrRuleStore`, `OcrRuleLoadResult`, and `OcrRuleValidationIssue`. Each profile includes its ledger source, layout strategy (`receipt-list` or `icbc-statement`), weighted source expressions, minimum score and margin, required amount/date patterns, optional time/direction/merchant/category patterns, date format, income/expense keywords, failure/refund/summary pattern lists, default category, and category mappings. The existing three detector rules use threshold 4 and margin 2. Encode the current source scores and parser field templates as defaults.

- [ ] **Step 4: Implement rule validation, selection, and store decoding**

Count regex capture groups while ignoring escapes, character classes, and non-capturing groups. Reject malformed expressions, invalid group references, invalid scores, missing source, and invalid layout strategy. Score each source by its highest matching enabled profile; preserve rule list order for same-source ties. Reject unsupported store versions and malformed serialized rule data rather than silently restoring defaults.

- [ ] **Step 5: Run OCR engine tests**

Run: `node --import ./tests/register-ets-loader.mjs --test ./tests/ocr-rule-engine.test.mjs`
Expected: PASS for default rules, scoring, ambiguity, validation, and storage codec cases.

### Task 3: Pass OCR rules through coordinate-aware parsers

**Files:**
- Modify: `entry/src/main/ets/services/OcrSourceDetector.ets`
- Modify: `entry/src/main/ets/services/ReceiptParser.ets`
- Modify: `entry/src/main/ets/services/IcbcParser.ets`
- Modify: `entry/src/main/ets/services/OcrImportCoordinator.ets`
- Modify: `tests/ocr-rule-engine.test.mjs`

**Interfaces:**
- Consumes: `OcrRule[]` selected by `OcrRuleEngine`.
- Produces:
  - `ReceiptParser.parse(lines, source, rule, existing, priorDrafts, captureTime): DraftEntry[]`.
  - `IcbcParser.parse(lines, rule, existing, priorDrafts, captureTime): DraftEntry[]`.
  - `OcrImportCoordinator.parsePages(pages, existing, rules): OcrImportResult` and `parsePage(lines, source, existing, rules, priorDrafts = [], captureTime?): DraftEntry[]`.

- [ ] **Step 1: Add failing coordinate-based parser cases**

Use synthetic `OcrLine` data to cover a WeChat/Alipay receipt list with neighboring merchant/date lines and an ICBC statement with date headers and transaction blocks. Also cover failure/summary filtering, refund direction warning, no-date omission, and multiple same-source profiles where the first profile produces no valid transaction.

- [ ] **Step 2: Run the parser cases to confirm rule injection is missing**

Run: `node --import ./tests/register-ets-loader.mjs --test ./tests/ocr-rule-engine.test.mjs`
Expected: FAIL because parsers and coordinator do not yet accept or apply OCR rules.

- [ ] **Step 3: Inject configurable field expressions without removing layout logic**

Apply amount/date/time/direction/merchant/category expressions and failure/refund/summary filters to each layout strategy. Keep row clustering, nearby-row association, bank block boundaries, and date context in the existing parser strategies. Attempt same-source profiles in visible order and return only the first profile that produces a draft with reliable date and amount.

- [ ] **Step 4: Route automatic and manual source selection through the OCR engine**

Make `OcrSourceDetector` delegate rule scoring to `OcrRuleEngine`; make `OcrImportCoordinator` pass rules to the selected parser and preserve unclassified-page behavior when source matching is ambiguous.

- [ ] **Step 5: Run parser regression cases**

Run: `node --import ./tests/register-ets-loader.mjs --test ./tests/ocr-rule-engine.test.mjs`
Expected: PASS while all valid dates, integer-fen amounts, directions, category defaults, refunds, and source labels match the expected drafts.

### Task 4: Persist and edit OCR rules in the app

**Files:**
- Create: `entry/src/main/ets/services/OcrRuleStore.ets`
- Create: `entry/src/main/ets/pages/ocr/OcrRuleSettingsView.ets`
- Create: `entry/src/main/ets/components/ocr/OcrRuleEditor.ets`
- Modify: `entry/src/main/ets/components/settings/SettingsView.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes: OCR rule model, engine validation/defaults, and Preferences.
- Produces: `loadOcrRules(context: common.Context): Promise<OcrRule[]>`, `saveOcrRules(context: common.Context, rules: OcrRule[]): Promise<void>`, and an OCR rule settings page with add/edit/enable/disable/reorder/delete operations.

- [x] **Step 1: Implement independent Preferences storage**

Use Preferences name `ocr_recognition_rules` and key `ruleSet`. On load, clear that preference cache before reading, persist defaults only when the key is absent, and preserve edited and empty rules. Validate every rule before saving, serialize version 1, and flush writes.

- [x] **Step 2: Add the OCR rules list and editor**

Expose source, layout strategy, weighted source expressions, thresholds, field expressions/group numbers, date format, income/expense keywords, default category, category mappings, and filter expressions. Reject invalid regexes and group numbers without closing the editor.

- [x] **Step 3: Add settings navigation**

Add `onOpenOcrRules` to `SettingsView`, add `ocrRules` to the `Index` screen union and route to `OcrRuleSettingsView`; return to settings through both the page back button and system back handling.

- [x] **Step 4: Load one rule snapshot for each OCR import path**

Load the latest rules before parsing screenshots in the picker and share-import paths. Pass the same snapshot to automatic source detection, manual source selection, and the parsers; do not load preferences from the pure coordinator.

- [x] **Step 5: Build the HAP**

Run: `& 'H:\Program\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default assembleHap`
Expected: successful build and HAP under `entry/build/default/outputs/default/`.

### Task 5: Verify persistence, imports, and final diff

**Files:**
- Verify: `tests/notification-rule-engine.test.mjs`
- Verify: `tests/ocr-rule-engine.test.mjs`
- Verify: `entry/build/default/outputs/default/`

- [x] **Step 1: Run both Node rule suites**

Run: `node --import ./tests/register-ets-loader.mjs --test ./tests/notification-rule-engine.test.mjs ./tests/ocr-rule-engine.test.mjs`
Expected: PASS for existing notification rules and OCR defaults, matching, validation, coordinate parsing, and serialization.

- [x] **Step 2: Check whitespace and tracked changes**

Run: `git diff --check`
Expected: no whitespace errors; no signing material, OCR images, real notification content, databases, or build output is tracked.

Then run: `git status --short`
Expected: only planned source and test files are changed or untracked.

- [x] **Step 3: Verify on HarmonyOS 7 / API 26 when a device is available**

Check default WeChat/Alipay/ICBC screenshots, ambiguous-source manual selection, field-rule editing and restart persistence, edited empty-rule behavior, share import, draft review, and confirmed ledger save. Do not use real financial screenshots as committed fixtures. If no compatible device is available, record that device verification was not completed.

Device verification performed: installed and launched the HAP on HarmonyOS 7.0 / API 26, opened OCR rule settings, saved a temporary fourth rule, force-stopped and restarted the app to confirm the rule persisted, then deleted it and confirmed the three defaults remained. The photo picker/share OCR path through draft review and ledger save was not manually exercised because no synthetic screenshot fixture was prepared; parser and routing cases are covered by the Node suite.
