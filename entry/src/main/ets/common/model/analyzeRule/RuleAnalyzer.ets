/**
 * RuleAnalyzer —— 端侧书源规则引擎（legado 规则语法子集）
 *
 * 替代远端 legado.miaogongzi.cc 解析服务的空壳实现，支持：
 *  - 规则字符串拆分：@@ 多规则（命中即停）、###/## 正则段、&& 拼接
 *  - CSS 选择器：tag / #id / .class / [attr=value] / 空格后代 / > 直接子 /
 *    tag.N 与 :N 索引 / !N 起始索引 / @ 链式选择 / 属性提取后缀
 *  - XPath 子集：//tag / /tag / [@attr='v'] / [N] / @attr
 *  - {{JSONPath}}：$.a.b[0]、$..key
 *  - @js: 内嵌 JS（走 JsEngine 执行）、{{JS 表达式}}、{{@@CSS}}、{{baseUrl}}
 *  - @put/@get 变量、@cookie/@header/@baseUrl/@default/@source/@regex/@json 等前缀
 *
 * 设计约束（ArkTS 严格语法）：禁止 any / eval，显式类型标注，正则使用字面量。
 */
import { HtmlParser, SelectorEngine, HtmlNode, JsonPathUtils } from './HtmlParser';
import { execJsRule } from '../jsEngine/JsEngine';

/**
 * 单条拆分后的规则
 */
export class SplitRule {
  ruleContent: string = '';
  regex: string = '';
  replacement: string = '';
  hasRegex: boolean = false;
}

/**
 * 规则解析结果上下文（供 getBookList 等入口内部使用）
 */
export interface RuleContext {
  baseUrl: string;
  sourceUrl: string;
}

/**
 * 规则引擎
 */
export class RuleAnalyzer {
  private baseUrl: string = '';
  // @put/@get 变量存储
  private variableMap: Record<string, string> = {};
  // 书源 jsLib（JS 库，规则 @js: 与 {{}} 表达式执行前注入）
  private jsLib: string = '';

  constructor() {
    // 无参构造，调用前先 setBaseUrl
  }

  setBaseUrl(url: string): void {
    this.baseUrl = url;
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }

  /**
   * 设置书源 jsLib，供规则内 @js: / {{}} 表达式使用
   */
  setJsLib(lib: string): void {
    this.jsLib = lib;
  }

  /**
   * 执行 JS 规则（自动注入 jsLib）
   */
  private runJs(js: string, source: string): string {
    if (this.jsLib.length > 0) {
      return execJsRule(this.jsLib + '\n' + js, source, this.baseUrl);
    }
    return execJsRule(js, source, this.baseUrl);
  }

  /**
   * 拆分规则字符串：@@ 多规则；单条规则拆出 ### / ## 正则段
   * @param allInOne 是否合并为单条（取第一个正则段应用到全部）
   */
  splitSourceRule(ruleStr: string, allInOne: boolean): SplitRule[] {
    const out: SplitRule[] = [];
    if (ruleStr.length === 0) {
      return out;
    }
    const subRules = ruleStr.split('@@');
    let mergedRegex = '';
    let mergedReplacement = '';
    let hasMerged = false;
    for (let i = 0; i < subRules.length; i++) {
      const sub = subRules[i].trim();
      if (sub.length === 0) {
        continue;
      }
      const sp = this.splitSingleRule(sub);
      if (sp.hasRegex && !hasMerged && allInOne) {
        mergedRegex = sp.regex;
        mergedReplacement = sp.replacement;
        hasMerged = true;
      }
      out.push(sp);
    }
    if (allInOne && hasMerged && out.length > 0) {
      // 合并为单条：保留第一条内容 + 整体正则
      const first = out[0];
      first.regex = mergedRegex;
      first.replacement = mergedReplacement;
      first.hasRegex = true;
      return [first];
    }
    return out;
  }

