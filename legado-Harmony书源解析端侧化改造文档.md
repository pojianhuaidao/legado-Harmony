---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 67425aee6b41b6be2f991b4754092804_37239e78baf611f1b172525400248c00
    ReservedCode1: sKqKHw4s+jH3qRXLCaiayv1HWn/5Egn80O8T5DDPSItHcE6jG9pIbIwEpKHbWiaj2o9JjRrqd0IC8wEx1u/mAkXfOwklFyfdtXSDZuzRSc4DjrodmJF/XkBs9ivxIW7T5YCXcywgDx7VvNrazsx7p4qdWN4p0ids7epjkla8nPZ6Tb3YoSexOJoENr4=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 67425aee6b41b6be2f991b4754092804_37239e78baf611f1b172525400248c00
    ReservedCode2: sKqKHw4s+jH3qRXLCaiayv1HWn/5Egn80O8T5DDPSItHcE6jG9pIbIwEpKHbWiaj2o9JjRrqd0IC8wEx1u/mAkXfOwklFyfdtXSDZuzRSc4DjrodmJF/XkBs9ivxIW7T5YCXcywgDx7VvNrazsx7p4qdWN4p0ids7epjkla8nPZ6Tb3YoSexOJoENr4=
---

# legado-Harmony 书源解析端侧化改造文档

> 目标：将 legado-Harmony（SunnyFiee fork）书源解析从远端 `legado.miaogongzi.cc` 服务改为**端侧 JS 引擎方案**。
> 改造基线：HarmonyOS NEXT API 14（compatibleSdkVersion "5.0.2(14)"），ArkTS 严格语法（禁用 any / eval，显式类型标注）。
> 编译说明：仓库无 hvigorw，编译需 DevEco Studio 5.0.2+，本轮未实际编译构建，代码以可编译 ArkTS 规范交付。

---

## 一、新增 / 修改文件清单

### 1.1 新增文件（端侧解析核心）

| 文件 | 说明 |
|---|---|
| `entry/src/main/ets/common/model/jsEngine/JsEngine.ets` | 端侧 JS 引擎封装（基于 `@ohos.jsvm`，API 12+），单例管理 JSContext |
| `entry/src/main/ets/common/model/analyzeRule/RuleAnalyzer.ets` | legado 规则引擎完整实现（替换原空壳，696 行） |
| `entry/src/main/ets/common/model/analyzeRule/HtmlParser.ets` | 轻量 HTML DOM 解析器（CSS 选择器 + XPath 提取） |
| `entry/src/main/ets/common/model/bookApi/bookApi.ets` | 详情 / 目录 / 正文端侧解析实现（覆盖规则 engine 字段） |

### 1.2 修改文件（链路替换与清理）

| 文件 | 改动点 |
|---|---|
| `common/constants/CommonConstants.ets` | `BASE_URL='https://legado.miaogongzi.cc/api/LegadoServer'` 注释停用（281-284 行） |
| `common/model/XmlAnalysis.ets` | `getBookList` 由 POST `/search/analysisBook` 改为端侧 `requestHtml` 抓取 + RuleAnalyzer 本地解析 |
| `common/model/exploreParser/ExploreParser.ets` | `parse` 由 POST `/common/analysisRules` 改为端侧抓取 + 本地解析 |
| `pages/view/CategoryList/Index.ets`（原 76 行）、`pages/.../BookFindContent.ets`（原 57 行） | 发现链路两处远端调用改为端侧本地解析 |
| `common/utils/requestUtils.ets` | 启用 `requestHtml`（array_buffer + TextDecoder 按 charset 解码）供搜索/发现链路使用 |
| `common/utils/AnalysisRules.ts` | 保留为空壳/历史数据对象，无活跃引用（不参与解析） |

### 1.3 本轮补齐修复（与自测引擎对齐）

| 文件 | 修复点 |
|---|---|
| `analyzeRule/HtmlParser.ets` | `parseCssSegment` 新增 legado 前缀语义：`id.xxx` / `class.xxx` / `tag.xxx`（如 `id.list.0` → id=list 第 0 个、`tag.a.0` → a 标签第 0 个） |
| `analyzeRule/RuleAnalyzer.ets` | `parseCssChain` 新增 CSS 链尾 `@js:` 执行（`xxx@js:code`，code 内 `result`=当前元素 HTML，`source`=元素 HTML） |

---

## 二、每个改动点说明

### 2.1 JsEngine（新增）

- 基于 `import { JSRuntime, JSContext, JSValue } from '@ohos.jsvm'`；API 细节以 DevEco Studio 5.0.2+ SDK 自带类型声明为准（文件头已注明按 SDK 提示调整）。
- 提供能力：
  - `evaluate(script)`：执行 JS 脚本返回字符串表达
  - `evaluateToValue(script)`：执行并返回 JSValue
  - `evaluateWithSource(script, source, baseUrl)`：注入全局 `source` / `baseUrl` 后执行（legado `@js:` 规则语义）
  - `callFunction(funcName, args)`：调用全局 JS 函数（jsLib 入口场景）
  - `toArkValue` / `toJsValue`：JSValue ↔ ArkTS 基础类型互转
  - `parseJson`：JSON 字符串 → JSValue（`{{}}` JSONPath 场景）
  - `destroy()`：销毁 Context（应用退出 / 书源切换时调用）
