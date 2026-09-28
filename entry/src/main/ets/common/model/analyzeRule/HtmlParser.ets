/**
 * HtmlParser —— 轻量 HTML 解析与选择器引擎
 *
 * 纯 ArkTS 实现，无第三方依赖。提供：
 *  - HTML 字符串 -> 节点树（标签/属性/文本/注释/自闭合）
 *  - CSS 选择器子集：tag / #id / .class / [attr=value] / 后代空格 / 直接子 > / :N 索引
 *  - 属性提取后缀：@a @href @text @textNodes @html @all @self（由调用方解析）
 *  - XPath 子集：//tag / /tag / [@attr='v'] / [N] / 末尾 @attr
 *  - JSONPath 子集：$.a.b[0] / $['a'] / $..key（递归）
 *
 * 设计约束：ArkTS 严格语法，禁止 any/eval，显式类型标注。
 */

/**
 * HTML 节点
 */
export class HtmlNode {
  // 标签名；文本节点为 '#text'；根节点为 '#root'
  tagName: string = '';
  // 元素属性
  attributes: Record<string, string> = {};
  // 子节点
  children: HtmlNode[] = [];
  // 父节点（根为 null）
  parent: HtmlNode | null = null;
  // 文本节点内容
  textContent: string = '';
  // 是否为自闭合（无内容）
  selfClosed: boolean = false;

  constructor(tagName: string) {
    this.tagName = tagName;
  }

  /**
   * 返回元素节点自身文本（不含后代）
   */
  ownText(): string {
    if (this.tagName === '#text') {
      return this.textContent;
    }
    let sb: string = '';
    for (let i = 0; i < this.children.length; i++) {
      const c = this.children[i];
      if (c.tagName === '#text') {
        sb += c.textContent;
      }
    }
    return sb;
  }

  /**
   * 返回元素全部文本（含所有后代文本节点）
   */
  wholeText(): string {
    if (this.tagName === '#text') {
      return this.textContent;
    }
    let sb: string = '';
    for (let i = 0; i < this.children.length; i++) {
      sb += this.children[i].wholeText();
    }
    return sb;
  }

  /**
   * 返回 HTML 源码（含本节点开闭标签）
   */
  outerHtml(): string {
    if (this.tagName === '#text') {
      return this.textContent;
    }
    let sb: string = '<' + this.tagName;
    const keys = Object.keys(this.attributes);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      sb += ' ' + k + '="' + this.attributes[k] + '"';
    }
    sb += '>';
    for (let i = 0; i < this.children.length; i++) {
      sb += this.children[i].outerHtml();
    }
    sb += '</' + this.tagName + '>';
    return sb;
  }
}

/**
 * CSS 选择器单段（如 ul.list、li.item）
 */
export interface CssSegment {
  tagName: string;
  id: string;
  classes: string[];
  attrs: Record<string, string>;
  index: number; // -1 表示不限制
  directChild: boolean; // 是否要求直接子节点（>）
}

/**
 * HTML 解析器
 */
export class HtmlParser {
  private pos: number = 0;
  private html: string = '';
  private root: HtmlNode = new HtmlNode('#root');

  /**
   * 解析 HTML 字符串，返回根节点
   */
  parse(html: string): HtmlNode {
    this.html = html;
    this.pos = 0;
    this.root = new HtmlNode('#root');
    this.parseNodes(this.root, false);
    return this.root;
  }

  private parseNodes(parent: HtmlNode, stopOnClose: boolean): void {
    const len = this.html.length;
    while (this.pos < len) {
      const ch = this.html.charAt(this.pos);
      if (ch === '<') {
        // 注释 / 结束标签 / 开始标签
        if (this.html.startsWith('<!--', this.pos)) {
          const end = this.html.indexOf('-->', this.pos + 4);
          this.pos = end === -1 ? len : end + 3;
          continue;
        }
        if (this.html.startsWith('</', this.pos)) {
          if (stopOnClose) {
            return;
          }
          const end = this.html.indexOf('>', this.pos + 2);
          this.pos = end === -1 ? len : end + 1;
          continue;
        }
        // 开始标签
        const tagInfo = this.parseTag();
        if (tagInfo === null) {
          this.pos++;
          continue;
        }
        const node = new HtmlNode(tagInfo.tagName);
        node.attributes = tagInfo.attrs;
        node.selfClosed = tagInfo.selfClosed;
        node.parent = parent;
        parent.children.push(node);
        if (!tagInfo.selfClosed && !this.isVoidTag(tagInfo.tagName)) {
          this.parseNodes(node, true);
        }
      } else {
        // 文本
        const start = this.pos;
        while (this.pos < len && this.html.charAt(this.pos) !== '<') {
          this.pos++;
        }
        const text = this.html.substring(start, this.pos);
        const textNode = new HtmlNode('#text');
        textNode.textContent = text;
        textNode.parent = parent;
        parent.children.push(textNode);
      }
    }
  }