  /**
   * 拆分单条规则（不处理 @@）：优先 ### 三段，其次 ## 两段
   */
  private splitSingleRule(rule: string): SplitRule {
    const sp = new SplitRule();
    // 前缀 @ 规则（@js: @put: 等）不拆分
    if (rule.startsWith('@js:') || rule.startsWith('@put:') || rule.startsWith('@get:')
      || rule.startsWith('@cookie:') || rule.startsWith('@header:') || rule.startsWith('@baseUrl:')
      || rule.startsWith('@default:') || rule.startsWith('@source:')) {
      sp.ruleContent = rule;
      return sp;
    }
    const idx3 = rule.indexOf('###');
    if (idx3 > -1) {
      sp.ruleContent = rule.substring(0, idx3);
      sp.regex = rule.substring(idx3 + 3);
      // 替换段：### 后可能还有 ## 分隔的替换
      const idx2 = sp.regex.indexOf('##');
      if (idx2 > -1) {
        sp.replacement = sp.regex.substring(idx2 + 2);
        sp.regex = sp.regex.substring(0, idx2);
      }
      sp.hasRegex = true;
      return sp;
    }
    const idx2 = rule.indexOf('##');
    if (idx2 > -1) {
      sp.ruleContent = rule.substring(0, idx2);
      sp.regex = rule.substring(idx2 + 2);
      // 双段替换：##regex##replacement（replacement 可空，空则等价删除）
      const idx4 = sp.regex.indexOf('##');
      if (idx4 > -1) {
        sp.replacement = sp.regex.substring(idx4 + 2);
        sp.regex = sp.regex.substring(0, idx4);
      }
      sp.hasRegex = true;
      return sp;
    }
    sp.ruleContent = rule;
    return sp;
  }

  /**
   * 核心入口：对 source 执行规则，返回匹配结果列表（命中即停）
   *  - CSS/XPath 无属性后缀时返回元素 HTML（供下级相对规则使用）
   *  - 有属性后缀时返回属性/文本
   *  - JSON 规则返回 JSON 片段
   */
  getElements(rule: string, source: string): string[] {
    if (rule.length === 0) {
      return [];
    }
    const rules = this.splitSourceRule(rule, false);
    for (let i = 0; i < rules.length; i++) {
      const result = this.parseRuleBody(rules[i], source);
      if (result.length > 0) {
        return result;
      }
    }
    return [];
  }

  /**
   * 取第一个结果；无结果返回空串
   */
  getString(rule: string, source: string): string {
    const list = this.getElements(rule, source);
    if (list.length > 0) {
      return list[0];
    }
    return '';
  }

  /**
   * 解析单条规则体
   */
  private parseRuleBody(rule: SplitRule, source: string): string[] {
    const content = rule.ruleContent.trim();
    if (content.length === 0) {
      return [];
    }
    // 前缀规则
    if (content.startsWith('@js:')) {
      const js = content.substring(4).trim();
      // 与链尾 @js: 一致：先注入 result=source 变量，legado 规则常用 result = ... 赋值
      const result = this.runJs('var result = source;\n' + js, source);
      return this.applyRegexToResult([result], rule);
    }
    if (content.startsWith('<js>') && content.endsWith('</js>')) {
      const js = content.substring(4, content.length - 5).trim();
      const result = this.runJs('var result = source;\n' + js, source);
      return this.applyRegexToResult([result], rule);
    }
    if (content.startsWith('@put:')) {
      const expr = content.substring(5).trim();
      const eq = expr.indexOf('=');
      if (eq > 0) {
        const key = expr.substring(0, eq).trim();
        let value = expr.substring(eq + 1).trim();
        // 值可能引用 source / 变量
        value = this.resolveVariable(value, source);
        this.variableMap[key] = value;
      }
      return [];
    }
    if (content.startsWith('@get:')) {
      const key = content.substring(5).trim();
      const v = this.variableMap[key];
      if (v !== undefined) {
        return [v];
      }
      return [];
    }
    if (content.startsWith('@cookie:')) {
      // 端侧 cookie 管理：当前返回空，待接入网络层 cookie jar
      return [];
    }
    if (content.startsWith('@header:')) {
      return [];
    }
    if (content.startsWith('@baseUrl:')) {
      return [this.baseUrl];
    }
    if (content.startsWith('@default:')) {
      return [content.substring(9).trim()];
    }
    if (content.startsWith('@source:')) {
      return [source];
    }
    if (content.startsWith('@json:')) {
      const path = content.substring(6).trim();
      const v = JsonPathUtils.query(source, path);
      if (v.length > 0) {
        return [v];
      }
      return [];
    }
    if (content.startsWith('@regex:')) {
      const re = content.substring(7).trim();
      const v = this.regexFirst(source, re);
      if (v.length > 0) {
        return [v];
      }
      return [];
    }
    // && 拼接
    if (content.indexOf('&&') > -1) {
      const parts = content.split('&&');
      let joined = '';
      for (let i = 0; i < parts.length; i++) {
        const sp = this.splitSingleRule(parts[i].trim());
        const res = this.parseRuleBody(sp, source);
        if (res.length > 0) {
          joined += res[0];
        }
      }
      return this.applyRegexToResult([joined], rule);
    }
    // {{}} 模板
    if (content.indexOf('{{') > -1) {
      const templated = this.parseTemplate(content, source);
      return this.applyRegexToResult([templated], rule);
    }
    // CSS / XPath / 选择器
    return this.applyRegexToResult(this.parseSelectorBody(content, source), rule);
  }