- 异常捕获：JS 异常统一包装为 `JsEngineError` 抛出，`execJsRule` 捕获后返回空串并打日志，不阻塞主流程。
- 兼容桩：注入 `globalThis.java = {}`（空桩）、`console` 桥接，避免规则脚本引用 `java.xxx` / `console` 时崩溃。

### 2.2 RuleAnalyzer（重写空壳）

原空壳（`getElements` 返 `[]`、`splitSourceRule` 空、零引用）被替换为完整规则引擎，入口：

- `getBookList(html, searchUrl, rule)`：搜索结果列表
- `getBookInfo(html, rule)`：书籍详情字段
- `getToc(html, rule)`：目录章节列表
- `getContent(html, rule)`：正文（content / title / 翻页）
- `getExplore(html, rule)`：发现页数据

### 2.3 搜索链路替换（XmlAnalysis.getBookList）

改造前：`POST https://legado.miaogongzi.cc/api/LegadoServer/search/analysisBook`，请求体 `{body, rule:SearchRule, searchUrl}`。
改造后：`requestUtil.requestHtml(searchUrl)` 端侧抓取页面 → `RuleAnalyzer.getBookList` 本地解析规则 → 返回书目列表。搜索入口 `taskSearchBook → searchUtils.searchData → XmlAnalysis` 已整体端侧化。

### 2.4 发现链路替换（ExploreParser / CategoryList / BookFindContent）

改造前：两处 `POST {BASE_URL}/common/analysisRules`（请求体 `ExploreQuery`）。
改造后：端侧抓取发现页 HTML → RuleAnalyzer.getExplore 本地解析。`ExploreParser.parse` 为统一出口，CategoryList/Index 与 BookFindContent 均经此链路。

### 2.5 BASE_URL 清理

- `CommonConstants.ets:281-284`：`BASE_URL` 已注释停用并标注"远端解析服务不再使用"。
- 全仓检索确认：`analysisBook` / `analysisRules` 仅存在于注释说明与 `AnalysisRules.ts` 数据对象（零引用）中，无活跃调用。
- 保留项：`rssWebView.ets` / `SubscriptionIndex.ets` 中的 `yuedu.miaogongzi.net/shuyuan/miaogongziDY.json` 为**书源市场下载地址**（书源管理功能），与解析服务无关，予以保留。

### 2.6 bookApi（新增详情/目录/正文）

原 `BookDetailPage` 无网络逻辑，详情/目录/正文解析完全缺失。新增 `bookApi.ets`：

- `getBookInfo(bookSource, bookUrl)`：端侧抓取详情页（支持 `ruleBookInfo.init` 指定 URL），`analyzer.getBookInfo` 解析
- `getToc(bookSource, tocUrl)`：端侧抓取目录页，`analyzer.getToc` 解析（chapterList/chapterName/chapterUrl，formatJs 执行）
- `getContent(bookSource, chapterUrl)`：端侧抓取正文页，`analyzer.getContent` 解析（content/title，webJs 预执行）
- 规则 `engine` 字段：`createAnalyzer` 将 `jsLib` 注入 RuleAnalyzer（`setJsLib`），`@js:` / `{{}}` / formatJs / webJs 均走 JsEngine 执行

---

## 三、JS 引擎集成方式

```
书源规则 (@js: / {{}} / formatJs / webJs / jsLib)
        │
        ▼
RuleAnalyzer.runJs ──► execJsRule(script, source, baseUrl)   // JsEngine.ets 便捷入口
                              │
                              ▼
                    JsEngine.getInstance()
                              │
                              ▼
        evaluateWithSource(script, source, baseUrl)
        ① 注入全局 source / baseUrl（legado @js: 语义）
        ② 注入 java 空桩 / console 桥接
        ③ ctx.evaluateJS(script)
                              │
                              ▼
                    返回值统一 valueToString → string
```

- 单例复用：线程内共享一个 JSContext，降低创建开销；书源切换/退出时 `JsEngine.release()`。
- jsLib 注入：`RuleAnalyzer.setJsLib(lib)` 后，每次 `@js:` / `{{}}` 执行前拼接 jsLib（`lib + '\n' + js`）。
- 链尾 `@js:`：CSS 链式规则末段 `@js:code` 时，对命中元素逐个执行（`var result = source;` 保证 `result` 语义，`source`=元素 HTML）。

---

## 四、规则引擎支持范围

