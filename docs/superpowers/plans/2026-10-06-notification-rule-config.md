# 通知识别规则配置 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在通知设置中提供可新增和编辑的识别规则，并以工商银行、中信银行、支付宝和微信支付规则作为默认值。

**Architecture:** 使用纯 TypeScript 规则模型与解析核心，ArkTS 设置页和通知订阅扩展共用版本化本地 Preferences。两条银行规则保留当前日期、分类、备注和来源值；支付宝、微信支付各用一条规则，按捕获到的方向关键词映射收入或支出；自定义规则把规则名称写入账目来源，页面和 CSV 显示该名称。

**Tech Stack:** HarmonyOS 7 / API 26、ArkTS、ArkUI、ArkData Preferences、Node.js 22.23.2 built-in test runner、DevEco Hvigor。

**Spec:** `docs/superpowers/specs/2026-10-06-notification-rule-config-design.md`

## Global Constraints

- 规则仅存于本机。
- 此功能不改变账目数据库、通知归档、系统授权流程、通知权限或网络配置。
- 不添加第三方运行或测试依赖；规则核心 `.ts` 只使用可剥离的 TypeScript 语法，供 Node.js 内置测试运行器和 ArkTS 共同使用。
- 工商银行默认规则缺少年份时根据接收时间选择相邻且合理的年份，与当前 183 天边界逻辑一致。
- 中信银行默认规则正文不含日期时使用通知投递时间；若投递时间无效则回退到接收时间。
- 支付宝、微信支付默认规则同时检查通知标题和正文，按收支关键词判定账目方向；金额仍保存为非负数，由方向字段表达收入或支出。
- 规则存储以可选的 `defaultRulesVersion` 标记完成过默认项迁移；旧版银行默认规则仅补入支付宝、微信支付规则一次，保存的空集合或仅含自定义规则的集合不补默认项。
- 全局失败、取消和撤销通知过滤保持不变。
- 入账时间仍归整到分钟；账本仍按现有方向、金额和分钟去重。
- 自定义规则写入账目的来源字段使用规则名称；后续改名只影响新入账，既有账目的来源文本不回写。
- 文本日期策略必须在格式中显式包含 `HH` 与 `mm`；仅有日期时使用投递时间策略，避免把缺失时分伪造成午夜。
- 自定义规则名称不能使用内置来源代码或显示名，以保证 CSV 来源往返不与内置别名冲突；可选分类捕获未命中或为空时回退默认分类。
- 加载时只把正文模式完全匹配旧内置默认规则的工行/中信规则升级为新的金额格式；保留已自定义的正文模式。

## Review Focus

- 非法正则、转义括号、字符组和非捕获组会影响捕获组计数；Task 1 tests validation and group extraction.
- 工商银行跨年边界、闰日和不存在的日期会影响时间推断；Task 1 tests valid and invalid dates around the 183-day boundary.
- 首次初始化与用户主动清空都可能表现为空规则列表；Task 1 tests missing, saved-empty, and corrupt serialized values; Task 2 tests Preferences persistence.
- 多条规则命中同一来源时，顺序和首条规则字段无效的行为必须确定；Task 1 tests priority and stop-on-invalid behavior.
- 新来源标签不得把未知规则错误显示为“手动”，默认 ICBC/CITIC 标签也必须保持原样；Task 1 tests parsed source values and Task 3 checks ledger/CSV output.

---

### Task 0: Commit the reviewed design and plan

**Files:**
- Commit: `docs/superpowers/specs/2026-10-06-notification-rule-config-design.md`
- Commit: `docs/superpowers/plans/2026-10-06-notification-rule-config.md`

**Interfaces:**
- Consumes: User-approved design and this implementation plan.
- Produces: One documentation commit containing only the two listed files.

- [ ] **Step 1: Commit the reviewed design and implementation plan**

Run in PowerShell:

```powershell
git add docs/superpowers/specs/2026-10-06-notification-rule-config-design.md docs/superpowers/plans/2026-10-06-notification-rule-config.md
git commit -m "docs: 设计通知识别规则配置"
```

Expected: the commit contains those two documentation files only; existing untracked files remain unstaged.

### Task 1: Add and test the pure rule engine

**Files:**
- Create: `entry/src/main/ets/services/notificationRules/package.json`
- Create: `entry/src/main/ets/services/notificationRules/NotificationRuleModels.ts`
- Create: `entry/src/main/ets/services/notificationRules/AmountParser.ts`
- Create: `entry/src/main/ets/services/notificationRules/NotificationRuleEngine.ts`
- Modify: `entry/src/main/ets/model/LedgerModels.ets`
- Test: `tests/notification-rule-engine.test.mjs`