  /**
   * 对结果列表应用正则删除/替换
   */
  private applyRegexToResult(results: string[], rule: SplitRule): string[] {
    if (!rule.hasRegex || rule.regex.length === 0) {
      return results;
    }
    const out: string[] = [];
    for (let i = 0; i < results.length; i++) {
      out.push(this.applyRegex(results[i], rule.regex, rule.replacement));
    }
    return out;
  }

  /**
   * 正则应用：有替换则替换，否则删除匹配
   */
  private applyRegex(input: string, regex: string, replacement: string): string {
    try {
      const re = new RegExp(regex, 'g');
      if (replacement.length > 0) {
        return input.replace(re, replacement);
      }
      return input.replace(re, '');
    } catch (e) {
      return input;
    }
  }

  /**
   * 正则取首个匹配组或首个匹配
   */
  private regexFirst(input: string, regex: string): string {
    try {
      const re = new RegExp(regex);
      const m = input.match(re);
      if (m !== null && m.length > 0) {
        if (m.length > 1) {
          return m[1];
        }
        return m[0];
      }
    } catch (e) {
      return '';
    }
    return '';
  }

  /**
   * 变量值解析：支持 @get:key 引用与 source 关键字
   */
  private resolveVariable(value: string, source: string): string {
    let out = value;
    const getMatch = out.match(/@get:(\w+)/);
    if (getMatch !== null) {
      const key = getMatch[1];
      const v = this.variableMap[key];
      if (v !== undefined) {
        out = out.replace(getMatch[0], v);
      }
    }
    if (out === 'source') {
      return source;
    }
    return out;
  }

  /**
   * {{}} 模板解析：{{@@CSS}} / {{JSONPath}} / {{baseUrl}} / {{JS 表达式}}
   * 逐段替换后拼接；未匹配的普通文本原样保留。
   */
  private parseTemplate(content: string, source: string): string {
    const re = /\{\{(.*?)\}\}/g;
    let result = '';
    let lastIndex = 0;
    let m: RegExpExecArray | null = null;
    let iter: RegExpExecArray | null = re.exec(content);
    while (iter !== null) {
      const start = iter.index;
      result += content.substring(lastIndex, start);
      const inner = iter[1].trim();
      result += this.evalTemplateExpr(inner, source);
      lastIndex = start + iter[0].length;
      iter = re.exec(content);
    }
    result += content.substring(lastIndex);
    return result;
  }