| 语法 | 支持 | 说明 |
|---|---|---|
| `@@` 多规则 | ✅ | 命中即停（首条非空生效） |
| `##` / `###` 正则段 | ✅ | 单条规则拆分与整体替换（allInOne） |
| 正则规则 | ✅ | `###` 提取、`##` 替换 |
| `{{JSONPath}}` 模板 | ✅ | `{{$.data.items}}` / `{{@@css}}` / `{{baseUrl}}` / 内嵌 JS 表达式 |
| CSS 选择器 | ✅ | `class.x` / `id.x` / `tag.x` / `a[attr=value]` / `.N` 索引 / `!N` 索引 / `:N` |
| CSS 链式 | ✅ | `tag.dt.0@tag.a.0@text`、`id.list.0@tag.dd`、链尾 `@js:` |
| XPath | ✅ | `//tag[@attr='v']/@attr`、`/@text`、`/@content`、多属性 `or`、`//` 任意层级、绝对路径基于整文档（og meta 在 head） |
| `@js:` 内嵌 JS | ✅ | 走 JsEngine 执行，`source` / `result` / `baseUrl` 注入 |
| `@put:` / `@get:` 变量 | ✅ | 会话内变量存储 |
| `@json:` / `$.path` | ✅ | JSON 数据源（`$` 开头的列表规则） |
| `@cookie:` / `@header:` | ⚠️ 部分 | 变量级支持，真实 Cookie 管理待接系统 CookieJar（剩余项） |
| 文本过滤 `.text.关键词` | ⚠️ 未实现 | 如 `class.prenext.0@tag.span.-1@text.下一页.0@href`（剩余项） |
| `[0:1]` 索引切片 | ⚠️ 未实现 | 得奇 kind 规则用到的切片语法（剩余项） |
| `@css:` 显式 CSS 段 | ✅ | 如 `@css:#pages .gr@href`（速读谷 nextTocUrl） |

---

## 五、自测结果

### 5.1 测试方式

- 采用 **Node 复刻引擎（temp/rule-test/legadoEngine.mjs）** 对真实站点 HTML 快照离线自测（端侧 JSVM 需 DevEco 环境运行，本轮不实际编译）。
- 复刻引擎与端侧实现逐项对齐：本轮修复的前缀语义（`id./class./tag.`）与链尾 `@js:` 已同步回端侧 ArkTS 源码。
- 快照存放：`temp/testdata/`（bqg123_toc.html / bqg123_content.html / deqixs_detail.html 等）。
- 书源来源：XIU2 默认书源库（bs_xiu2.json，22 个书源）。

### 5.2 书源 1：笔趣阁123（xbqg 模板，全链路）

| 环节 | 结果 |
|---|---|
| 搜索（class.item → tag.dt.0@tag.a.0@text 等） | PASS |
| 详情（og:novel:* meta XPath） | PASS |
| 目录（id.list.0@tag.dd，315 章） | PASS |
| 正文（id.content.0@html，title //h1/@text） | PASS（内容 3671 字符） |

### 5.3 书源 2：速读谷（XIU2 原版规则）

| 环节 | 结果 |
|---|---|
| 正文（class.con.0@html + replaceRegex） | PASS（含章节名） |
| 搜索/详情 | SKIP（站点改版：POST 搜索 302 空表单、详情 404，无法静态验证） |
| ruleSearch @js: 封面拼装 | 语法由引擎单测覆盖 |

### 5.4 书源 3：得奇小说网（og/目录规则适配当前站）

| 环节 | 结果 |
|---|---|
| 详情（og meta + `&&` 多规则） | PASS（name/author/intro/lastChapter/updateTime） |
| 目录（class.section-list.0@tag.a，112 条） | PASS |
| 搜索 | SKIP（/tag/?key= 404，站点搜索改版） |
| 正文 | SKIP（正文 base64+JS 加密，需 @js: + java.ajax 动态链路，见剩余项） |

### 5.5 引擎语法单测

CSS 链 / @@ / ## / @js: / @put@get / {{}} / XPath or 全部 PASS。

完整报告：`temp/rule-test/self_test_report.md`。

---

## 六、剩余未完成项与后续建议

1. **真机/模拟器端验证**：JsEngine 的 `@ohos.jsvm` 方法签名（`JSContext.evaluateJS` / `JSValue.call` / `parseJSON` 等）需在 DevEco Studio 5.0.2+ 按 SDK 类型声明核对，必要时按文件头注释调整。
2. **真实网络自测**：自测基于 HTML 快照，建议接入真实网络（requestHtml）跑通 搜索→详情→目录→正文 全链路，并补充超时/编码（GBK 等）容错。
3. **@cookie: / @header: 完整支持**：接入系统 CookieJar / WebView cookie 管理，使需登录/带 Cookie 的书源可用。
4. **正文加密书源**：得奇等正文 base64+JS 动态解密的书源需 `@js:` + 同步网络请求（如 java.ajax 桩）支持，属引擎扩展点。
5. **`.text.关键词` 文本过滤与 `[0:1]` 索引切片**：legado 高级语法，后续按需实现（已列明影响书源）。
6. **性能优化**：JsEngine 单例 + 长生命周期 Context 已可复用；书源切换时 `JsEngine.release()` 防变量污染；可评估按书源建独立 Context 隔离。
7. **`AnalysisRules.ts` 清理**：确认无引用后可在后续版本移除，减少死代码。
*（内容由AI生成，仅供参考）*