**Interfaces:**
- Consumes: Current notification regexes and `parseAmountFen` behavior in `BankNotificationParser.ets` and `LedgerModels.ets`.
- Produces:
  - `createDefaultNotificationRules(): NotificationRule[]`
  - `decodeNotificationRuleStore(value: string | undefined): { rules: NotificationRule[]; persistDefaults: boolean; migrated?: boolean }`; throw `Error` for malformed JSON or unsupported versions.
  - `validateNotificationRule(rule: NotificationRule): RuleValidationIssue | undefined`, where `RuleValidationIssue` is `{ field: string; message: string }`.
  - `parseNotificationEntry(input: NotificationInput, rules: NotificationRule[]): ParsedNotificationEntry | undefined`, where `NotificationInput` is `{ appName: string; bundleName: string; title?: string; body: string; deliveryTime?: number; receivedAt: number }`.
  - `ParsedNotificationEntry` has the `LedgerEntry` fields with `source: string`.
  - `parseAmountFen(value: string): number | undefined`, re-exported from `LedgerModels.ets` so existing callers retain their import path.

- [ ] **Step 1: Write Node tests for defaults, custom extraction, and validation**

Add tests for the exact ICBC/CITIC mock formats, category and note output, custom capture mapping and rule-name source, malformed regex, escaped and non-capturing parentheses, missing group references, empty saved rules, corrupted saved data, blocked notices, first-match priority, invalid dates, delivery-time fallback, and 183-day year inference. For example, an ICBC notice with body `尾号1234卡3月5日12:03支出（消费午餐）18.50元` received on March 6, 2026 produces an expense of 1850 fen at March 5, 2026 12:03, merchant `午餐`, category `消费`, source `icbc`, and note `尾号1234卡 · 动账通知`. A CITIC notice with body `尾号123456的账户支出￥18.50元` uses its positive `deliveryTime`, source `citic`, merchant `中信银行账户`, category `其他`, and note `尾号123456账户 · 通知未提供商户`.

- [ ] **Step 2: Run the tests to confirm the missing engine fails**

Run: `node --test tests/notification-rule-engine.test.mjs`

Expected: FAIL because the rule-engine modules do not exist yet.

- [ ] **Step 3: Extract `parseAmountFen` without changing its behavior**

Move the existing amount conversion body to `notificationRules/AmountParser.ts`. Re-export it from `LedgerModels.ets` so existing app imports continue to resolve to the same function. In `LedgerModels.ets`, widen `EntrySource` to `string`; the database source column is already `TEXT`, so this does not require schema migration.

- [ ] **Step 4: Define `NotificationRule` and the default rule values**

In `NotificationRuleModels.ts`, define `NotificationRule` with `id`, `name`, `enabled`, `sourceKeywords`, `bodyPattern`, `amountGroup`, `directionGroup`, `incomeText`, `expenseText`, optional `dateGroup`, `dateFormat`, `dateStrategy`, optional `merchantGroup` and `categoryGroup`, `defaultMerchant`, `defaultCategory`, ordered `categoryMappings`, `merchantPrefixToStrip`, `noteTemplate`, and optional `entrySource`. Define each category mapping as `{ text: string; matchMode: 'startsWith' | 'includes'; category: string }`, plus the normalized notification input, parsed entry, storage-state, and validation-issue interfaces. The ICBC default regex is `尾号\s*(\d{4})\s*卡\s*(\d{1,2}月\d{1,2}日\s*\d{1,2}:\d{2})\s*(支出|收入)\s*[（(]\s*([^）)]*?)\s*[）)]\s*((?:\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:[.,]\d{1,2})?))\s*元`; groups 1–5 map to account tail, `M月d日 HH:mm`, direction, transaction detail, and amount. Permit optional whitespace where the existing parser does. Configure group 4 as both merchant and category input, strip the `消费` merchant prefix, and map category in this order: starts with `消费` → `消费`, contains `ATM取款` → `取现`, contains `贷款本息` → `贷款`, otherwise `其他`. Use `infer-year`, default merchant `工商银行账户`, entry source `icbc`, and note template `尾号{{1}}卡 · 动账通知`.