  /**
   * 求值单个 {{}} 表达式
   */
  private evalTemplateExpr(expr: string, source: string): string {
    if (expr.length === 0) {
      return '';
    }
    // {{@@CSS}}
    if (expr.startsWith('@@')) {
      const css = expr.substring(2).trim();
      return this.getFirstTextByCss(css, source);
    }
    // {{baseUrl}}
    if (expr === 'baseUrl' || expr === 'bookSourceUrl') {
      return this.baseUrl;
    }
    if (expr === 'source') {
      return source;
    }
    // {{java.xxx}} 或含函数调用的 JS 表达式
    if (expr.indexOf('java.') > -1 || expr.indexOf('(') > -1 || expr.indexOf('.replace') > -1
      || expr.indexOf('.substring') > -1 || expr.indexOf('.split') > -1) {
      const jsResult = this.runJs('(function(){ return (' + expr + '); })();', source);
      if (jsResult.length > 0) {
        return jsResult;
      }
    }
    // JSONPath
    const jsonResult = JsonPathUtils.query(source, expr);
    if (jsonResult.length > 0) {
      return jsonResult;
    }
    // 兜底：JS 表达式
    return this.runJs('(function(){ return (' + expr + '); })();', source);
  }

  /**
   * CSS 取首个元素的文本
   */
  private getFirstTextByCss(css: string, source: string): string {
    const parser = new HtmlParser();
    const root = parser.parse(source);
    const engine = new SelectorEngine(root);
    const nodes = engine.queryByCss(css);
    if (nodes.length > 0) {
      return engine.extractAttr(nodes[0], 'text');
    }
    return '';
  }

  /**
   * 选择器主体解析：CSS @ 链式 / XPath / 索引 / 属性提取
   */
  parseSelectorBody(body: string, source: string): string[] {
    const trimmed = body.trim();
    if (trimmed.length === 0) {
      return [];
    }
    const parser = new HtmlParser();
    const root = parser.parse(source);
    const engine = new SelectorEngine(root);
    if (trimmed.startsWith('//')) {
      return this.parseXpathChain(engine, root, trimmed);
    }
    return this.parseCssChain(engine, root, trimmed);
  }

  /**
   * CSS @ 链式解析
   */
  private parseCssChain(engine: SelectorEngine, root: HtmlNode, body: string): string[] {
    // 按 @ 拆分链式段（避开 []）
    const segments = this.splitAt(body);
    if (segments.length === 0) {
      return [];
    }
    let nodes: HtmlNode[] = [root];
    // 最近出现的属性提取段（供链尾 @js: 作 base；非链尾属性段不再当选择器查询）
    let pendingAttr: string = '';
    for (let i = 0; i < segments.length; i++) {
      const seg = segments[i].trim();
      if (seg.length === 0) {
        continue;
      }
      const isLast = (i === segments.length - 1);
      // 链尾 @js: 执行（legado 语法 "xxx@text@js:code"，code 内 result=最近属性值或元素 HTML）
      if (isLast && seg.startsWith('js:')) {
        const jsCode = seg.substring(3).trim();
        const out: string[] = [];
        for (let j = 0; j < nodes.length; j++) {
          let base: string = '';
          if (pendingAttr.length > 0) {
            base = engine.extractAttr(nodes[j], pendingAttr);
          } else {
            base = nodes[j].outerHtml();
          }
          let jsResult = this.runJs('var result = source;\n' + jsCode, base);
          // JS 执行失败/返回空（如 CI jsvmStub 无法执行 @js:）时回退原始值，避免字段整体丢失
          if (jsResult.length === 0 && base.length > 0) {
            jsResult = base;
          }
          out.push(jsResult);
        }
        return out;
      }
      if (this.isAttrToken(seg)) {
        if (isLast) {
          // 属性提取
          const out: string[] = [];
          for (let j = 0; j < nodes.length; j++) {
            out.push(engine.extractAttr(nodes[j], seg));
          }
          return out;
        }
        // 非链尾属性段：仅记录，继续后续选择器/JS 段
        pendingAttr = seg;
        continue;
      }
      // 选择器段（可能含 !N 索引后缀）
      const idxInfo = this.parseIndexSuffix(seg);
      const sel = idxInfo.selector;
      let matched: HtmlNode[] = [];
      for (let j = 0; j < nodes.length; j++) {
        const part = engine.queryByCssFrom(nodes[j], sel);
        for (let k = 0; k < part.length; k++) {
          matched.push(part[k]);
        }
      }
      matched = this.applyIndexList(matched, idxInfo.indexList);
      nodes = matched;
      if (nodes.length === 0) {
        return [];
      }
    }
    // 无属性后缀：返回元素 HTML（供下级规则使用）
    const out: string[] = [];
    for (let i = 0; i < nodes.length; i++) {
      out.push(nodes[i].outerHtml());
    }
    return out;
  }

