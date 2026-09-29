/**
 * ExploreParser —— 发现（分类）页端侧解析
 *
 * 改造前：POST {BASE_URL}/common/analysisRules 远端解析。
 * 改造后：requestUtils 端侧抓取发现页 -> RuleAnalyzer 本地执行 ruleExplore 规则。
 */
import { ExploreRule } from '../../../database/entities/rule';
import { RuleAnalyzer } from '../analyzeRule/RuleAnalyzer';
import { SearchConfig, parseSearchString } from '../SearchConfig';
import requestUtil from '../../utils/requestUtils';
import { isNetworkUrl } from '../../utils/utils';

export class ExploreParser {
  /**
   * 解析发现页（支持分页 url 已由调用方替换好 {{page}}）
   * 兼容安卓 legado exploreUrl 格式：
   *  - 纯 URL
   *  - URL,{"method":"POST","body":"...","charset":"utf-8","headers":"{...}","webView":true}
   *  - URL@@method=POST@@body=...@@headers={...}
   * @param jsLib 书源 jsLib，发现规则中 @js: / {{}} 表达式依赖的 JS 库
   * @param sourceHeader 书源 header（JSON 字符串），合并到请求头
   */
  async parse(bookSourceUrl: string, url: string, exploreRule: ExploreRule, jsLib?: string, sourceHeader?: string): Promise<ExploreRule[]> {
    const list: ExploreRule[] = [];
    if (!exploreRule) {
      return list;
    }
    // 1. 解析请求串（支持安卓 exploreUrl 的 JSON 配置 / @@ 语法）
    const rawUrl = (url || '').trim();
    let config: SearchConfig;
    try {
      config = parseSearchString(rawUrl);
    } catch (e) {
      config = new SearchConfig('', 'GET', '', 'UTF-8', rawUrl, false, '');
    }
    let targetUrl = config.path.length > 0 ? config.path : config.url;
    if (targetUrl.length === 0) {
      targetUrl = rawUrl;
    }
    // 相对路径拼接书源域名
    if (!isNetworkUrl(targetUrl)) {
      targetUrl = bookSourceUrl + targetUrl;
    }
    config.url = targetUrl;
    config.path = targetUrl;
    // 2. 端侧抓取
    let html = '';
    try {
      html = await requestUtil.requestHtml(config, sourceHeader ?? '');
    } catch (e) {
      // 兜底：POST/object 响应（与 XmlAnalysis 搜索链路保持一致）
      try {
        html = await requestUtil.requestUrlHtml(targetUrl);
      } catch (e2) {
        html = '';
      }
    }
    if (html.length === 0) {
      return list;
    }
    // 2. 本地规则解析
    const analyzer = new RuleAnalyzer();
    analyzer.setBaseUrl(bookSourceUrl);
    if (jsLib && jsLib.length > 0) {
      analyzer.setJsLib(jsLib);
    }
    const ruleMap: Record<string, string> = {};
    const src = exploreRule as Record<string, string | undefined>;
    const keys = Object.keys(src);
    for (let i = 0; i < keys.length; i++) {
      const v = src[keys[i]];
      if (v !== undefined) {
        ruleMap[keys[i]] = v;
      }
    }
    const rows = analyzer.getExplore(html, ruleMap);
    // 3. 映射为 ExploreRule
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const item: ExploreRule = {};
      item.name = row['name'] || '';
      item.author = row['author'] || '';
      item.intro = row['intro'] || '';
      item.kind = row['kind'] || '';
      item.lastChapter = row['lastChapter'] || '';
      item.wordCount = row['wordCount'] || '';
      item.bookUrl = row['bookUrl'] || '';
      item.coverUrl = row['coverUrl'] || '';
      if (item.bookUrl && !isNetworkUrl(item.bookUrl)) {
        item.bookUrl = bookSourceUrl + item.bookUrl;
      }
      if (item.coverUrl && !isNetworkUrl(item.coverUrl)) {
        item.coverUrl = bookSourceUrl + item.coverUrl;
      }
      if (item.name.length > 0 || item.bookUrl.length > 0) {
        list.push(item);
      }
    }
    return list;
  }
}

const exploreParser = new ExploreParser();
export default exploreParser as ExploreParser;