The CITIC default regex is `尾号\s*(\d{3,6})\s*的账户\s*(支出|收入)\s*[¥￥]?\s*((?:\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:[.,]\d{1,2})?))\s*元`; groups 1–3 map to account tail, direction, and amount. Use `delivery-time`, default merchant `中信银行账户`, category `其他`, entry source `citic`, and note template `尾号{{1}}账户 · 通知未提供商户`. Add one Alipay and one WeChat rule with pipe-separated income/expense keywords, title-plus-body matching, an amount marked by a currency symbol or `元`, and `delivery-time`; exclude failed, cancelled, reversed, and refund notices. Encode version-1 storage decoding so a missing value seeds all four defaults, a saved empty array stays empty, and malformed or unsupported JSON raises an error instead of overwriting it. Use `defaultRulesVersion` to add the two payment-app rules once when migrating a saved store that still contains a bank default.

- [ ] **Step 5: Implement validation and deterministic parsing**

In `NotificationRuleEngine.ts`, import local `.ts` modules with explicit `.ts` extensions and use `import type` for type-only imports. Implement regex syntax checking and capture-group counting that skips escapes, character classes and non-capturing/lookaround groups, while counting named captures. Require a name, at least one non-empty source keyword, positive amount/direction group references and non-empty direction tokens; reject custom names equal to built-in source codes or display labels; require a date group for `format` and `infer-year`, with explicit `HH` and `mm` tokens; verify optional group and `{{n}}` note-template references. Parse supported date tokens `yyyy`, `MM`, `dd`, `M`, `d`, `HH`, and `mm`; treat whitespace in the format as optional to preserve the current ICBC notice variant; validate calendar rollover; infer a missing year with the existing 183-day threshold; normalize output time to the minute and set `hasTime` to `true`, matching the existing automatic-entry path. Match source keywords case-insensitively, apply the existing failure/cancel/reversal filter, and evaluate enabled rules in list order. Stop after the first source/body match even when its fields are invalid. For category selection, use the first category mapping that matches its input; if mappings exist but none match, use `defaultCategory`; if no mappings exist but `categoryGroup` is set and has a non-empty capture, use that capture; otherwise use `defaultCategory`. Remove the merchant prefix only when it appears at the beginning and use `defaultMerchant` if the result is empty. Replace a missing optional note capture with an empty string. Output `entrySource` when set or the rule name for a custom source. The service folder's `package.json` sets `type` to `module` for Node's TypeScript loader; do not add runtime enums or other TypeScript syntax that requires code generation.

- [ ] **Step 6: Run all pure-engine tests**

Run: `node --test tests/notification-rule-engine.test.mjs`

Expected: PASS for defaults, custom fields, category precedence, year boundaries, amount conversion, invalid input, precedence, and source output.

- [ ] **Step 7: Commit the engine and regression tests**

```powershell
git add entry/src/main/ets/services/notificationRules/package.json entry/src/main/ets/services/notificationRules/NotificationRuleModels.ts entry/src/main/ets/services/notificationRules/AmountParser.ts entry/src/main/ets/services/notificationRules/NotificationRuleEngine.ts entry/src/main/ets/model/LedgerModels.ets tests/notification-rule-engine.test.mjs
git commit -m "feat: 增加通知规则解析核心"
```

### Task 2: Persist and manage notification rules

**Files:**
- Create: `entry/src/main/ets/services/NotificationRuleStore.ets`
- Create: `entry/src/main/ets/pages/notifications/NotificationRuleSettingsView.ets`
- Create: `entry/src/main/ets/components/notifications/NotificationRuleEditor.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify: `entry/src/main/ets/services/CsvFormat.ets`
- Modify: entry/src/main/ets/components/settings/NotificationSettingsView.ets

**Interfaces:**
- Consumes: Task 1 rule types, codec, validator, and defaults.
- Produces:
  - `loadNotificationRules(context: common.Context): Promise<NotificationRule[]>`
  - `saveNotificationRules(context: common.Context, rules: NotificationRule[]): Promise<void>`
  - `NotificationRuleSettingsView({ onBack: () => void })`
  - A controlled editor accepting one rule plus save/cancel/delete callbacks.

- [ ] **Step 1: Implement the versioned Preferences store**

Use Preferences name `notification_rules` and key `ruleSet`. On a missing key, persist all four defaults and flush. Preserve an explicit empty list. Before loads, remove the named Preferences cache so the main app and notification extension observe the same latest value. Upgrade only an exact legacy ICBC/CITIC default body pattern to the new amount pattern and flush the result; preserve user-customized body patterns. Validate all rules before saving; reject unsupported or malformed stored values without silently reseeding them.

- [ ] **Step 2: Add the rule list and editor**

The list shows name and enabled state and supports add, edit, enable/disable, delete, and move-up/move-down ordering. The editor exposes source keywords, body regex, amount/direction/date/merchant/category capture groups, direction tokens, date format/strategy, default merchant/category, ordered category mappings, merchant prefix, and note template. Display one validation issue inline and keep the editor open when validation fails.

- [ ] **Step 3: Add settings navigation and preserve custom source labels**

Add `notificationRules` to the screen union in Index.ets, route to the rule settings page from NotificationSettingsView.ets, and return correctly from the hardware back action. In `Index.ets` and `CsvFormat.ets`, display an unknown source string as-is; keep explicit labels for existing sources. Do not modify `StatisticsView.ets`, which already displays the stored source string.

- [ ] **Step 4: Build the settings interface**

Run: `& 'H:\Program\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default assembleHap`