  private parseTag(): TagInfo | null {
    const len = this.html.length;
    // this.pos 位于 '<'
    const start = this.pos + 1;
    let i = start;
    while (i < len && !this.isSpace(this.html.charAt(i)) && this.html.charAt(i) !== '>' && this.html.charAt(i) !== '/') {
      i++;
    }
    const tagName = this.html.substring(start, i).toLowerCase();
    if (tagName.length === 0) {
      return null;
    }
    const attrs: Record<string, string> = {};
    let selfClosed = false;
    // 解析属性
    while (i < len) {
      while (i < len && this.isSpace(this.html.charAt(i))) {
        i++;
      }
      if (i >= len) {
        break;
      }
      const c = this.html.charAt(i);
      if (c === '>') {
        i++;
        break;
      }
      if (c === '/' && i + 1 < len && this.html.charAt(i + 1) === '>') {
        selfClosed = true;
        i += 2;
        break;
      }
      // 属性名
      const attrStart = i;
      while (i < len && !this.isSpace(this.html.charAt(i)) && this.html.charAt(i) !== '=' && this.html.charAt(i) !== '>') {
        i++;
      }
      const attrName = this.html.substring(attrStart, i).toLowerCase();
      // 跳过空白
      while (i < len && this.isSpace(this.html.charAt(i))) {
        i++;
      }
      if (i < len && this.html.charAt(i) === '=') {
        i++;
        while (i < len && this.isSpace(this.html.charAt(i))) {
          i++;
        }
        // 属性值（引号或裸值）
        let attrValue = '';
        if (i < len && (this.html.charAt(i) === '"' || this.html.charAt(i) === '\'')) {
          const quote = this.html.charAt(i);
          i++;
          const vStart = i;
          while (i < len && this.html.charAt(i) !== quote) {
            i++;
          }
          attrValue = this.html.substring(vStart, i);
          if (i < len) {
            i++;
          }
        } else {
          const vStart = i;
          while (i < len && !this.isSpace(this.html.charAt(i)) && this.html.charAt(i) !== '>') {
            i++;
          }
          attrValue = this.html.substring(vStart, i);
        }
        attrs[attrName] = this.decodeEntities(attrValue);
      } else {
        attrs[attrName] = '';
      }
    }
    this.pos = i;
    const info: TagInfo = {
      tagName: tagName,
      attrs: attrs,
      selfClosed: selfClosed
    };
    return info;
  }

  private isSpace(ch: string): boolean {
    return ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r' || ch === '\f';
  }

  private isVoidTag(tag: string): boolean {
    return tag === 'br' || tag === 'hr' || tag === 'img' || tag === 'input' || tag === 'meta'
      || tag === 'link' || tag === 'area' || tag === 'base' || tag === 'col' || tag === 'embed'
      || tag === 'source' || tag === 'track' || tag === 'wbr';
  }

  private decodeEntities(input: string): string {
    return input.replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, '\'')
      .replace(/&nbsp;/g, ' ');
  }
}

interface TagInfo {
  tagName: string;
  attrs: Record<string, string>;
  selfClosed: boolean;
}

/**
 * 选择器匹配工具
 */
export class SelectorEngine {
  private root: HtmlNode;

  constructor(root: HtmlNode) {
    this.root = root;
  }

  /**
   * CSS 选择器查询，返回元素节点列表（不含 #text）
   * 支持：tag / #id / .class / [attr=value] / 空格后代 / > 直接子 / :N 与 tag.N 索引
   */
  queryByCss(selector: string): HtmlNode[] {
    return this.queryByCssFrom(this.root, selector);
  }

