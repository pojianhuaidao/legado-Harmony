/**
 * bookApi —— 书籍详情 / 目录 / 正文的端侧规则解析实现
 *
 * 替代远端 legado.miaogongzi.cc 的详情/目录/正文解析（原 BookDetailPage 无网络逻辑）。
 * 链路：requestUtils 端侧抓取网页 -> RuleAnalyzer 本地解析规则 -> 返回实体。
 *
 * 覆盖：
 *  - getBookInfo：详情页（ruleBookInfo，含 init 指定 URL）
 *  - getToc：目录页（ruleToc，chapterList/chapterName/chapterUrl，formatJs 执行）
 *  - getContent：正文页（ruleContent，content/title，webJs 预执行）
 *  - 规则 engine 字段（jsLib / formatJs / webJs）JS 执行
 *  - 相对 URL 拼接、webView 标记清理、编码默认 UTF-8
 */
import { BookSource } from '../../database/entities/BookSource';
import { SearchBook } from '../../database/entities/SearchBook';
import { BookChapter } from '../BookChapter';
import { RuleAnalyzer } from '../analyzeRule/RuleAnalyzer';
import { SearchConfig } from '../SearchConfig';
import requestUtil from '../../utils/requestUtils';
import { isNetworkUrl } from '../../utils/utils';
import purificationRuleStore from '../../utils/PurificationRuleStore';

/**
 * 正文解析结果
 */
export interface ContentResult {
  content: string;
  title: string;
}

/**
 * 解析后的详情字段（供调用方合并到 SearchBook）
 */
export interface BookInfoResult {
  name: string;
  author: string;
  intro: string;
  kind: string;
  lastChapter: string;
  updateTime: string;
  coverUrl: string;
  tocUrl: string;
  wordCount: string;
}

export class BookApi {
  /**
   * 详情解析：优先使用 ruleBookInfo.init 指定 URL；否则使用 bookUrl
   */
  async getBookInfo(bookSource: BookSource, bookUrl: string): Promise<BookInfoResult> {
    const result: BookInfoResult = {
      name: '', author: '', intro: '', kind: '', lastChapter: '',
      updateTime: '', coverUrl: '', tocUrl: '', wordCount: ''
    };
    const rule = bookSource.ruleBookInfo;
    if (!rule) {
      return result;
    }
    const analyzer = this.createAnalyzer(bookSource);
    // init 规则：可为 URL（含 {{}} 模板）或 JS
    let fetchUrl = bookUrl;
    let source = '';
    if (rule.init && rule.init.length > 0) {
      const initVal = analyzer.getString(rule.init, bookUrl);
      if (initVal.length > 0) {
        fetchUrl = this.resolveUrl(bookSource.bookSourceUrl, initVal);
      }
    }
    const page = await this.fetchHtml(bookSource, fetchUrl);
    if (page.length === 0) {
      return result;
    }
    // 部分书源 init 为 @js: 返回整页内容
    if (rule.init && rule.init.startsWith('@js:')) {
      source = analyzer.getString(rule.init, page);
      if (source.length === 0) {
        source = page;
      }
    } else {
      source = page;
    }
    const fields = analyzer.getBookInfo(source, this.ruleToMap(rule));
    result.name = fields['name'] || '';
    result.author = fields['author'] || '';
    result.intro = fields['intro'] || '';
    result.kind = fields['kind'] || '';
    result.lastChapter = fields['lastChapter'] || '';
    result.updateTime = fields['updateTime'] || '';
    result.wordCount = fields['wordCount'] || '';
    let cover = fields['coverUrl'] || '';
    let toc = fields['tocUrl'] || '';
    if (cover.length > 0 && !isNetworkUrl(cover)) {
      cover = bookSource.bookSourceUrl + cover;
    }
    if (toc.length > 0 && !isNetworkUrl(toc)) {
      toc = bookSource.bookSourceUrl + toc;
    }
    result.coverUrl = cover;
    result.tocUrl = toc;
    return result;
  }

  /**
   * 目录解析：抓取 tocUrl，解析 chapterList 等规则；formatJs 对每章执行
   */
  async getToc(bookSource: BookSource, tocUrl: string): Promise<BookChapter[]> {
    const chapters: BookChapter[] = [];
    const rule = bookSource.ruleToc;
    if (!rule) {
      return chapters;
    }
    const analyzer = this.createAnalyzer(bookSource);
    const page = await this.fetchHtml(bookSource, this.resolveUrl(bookSource.bookSourceUrl, tocUrl));
    if (page.length === 0) {
      return chapters;
    }
    const fields = analyzer.getToc(page, this.ruleToMap(rule));
    const formatJs = rule.formatJs || '';
    for (let i = 0; i < fields.length; i++) {
      const item = fields[i];
      const chapter = new BookChapter();
      chapter.title = item['chapterName'] || '';
      chapter.url = item['chapterUrl'] || '';
      chapter.tag = item['updateTime'] || '';
      chapter.bookUrl = tocUrl;
      chapter.baseUrl = bookSource.bookSourceUrl;
      chapter.index = i;
      // formatJs：章节规则引擎字段，可对章节对象做 JS 变换
      if (formatJs.length > 0 && chapter.url.length > 0) {
        const js = formatJs;
        const jsonStr = 'JSON.stringify({title:' + JSON.stringify(chapter.title)
          + ',url:' + JSON.stringify(chapter.url) + '})';
        const wrapped = '(function(){ var item = ' + jsonStr + '; ' + js + '; return JSON.stringify(item); })();';
        const out = analyzer.getString(wrapped, page);
        if (out.length > 0) {
          // 简化：尝试解析 JSON 结果更新 title/url
          this.tryApplyJsonItem(out, chapter);
        }
      }
      // 相对 URL 拼接
      if (chapter.url.length > 0 && !isNetworkUrl(chapter.url) && !chapter.url.startsWith('{{')) {
        chapter.url = this.resolveUrl(bookSource.bookSourceUrl, chapter.url);
      }
      chapters.push(chapter);
    }
    return chapters;
  }