Expected: HAP build succeeds and the output appears under `entry/build/default/outputs/default/`.

- [ ] **Step 5: Manually exercise settings persistence and validation**

On a HarmonyOS device, open the rule page and verify all four defaults, edit/disable/delete/reorder, save and reopen, save an empty list without reseeding, reject regex `[` and an out-of-range group, and retain edited rules after restarting the app.

- [ ] **Step 6: Commit the rule store and interface**

```powershell
git add entry/src/main/ets/services/NotificationRuleStore.ets entry/src/main/ets/pages/notifications/NotificationRuleSettingsView.ets entry/src/main/ets/components/notifications/NotificationRuleEditor.ets entry/src/main/ets/pages/Index.ets entry/src/main/ets/components/settings/NotificationSettingsView.ets entry/src/main/ets/services/CsvFormat.ets
git commit -m "feat: 添加通知规则管理界面"
```

### Task 3: Connect the notification extension and verify automatic entry

**Files:**
- Modify: `entry/src/main/ets/services/BankNotificationParser.ets`
- Modify: `entry/src/main/ets/extensionability/NotificationProbeExtension.ets`
- Verify: `entry/build/default/outputs/default/`

**Interfaces:**
- Consumes: `loadNotificationRules`, `parseNotificationEntry`, and the current `LedgerRepository.addNotificationEntry`.
- Produces: The existing notification callback loads the latest rules and sends at most one successfully parsed `LedgerEntry` through the existing deduplicating repository path.

- [ ] **Step 1: Adapt NotificationInfo to the pure parser input**

Keep the existing `parseBankNotificationEntry` export in `BankNotificationParser.ets` with the signature `parseBankNotificationEntry(info: notificationExtensionSubscription.NotificationInfo, receivedAt: number, rules: NotificationRule[]): LedgerEntry | undefined`. Pass `appName`, `bundleName`, body text and delivery time to the pure engine.

- [ ] **Step 2: Load fresh rules in the extension queue**

In `recordAutomaticLedgerEntry`, await `loadNotificationRules(this.context)` before parsing each queued notification. Keep archive writes and probe recording independent. If loading/parsing fails, log the existing automatic-entry failure and do not write a partial ledger row.

- [ ] **Step 3: Run the pure-engine tests**

Run: `node --test tests/notification-rule-engine.test.mjs`

Expected: PASS for all pure-engine and rule-codec cases.

- [ ] **Step 4: Build the HAP**

Run: `& 'H:\Program\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default assembleHap`

Expected: the command reports a successful build, and the HAP appears under `entry/build/default/outputs/default/`.

- [ ] **Step 5: Verify default and custom notification flows on device**

Using the existing ICBC and CITIC mock apps, verify the bank defaults. On-device sample notifications, verify that the Alipay and WeChat defaults map configured incoming/outgoing keywords to direction, parse symbol/unit-marked amounts, and skip failed, cancelled, and refund notices. Send a duplicate notice and confirm the existing ledger deduplication leaves one row. Add a custom rule above the matching default, send a matching mock notice, and verify the rule name appears as the source in the ledger and exported CSV. Change the rule and verify the next notice uses the saved rule without restarting the app. Do not modify the mock-app projects.

- [ ] **Step 6: Check the final diff**

Run: `git diff --check`

Expected: no whitespace errors, and only the planned integration files have changed since Task 2.

- [ ] **Step 7: Commit the integration**

```powershell
git add entry/src/main/ets/services/BankNotificationParser.ets entry/src/main/ets/extensionability/NotificationProbeExtension.ets
git commit -m "feat: 按通知规则自动入账"
```

Expected: the commit contains only the two integration files.
