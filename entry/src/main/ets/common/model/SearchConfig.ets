/**
 * @author 2008
 * @datetime 2024/8/15 0:06
 * @className: SearchConfig
 */
export class SearchConfig {
  path: string;
  method: string;
  body: string;
  charset: string;
  url: string;
  webView:boolean;
  // 自定义请求头（JSON 字符串，legado 书源 header 或 URL 配置 headers 字段）
  headers: string;

  constructor(path: string, method: string, body: string, charset: string, url: string, webView:boolean, headers: string = '') {
    this.path = path;
    this.method = method.toUpperCase(); // 确保方法为大写
    this.body = body;
    this.charset = charset??'UTF-8';
    this.url = url;
    this.webView = webView
    this.headers = headers;
  }

  // 替换 body 中的关键字
  setKeyword(keyword: string): void {
    this.body = this.body.replace('{{key}}', encodeURIComponent(keyword));
  }
}

interface SearchConfigData {
  method: string;
  body?: string;
  charset?: string;
  url: string;
  webView?:boolean;
  headers?: string;
}

/**
 * 解析 legado URL 请求串（对齐安卓 AnalyzeUrl / HttpUrl）：
 *  1) 旧式：path,{"charset":"utf-8","method":"POST","body":"...","headers":"{...}","webView":true}
 *  2) 新版：path@@method=POST@@body=...@@charset=utf-8@@headers={...}@@webView=true
 * 无逗号/@@ 时视为纯 URL。
 */
export function parseSearchString(searchString: string): SearchConfig {
  let str = searchString.trim();
  if (str.length === 0) {
    return new SearchConfig('', 'GET', '', 'UTF-8', '', false, '');
  }
  let method = 'GET';
  let body = '';
  let charset = 'UTF-8';
  let headers = '';
  let webView = false;
  let path = str;

  const atIdx = str.indexOf('@@');
  if (atIdx > 0) {
    // @@ 语法
    path = str.substring(0, atIdx).trim();
    const opts = str.substring(atIdx + 2).split('@@');
    for (let i = 0; i < opts.length; i++) {
      const opt = opts[i].trim();
      const eq = opt.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const key = opt.substring(0, eq).trim().toLowerCase();
      const val = opt.substring(eq + 1).trim();
      if (key === 'method') {
        method = val;
      } else if (key === 'body') {
        body = val;
      } else if (key === 'charset' || key === 'encoding') {
        charset = val;
      } else if (key === 'headers' || key === 'header') {
        headers = val;
      } else if (key === 'webview') {
        webView = val === 'true' || val === '1';
      }
    }
  } else {
    const splitIndex = str.indexOf(',');
    if (splitIndex > -1) {
      path = str.substring(0, splitIndex).trim();
      const configString = str.substring(splitIndex + 1).trim();
      // 先尝试标准 JSON 解析（合法 JSON 直接成功，避免破坏嵌套 headers 字符串）
      let config: SearchConfigData | null = null;
      try {
        config = JSON.parse(configString) as SearchConfigData;
      } catch (e) {
        // 兼容单引号/无引号 key 的宽松写法
        try {
          const cleanConfigString = configString
            .replace(/([{,]\s*)(\w+)\s*:/g, '$1"$2":')
            .replace(/'/g, '"');
          config = JSON.parse(cleanConfigString) as SearchConfigData;
        } catch (e2) {
          config = null;
        }
      }
      if (config !== null && config !== undefined) {
        method = config.method ?? 'GET';
        body = config.body ?? '';
        charset = config.charset ?? 'UTF-8';
        webView = config.webView ?? false;
        headers = config.headers ?? '';
      } else {
        // 解析失败：整体视为纯 URL（path 保留完整串）
        path = str.trim();
      }
    }
  }

  return new SearchConfig('', method, body, charset, path, webView, headers);
}
