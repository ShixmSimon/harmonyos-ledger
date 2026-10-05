# 架构与数据流

## 模块职责

| 目录 | 职责 |
| --- | --- |
| pages/ | 页面状态、查询状态、编辑和导入流程 |
| components/ | 受控展示组件，以属性接收数据、以回调上报交互 |
| model/ | 账目、草稿和通知归档类型，以及金额和日期格式化 |
| data/ | ArkData relationalStore 读写和数据库初始化 |
| services/ | OCR、来源检测、账单解析、通知解析和统计计算 |
| state/ | 分享导入等跨扩展入口的短期应用状态 |
| entryability/ | EntryAbility 启动、前后台切换与宿主能力 |
| extensionability/ | 图片分享导入、通知订阅等扩展入口 |

Index.ets 负责页面切换和跨页面操作协调。数据计算与数据库访问不应放进展示组件。

~~~mermaid
flowchart LR
  User[用户] --> Index[Index 页面协调]
  Index --> Picker[系统图片选择器]
  Picker --> OCR[Core Vision 本地 OCR]
  OCR --> Parser[来源检测与账单解析]
  Parser --> Review[逐条复核]
  Review --> Ledger[LedgerRepository]
  Ledger --> LedgerDB[(harmony_ledger.db)]
  Notify[系统通知订阅] --> Extension[NotificationProbeExtension]
  Extension --> Archive[NotificationArchiveRepository]
  Archive --> ArchiveDB[(notification_archive.db)]
  Extension --> Ledger
  Index --> Stats[LedgerStatistics]
  Index --> CSV[CsvExporter]
~~~

## 本地数据库

### 账本

账本存放在 harmony_ledger.db 的 ledger_entries 表。金额使用 amount_fen 整数分保存，direction 区分收入和支出；happened_at 保存本地时间戳，has_time 表示是否识别到具体时分。只有日期的 OCR 账目以当天日期保存，但 has_time 为 false；显示和导出时不显示虚构的时分。

既有字段包括 id、happened_at、amount_fen、direction、source、merchant、category、note 和 has_time。这个结构已经有本机用户数据，新增或改变字段必须考虑迁移，不能以删除数据库的方式绕过兼容。

LedgerRepository 在通知自动入账和分类更新后发出跨进程数据变更事件。Index 监听事件，并在回到账本、统计或导入流程时重新读取账目，使通知扩展写入的数据能反映到当前页面。

### 通知归档

通知标题、正文和系统来源字段独立存放于 notification_archive.db 的 notification_events 表。归档与自动记账分别使用自己的异步队列和错误处理：归档失败不会阻止银行通知记账，自动记账失败也不会阻止保存通知历史。

该数据库会保存设备实际投递给本应用的通知内容；使用者应将它视作敏感个人数据。当前版本没有云端副本或账号同步。

## 页面与服务流

- Index.ets 协调首页、统计、手动编辑、OCR 复核、设置和通知历史。
- LedgerStatistics.ets 对已加载的账目按本地日期和所选记账周期做纯计算；统计视图负责图表与排行展示。
- CsvExporter.ets 通过系统文档保存选择器写出 UTF-8 CSV，不自行选择或上传目标路径。
- ShareImportExtension 接收用户从其他应用明确分享过来的图片 URI；图片仍由 OCR 导入流程处理。

## CSV 处理

CSV 每个字段以双引号包裹，字段内部双引号重复转义。可能被表格软件解释为公式的前导字符会额外加单引号。表格软件处理规则各不相同，且重新保存 CSV 可能改变转义行为；导出文件仍应先用文本编辑器或目标表格软件检查。参见 [OWASP CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection)。