  /**
   * 正文解析：抓取章节页，content/title 规则；webJs 在解析前执行
   */
  async getContent(bookSource: BookSource, chapterUrl: string): Promise<ContentResult> {
    const result: ContentResult = { content: '', title: '' };
    const rule = bookSource.ruleContent;
    if (!rule) {
      return result;
    }
    const analyzer = this.createAnalyzer(bookSource);
    // 清理 webView 标记（形如 ,{'webView': true}）
    const cleanUrl = this.stripWebViewFlag(chapterUrl);
    let page = await this.fetchHtml(bookSource, this.resolveUrl(bookSource.bookSourceUrl, cleanUrl));
    if (page.length === 0) {
      return result;
    }
    // webJs：正文前执行，结果作为新的 source 参与解析
    if (rule.webJs && rule.webJs.length > 0) {
      const webSource = analyzer.getString(rule.webJs, page);
      if (webSource.length > 0) {
        page = webSource;
      }
    }
    const fields = analyzer.getContent(page, this.ruleToMap(rule));
    result.content = fields['content'] || '';
    result.title = fields['title'] || '';
    // sourceRegex/replaceRegex：正文净化（示例实现，按书源配置）
    if (rule.sourceRegex && rule.sourceRegex.length > 0 && result.content.length > 0) {
      result.content = result.content.replace(new RegExp(rule.sourceRegex, 'g'), '');
    }
    if (rule.replaceRegex && rule.replaceRegex.length > 0 && result.content.length > 0) {
      // replaceRegex 形如 source##replace 或直接正则删除
      const sp = rule.replaceRegex.split('##');
      if (sp.length >= 2) {
        result.content = result.content.replace(new RegExp(sp[0], 'g'), sp[1]);
      } else {
        result.content = result.content.replace(new RegExp(rule.replaceRegex, 'g'), '');
      }
    }
    // 全局净化规则（净化管理导入的规则，正文 scope=content/all，标题 scope=title/all）
    result.content = purificationRuleStore.applyContent(result.content);
    result.title = purificationRuleStore.applyTitle(result.title);
    return result;
  }

  /**
   * 创建规则引擎并注入书源上下文
   */
  private createAnalyzer(bookSource: BookSource): RuleAnalyzer {
    const analyzer = new RuleAnalyzer();
    analyzer.setBaseUrl(bookSource.bookSourceUrl);
    if (bookSource.jsLib && bookSource.jsLib.length > 0) {
      analyzer.setJsLib(bookSource.jsLib);
    }
    return analyzer;
  }

  /**
   * 规则实体 -> 字段 map（供 RuleAnalyzer 通用入口使用）
   */
  private ruleToMap(rule: object): Record<string, string> {
    const map: Record<string, string> = {};
    const src = rule as Record<string, string | undefined>;
    const keys = Object.keys(src);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const v = src[k];
      if (v !== undefined && v !== null) {
        map[k] = v;
      }
    }
    return map;
  }

  /**
   * 相对地址拼接：baseUrl + path；path 为绝对地址时直接返回
   */
  private resolveUrl(baseUrl: string, url: string): string {
    if (url.length === 0) {
      return baseUrl;
    }
    if (isNetworkUrl(url) || url.startsWith('//')) {
      return url;
    }
    // 处理 ./ ../ 相对路径
    if (url.startsWith('./')) {
      return baseUrl + url.substring(1);
    }
    if (url.startsWith('../')) {
      // 简化：取 base 目录上一级
      let base = baseUrl;
      if (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      const slash = base.lastIndexOf('/');
      if (slash > 8) {
        return base.substring(0, slash) + url.substring(2);
      }
      return baseUrl + url;
    }
    if (url.startsWith('/')) {
      const m = baseUrl.match(/^(https?:\/\/[^/]+)/);
      if (m !== null) {
        return m[1] + url;
      }
      return baseUrl + url;
    }
    return baseUrl + url;
  }

  /**
   * 清理章节 URL 末尾的 webView 标记（legado 约定：,{'webView': true}）
   */
  private stripWebViewFlag(url: string): string {
    const idx = url.indexOf(",'");
    if (idx > -1) {
      return url.substring(0, idx);
    }
    const idx2 = url.indexOf(',{');
    if (idx2 > -1) {
      return url.substring(0, idx2);
    }
    return url;
  }

  /**
   * 尝试解析 formatJs 输出的 JSON 并回填章节
   */
  private tryApplyJsonItem(jsonStr: string, chapter: BookChapter): void {
    try {
      const obj = JSON.parse(jsonStr) as Record<string, string>;
      if (obj['title'] !== undefined && obj['title'].length > 0) {
        chapter.title = obj['title'];
      }
      if (obj['url'] !== undefined && obj['url'].length > 0) {
        chapter.url = obj['url'];
      }
    } catch (e) {
      // 忽略解析失败，保留原始值
    }
  }

  /**
   * 端侧抓取 HTML
   */
  private async fetchHtml(bookSource: BookSource, url: string): Promise<string> {
    try {
      // 优先 GET 抓取
      const config = new SearchConfig('', 'GET', '', 'UTF-8', url, false);
      return await requestUtil.requestHtml(config);
    } catch (e) {
      // 兜底：POST 或 object 响应
      try {
        return await requestUtil.requestUrlHtml(url);
      } catch (e2) {
        return '';
      }
    }
  }
}

const bookApi = new BookApi();
export default bookApi as BookApi;