  /**
   * 从指定节点（相对）开始执行 CSS 选择器查询
   */
  queryByCssFrom(node: HtmlNode, selector: string): HtmlNode[] {
    const segments = this.parseCssSelector(selector);
    if (segments.length === 0) {
      return [];
    }
    let current: HtmlNode[] = [node];
    for (let i = 0; i < segments.length; i++) {
      const seg = segments[i];
      if (seg.directChild) {
        current = this.matchDirectChildren(current, seg);
      } else {
        current = this.matchDescendants(current, seg);
      }
      current = this.applyIndex(current, seg);
      if (current.length === 0) {
        return [];
      }
    }
    return current;
  }

  /**
   * 应用索引过滤：seg.index >= 0 取第 index 个；< 0 取倒数第 |index| 个
   */
  private applyIndex(nodes: HtmlNode[], seg: CssSegment): HtmlNode[] {
    if (seg.index === -1) {
      return nodes;
    }
    const out: HtmlNode[] = [];
    if (seg.index >= 0) {
      if (seg.index < nodes.length) {
        out.push(nodes[seg.index]);
      }
    } else {
      const idx = nodes.length + seg.index;
      if (idx >= 0 && idx < nodes.length) {
        out.push(nodes[idx]);
      }
    }
    return out;
  }

  /**
   * XPath 子集查询：
   * 支持 //tag、/tag、[N] 索引、[@attr='v']、末尾 @attr 提取
   * 返回元素节点列表。
   */
  queryByXpath(xpath: string): HtmlNode[] {
    return this.queryByXpathFrom(this.root, xpath);
  }

  /**
   * 从指定节点（相对）开始执行 XPath 子集查询
   */
  queryByXpathFrom(node: HtmlNode, xpath: string): HtmlNode[] {
    // 提取末尾属性提取符（@attr 或 @text/@html）
    const cleaned = xpath.trim();
    // 拆分路径段
    const segStrs = this.splitXpath(cleaned);
    if (segStrs.length === 0) {
      return [];
    }
    let current: HtmlNode[] = [node];
    for (let i = 0; i < segStrs.length; i++) {
      const segStr = segStrs[i];
      if (segStr.length === 0) {
        continue;
      }
      // 解析段：tagName[@attr='v'][N]
      const seg = this.parseXpathSegment(segStr);
      current = this.matchDescendants(current, seg);
      current = this.applyIndex(current, seg);
      if (current.length === 0) {
        return [];
      }
    }
    return current;
  }

  /**
   * 从元素列表提取属性值（legado 后缀语义）
   *  - @a / @href / @src / @id 等：取指定属性
   *  - @text：取元素自身文本
   *  - @textNodes：取全部后代文本
   *  - @html：取 innerHTML（outerHtml 简化）
   *  - @all：全部属性拼接
   *  - @self：取节点自身（返回 outerHtml）
   */
  extractAttr(node: HtmlNode, attrName: string): string {
    if (attrName === 'text') {
      return this.trimText(node.ownText());
    }
    if (attrName === 'textNodes') {
      return this.trimText(node.wholeText());
    }
    if (attrName === 'html') {
      return node.outerHtml();
    }
    if (attrName === 'self') {
      return node.outerHtml();
    }
    if (attrName === 'all') {
      let sb: string = '';
      const keys = Object.keys(node.attributes);
      for (let i = 0; i < keys.length; i++) {
        sb += keys[i] + '=' + node.attributes[keys[i]] + ' ';
      }
      return sb.trim();
    }
    if (node.attributes[attrName] !== undefined) {
      return node.attributes[attrName];
    }
    return '';
  }

  private trimText(s: string): string {
    return s.replace(/\s+/g, ' ').trim();
  }