  /**
   * XPath 解析：末尾 @attr 提取属性；否则返回元素 HTML
   */
  private parseXpathChain(engine: SelectorEngine, root: HtmlNode, body: string): string[] {
    let xpath = body;
    let attrName = '';
    // 末尾 @attr（如 //a/@href、//div/@class）
    const atIdx = xpath.lastIndexOf('/@');
    if (atIdx > -1) {
      attrName = xpath.substring(atIdx + 2).trim();
      xpath = xpath.substring(0, atIdx);
    }
    const nodes = engine.queryByXpathFrom(root, xpath);
    if (nodes.length === 0) {
      return [];
    }
    const out: string[] = [];
    if (attrName.length > 0) {
      for (let i = 0; i < nodes.length; i++) {
        out.push(engine.extractAttr(nodes[i], attrName));
      }
    } else {
      for (let i = 0; i < nodes.length; i++) {
        out.push(nodes[i].outerHtml());
      }
    }
    return out;
  }

  /**
   * 按 @ 拆分（避开 [ ] 内的 @）
   */
  private splitAt(input: string): string[] {
    const out: string[] = [];
    let depth = 0;
    let cur = '';
    for (let i = 0; i < input.length; i++) {
      const ch = input.charAt(i);
      if (ch === '[') {
        depth++;
      } else if (ch === ']') {
        depth--;
      }
      if (ch === '@' && depth === 0) {
        out.push(cur);
        cur = '';
      } else {
        cur += ch;
      }
    }
    if (cur.length > 0 || out.length === 0) {
      out.push(cur);
    }
    return out;
  }

  /**
   * 判断是否为属性提取 token（text/textNodes/html/all/self 或已知 HTML 属性名）
   */
  private isAttrToken(token: string): boolean {
    const t = token.toLowerCase();
    if (t === 'text' || t === 'textnodes' || t === 'html' || t === 'all' || t === 'self') {
      return true;
    }
    const knownAttrs = ['href', 'src', 'src2', 'alt', 'title', 'value', 'data-src', 'data-original',
      'data-srcset', 'data-url', 'data-id', 'data-bookid', 'data-chapterid', 'name', 'class',
      'id', 'style', 'width', 'height', 'content', 'rel', 'target', 'type', 'placeholder'];
    if (knownAttrs.indexOf(t) > -1) {
      return true;
    }
    // 含连字符/下划线的属性名（data-xxx、xxx_xxx）
    if (/^[a-zA-Z][\w-]*$/.test(t) && (t.indexOf('-') > -1 || t.indexOf('_') > -1)) {
      return true;
    }
    return false;
  }

  /**
   * 解析选择器段尾 !N 索引后缀：!0 / !0:-1:-2
   */
  private parseIndexSuffix(seg: string): IndexInfo {
    const info: IndexInfo = {
      selector: seg,
      indexList: []
    };
    const bangIdx = seg.indexOf('!');
    if (bangIdx > -1) {
      const after = seg.substring(bangIdx + 1);
      if (/^-?\d+(:-?\d+)*$/.test(after)) {
        info.selector = seg.substring(0, bangIdx).trim();
        const parts = after.split(':');
        for (let i = 0; i < parts.length; i++) {
          info.indexList.push(parseInt(parts[i], 10));
        }
      }
    }
    return info;
  }