  /**
   * 解析 CSS 选择器为段序列
   */
  private parseCssSelector(selector: string): CssSegment[] {
    const rawSegments: string[] = [];
    // 先按 > 拆分，再处理空格后代
    const parts = selector.split('>');
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (i < parts.length - 1) {
        const sub = part.trim();
        if (sub.length > 0) {
          rawSegments.push(sub + '>');
        }
      } else {
        const sub = part.trim();
        if (sub.length > 0) {
          rawSegments.push(sub);
        }
      }
    }
    // 处理空格后代（rawSegments 中可能含 "a b"）
    const finalSegments: CssSegment[] = [];
    for (let i = 0; i < rawSegments.length; i++) {
      const raw = rawSegments[i];
      const direct = raw.endsWith('>');
      const body = direct ? raw.substring(0, raw.length - 1) : raw;
      // 按空白拆分（多个选择器间空格=后代）
      const tokens = body.trim().split(/\s+/);
      for (let j = 0; j < tokens.length; j++) {
        const tok = tokens[j];
        if (tok.length === 0) {
          continue;
        }
        const isLast = (j === tokens.length - 1);
        const seg = this.parseCssSegment(tok);
        seg.directChild = direct && isLast;
        finalSegments.push(seg);
      }
    }
    return finalSegments;
  }

  /**
   * 解析单个 CSS 段：tag#id.class[attr=value]:N
   */
  private parseCssSegment(segStr: string): CssSegment {
    const seg: CssSegment = {
      tagName: '',
      id: '',
      classes: [],
      attrs: {},
      index: -1,
      directChild: false
    };
    let rest = segStr;
    // 索引 :N（数字）
    const idxMatch = rest.match(/:(\d+)$/);
    if (idxMatch !== null) {
      seg.index = parseInt(idxMatch[1], 10);
      rest = rest.substring(0, idxMatch.index);
    }
    // 属性 [attr=value]
    const attrMatches = rest.match(/\[([^\]]+)\]/g);
    if (attrMatches !== null) {
      for (let i = 0; i < attrMatches.length; i++) {
        const inner = attrMatches[i].substring(1, attrMatches[i].length - 1);
        const eq = inner.indexOf('=');
        if (eq > 0) {
          const k = inner.substring(0, eq).trim();
          let v = inner.substring(eq + 1).trim();
          if (v.startsWith('"') && v.endsWith('"')) {
            v = v.substring(1, v.length - 1);
          }
          if (v.startsWith('\'') && v.endsWith('\'')) {
            v = v.substring(1, v.length - 1);
          }
          seg.attrs[k] = v;
        } else {
          seg.attrs[inner.trim()] = '';
        }
      }
      rest = rest.replace(/\[[^\]]+\]/g, '');
    }
    // legado 前缀语义：id.xxx / class.xxx / tag.xxx（须先于类名/数字索引解析，
    // 使 "id.list.0" -> id=list 第 0 个、"tag.a.0" -> a 标签第 0 个、"class.item" -> class=item）
    const idPrefix = rest.match(/^id\.([\w-]+)/);
    if (idPrefix !== null) {
      seg.id = idPrefix[1];
      rest = rest.substring(idPrefix[0].length);
    } else {
      const classPrefix = rest.match(/^class\.([\w-]+)/);
      if (classPrefix !== null) {
        seg.classes.push(classPrefix[1]);
        rest = rest.substring(classPrefix[0].length);
      } else {
        const tagPrefix = rest.match(/^tag\.([\w-]+)/);
        if (tagPrefix !== null) {
          seg.tagName = tagPrefix[1];
          rest = rest.substring(tagPrefix[0].length);
        }
      }
    }
    // 数字索引（legado 语法 tag.N 表示索引，如 a.0、a.-1；负数=倒数）
    // 必须先于类名提取，避免把 a.0 当作类名 "0"
    const numIdxMatch = rest.match(/\.(-?\d+)(?![\w-])/);
    if (numIdxMatch !== null) {
      seg.index = parseInt(numIdxMatch[1], 10);
      rest = rest.substring(0, numIdxMatch.index) + rest.substring(numIdxMatch.index + numIdxMatch[0].length);
    }
    // 类名与 id（纯 .name 形式）
    const clsMatches = rest.match(/\.([\w-]+)/g);
    if (clsMatches !== null) {
      for (let i = 0; i < clsMatches.length; i++) {
        seg.classes.push(clsMatches[i].substring(1));
      }
      rest = rest.replace(/\.[\w-]+/g, '');
    }
    const idMatch = rest.match(/#([\w-]+)/);
    if (idMatch !== null) {
      seg.id = idMatch[1];
      rest = rest.replace(/#[\w-]+/, '');
    }
    // 剩余为标签名
    seg.tagName = rest.trim().toLowerCase();
    return seg;
  }

  private matchDescendants(nodes: HtmlNode[], seg: CssSegment): HtmlNode[] {
    const out: HtmlNode[] = [];
    for (let i = 0; i < nodes.length; i++) {
      this.collectMatch(nodes[i], seg, out);
    }
    return out;
  }

  private collectMatch(node: HtmlNode, seg: CssSegment, out: HtmlNode[]): void {
    for (let i = 0; i < node.children.length; i++) {
      const child = node.children[i];
      if (this.matchSegment(child, seg)) {
        out.push(child);
      }
      this.collectMatch(child, seg, out);
    }
  }

  private matchDirectChildren(nodes: HtmlNode[], seg: CssSegment): HtmlNode[] {
    const out: HtmlNode[] = [];
    for (let i = 0; i < nodes.length; i++) {
      const children = nodes[i].children;
      for (let j = 0; j < children.length; j++) {
        if (this.matchSegment(children[j], seg)) {
          out.push(children[j]);
        }
      }
    }
    return out;
  }

  private matchSegment(node: HtmlNode, seg: CssSegment): boolean {
    if (node.tagName === '#text' || node.tagName === '#root') {
      return false;
    }
    if (seg.tagName.length > 0 && node.tagName !== seg.tagName) {
      return false;
    }
    if (seg.id.length > 0 && node.attributes['id'] !== seg.id) {
      return false;
    }
    for (let i = 0; i < seg.classes.length; i++) {
      const cls = seg.classes[i];
      const nodeCls = node.attributes['class'] || '';
      const clsList = nodeCls.split(/\s+/);
      if (clsList.indexOf(cls) === -1) {
        return false;
      }
    }
    const attrKeys = Object.keys(seg.attrs);
    for (let i = 0; i < attrKeys.length; i++) {
      const k = attrKeys[i];
      const expect = seg.attrs[k];
      const actual = node.attributes[k] || '';
      if (expect.length > 0) {
        if (actual !== expect) {
          return false;
        }
      } else {
        if (node.attributes[k] === undefined) {
          return false;
        }
      }
    }
    return true;
  }

  /**
   * 拆分 XPath：/ 与 // 均为后代关系（简化），保留段
   */
  private splitXpath(xpath: string): string[] {
    // 去除开头 //
    let s = xpath.trim();
    if (s.startsWith('//')) {
      s = s.substring(2);
    } else if (s.startsWith('/')) {
      s = s.substring(1);
    }
    // 按 / 拆分（避开 [ ] 内的 /）
    const out: string[] = [];
    let depth = 0;
    let cur = '';
    for (let i = 0; i < s.length; i++) {
      const ch = s.charAt(i);
      if (ch === '[') {
        depth++;
      } else if (ch === ']') {
        depth--;
      }
      if (ch === '/' && depth === 0) {
        if (cur.length > 0) {
          out.push(cur);
        }
        cur = '';
      } else {
        cur += ch;
      }
    }
    if (cur.length > 0) {
      out.push(cur);
    }
    return out;
  }

  /**
   * 解析 XPath 段：tagName[@attr='v'][N]
   */
  private parseXpathSegment(segStr: string): CssSegment {
    const seg: CssSegment = {
      tagName: '',
      id: '',
      classes: [],
      attrs: {},
      index: -1,
      directChild: false
    };
    let rest = segStr.trim();
    // [N] 索引
    const idxMatch = rest.match(/\[(\d+)\]$/);
    if (idxMatch !== null) {
      seg.index = parseInt(idxMatch[1], 10);
      rest = rest.substring(0, idxMatch.index);
    }
    // [@attr='v']
    const attrMatches = rest.match(/\[@([\w-]+)\s*=\s*'([^']*)'\]/g);
    if (attrMatches !== null) {
      for (let i = 0; i < attrMatches.length; i++) {
        const m = attrMatches[i].match(/\[@([\w-]+)\s*=\s*'([^']*)'\]/);
        if (m !== null) {
          seg.attrs[m[1]] = m[2];
        }
      }
      rest = rest.replace(/\[@([\w-]+)\s*=\s*'([^']*)'\]/g, '');
    }
    seg.tagName = rest.trim().toLowerCase();
    return seg;
  }
}

/**
 * JSONPath 工具（子集）：
 * 支持 $.a.b[0].c、$['a']、$..key（递归取首个）、[0] 索引
 * 输入/输出均为 JSON 字符串
 */
export class JsonPathUtils {
  /**
   * 对 JSON 字符串执行 JSONPath，返回结果 JSON 字符串；
   * 若结果是标量返回其字符串表达。
   */
  static query(jsonStr: string, path: string): string {
    let obj: Object | null = null;
    try {
      obj = JSON.parse(jsonStr);
    } catch (e) {
      return '';
    }
    if (obj === null || obj === undefined) {
      return '';
    }
    const tokens = JsonPathUtils.tokenize(path);
    if (tokens.length === 0) {
      return jsonStr;
    }
    const result = JsonPathUtils.evalPath(obj, tokens, 0);
    if (result === undefined || result === null) {
      return '';
    }
    if (typeof result === 'string' || typeof result === 'number' || typeof result === 'boolean') {
      return String(result);
    }
    try {
      return JSON.stringify(result);
    } catch (e) {
      return '';
    }
  }

  /**
   * 取 JSON 中所有匹配 key 的值（用于 $..key），返回第一个匹配值的 JSON 字符串
   */
  static queryAll(jsonStr: string, key: string): string {
    let obj: Object | null = null;
    try {
      obj = JSON.parse(jsonStr);
    } catch (e) {
      return '';
    }
    const found: Object[] = [];
    JsonPathUtils.deepCollect(obj, key, found);
    if (found.length === 0) {
      return '';
    }
    const v = found[0];
    if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') {
      return String(v);
    }
    try {
      return JSON.stringify(v);
    } catch (e) {
      return '';
    }
  }

  private static tokenize(path: string): string[] {
    let s = path.trim();
    if (s.startsWith('$')) {
      s = s.substring(1);
    }
    const tokens: string[] = [];
    let i = 0;
    while (i < s.length) {
      const ch = s.charAt(i);
      if (ch === '.') {
        i++;
        continue;
      }
      if (ch === '[') {
        const end = s.indexOf(']', i);
        if (end === -1) {
          break;
        }
        let inner = s.substring(i + 1, end).trim();
        if (inner.startsWith('\'') || inner.startsWith('"')) {
          inner = inner.substring(1, inner.length - 1);
        }
        tokens.push(inner);
        i = end + 1;
        continue;
      }
      // 普通 key
      let j = i;
      while (j < s.length && s.charAt(j) !== '.' && s.charAt(j) !== '[') {
        j++;
      }
      const key = s.substring(i, j);
      if (key.length > 0) {
        tokens.push(key);
      }
      i = j;
    }
    return tokens;
  }

  private static evalPath(obj: Object | null | undefined, tokens: string[], idx: number): Object | null | undefined {
    if (idx >= tokens.length) {
      return obj;
    }
    const tok = tokens[idx];
    if (obj === null || obj === undefined) {
      return undefined;
    }
    let next: Object | null | undefined = undefined;
    if (Array.isArray(obj)) {
      const arr = obj as Object[];
      const arrIdx = parseInt(tok, 10);
      if (!isNaN(arrIdx) && arrIdx >= 0 && arrIdx < arr.length) {
        next = arr[arrIdx];
      } else {
        return undefined;
      }
    } else if (typeof obj === 'object') {
      const rec = obj as Record<string, Object>;
      next = rec[tok];
    } else {
      return undefined;
    }
    return JsonPathUtils.evalPath(next, tokens, idx + 1);
  }

  private static deepCollect(obj: Object | null | undefined, key: string, out: Object[]): void {
    if (obj === null || obj === undefined) {
      return;
    }
    if (Array.isArray(obj)) {
      const arr = obj as Object[];
      for (let i = 0; i < arr.length; i++) {
        JsonPathUtils.deepCollect(arr[i], key, out);
      }
      return;
    }
    if (typeof obj === 'object') {
      const rec = obj as Record<string, Object>;
      const keys = Object.keys(rec);
      for (let i = 0; i < keys.length; i++) {
        if (keys[i] === key) {
          out.push(rec[keys[i]]);
        }
        JsonPathUtils.deepCollect(rec[keys[i]], key, out);
      }
    }
  }
}