  /**
   * 应用索引列表：单元素=起始索引（slice）；多元素=按索引取
   */
  private applyIndexList(nodes: HtmlNode[], indexList: number[]): HtmlNode[] {
    if (indexList.length === 0) {
      return nodes;
    }
    const out: HtmlNode[] = [];
    if (indexList.length === 1) {
      const start = indexList[0] < 0 ? Math.max(0, nodes.length + indexList[0]) : indexList[0];
      for (let i = start; i < nodes.length; i++) {
        out.push(nodes[i]);
      }
      return out;
    }
    for (let i = 0; i < indexList.length; i++) {
      const idx = indexList[i];
      if (idx >= 0 && idx < nodes.length) {
        out.push(nodes[idx]);
      } else if (idx < 0) {
        const realIdx = nodes.length + idx;
        if (realIdx >= 0 && realIdx < nodes.length) {
          out.push(nodes[realIdx]);
        }
      }
    }
    return out;
  }

  // ==================== 高级入口 ====================

  /**
   * 搜索解析：对搜索结果页执行 ruleSearch，返回字段 map 列表
   * 字段：name/author/intro/kind/lastChapter/updateTime/bookUrl/coverUrl/wordCount
   */
  getBookList(source: string, searchRule: Record<string, string>): Record<string, string>[] {
    const bookListRule = searchRule['bookList'] || '';
    const items = this.getElements(bookListRule, source);
    const out: Record<string, string>[] = [];
    const fields = ['name', 'author', 'intro', 'kind', 'lastChapter', 'updateTime', 'bookUrl', 'coverUrl', 'wordCount'];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const row: Record<string, string> = {};
      for (let f = 0; f < fields.length; f++) {
        const rule = searchRule[fields[f]] || '';
        if (rule.length === 0) {
          continue;
        }
        row[fields[f]] = this.getString(rule, item);
      }
      out.push(row);
    }
    return out;
  }

  /**
   * 详情解析
   */
  getBookInfo(source: string, infoRule: Record<string, string>): Record<string, string> {
    const fields = ['name', 'author', 'intro', 'kind', 'lastChapter', 'updateTime', 'coverUrl', 'wordCount', 'tocUrl'];
    const row: Record<string, string> = {};
    for (let f = 0; f < fields.length; f++) {
      const rule = infoRule[fields[f]] || '';
      if (rule.length === 0) {
        continue;
      }
      row[fields[f]] = this.getString(rule, source);
    }
    return row;
  }

  /**
   * 目录解析：chapterList 规则返回元素列表，每项再取 chapterName/chapterUrl/updateTime
   */
  getToc(source: string, tocRule: Record<string, string>): Record<string, string>[] {
    const listRule = tocRule['chapterList'] || '';
    const items = this.getElements(listRule, source);
    const out: Record<string, string>[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const row: Record<string, string> = {};
      const name = tocRule['chapterName'] || '';
      const url = tocRule['chapterUrl'] || '';
      const update = tocRule['updateTime'] || '';
      if (name.length > 0) {
        row['chapterName'] = this.getString(name, item);
      }
      if (url.length > 0) {
        row['chapterUrl'] = this.getString(url, item);
      }
      if (update.length > 0) {
        row['updateTime'] = this.getString(update, item);
      }
      out.push(row);
    }
    return out;
  }

  /**
   * 正文解析
   */
  getContent(source: string, contentRule: Record<string, string>): Record<string, string> {
    const row: Record<string, string> = {};
    const content = contentRule['content'] || '';
    const title = contentRule['title'] || '';
    if (content.length > 0) {
      row['content'] = this.getString(content, source);
    }
    if (title.length > 0) {
      row['title'] = this.getString(title, source);
    }
    return row;
  }

  /**
   * 发现/探索解析：同搜索
   */
  getExplore(source: string, exploreRule: Record<string, string>): Record<string, string>[] {
    return this.getBookList(source, exploreRule);
  }
}

interface IndexInfo {
  selector: string;
  indexList: number[];
}
