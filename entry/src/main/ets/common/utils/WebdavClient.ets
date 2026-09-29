/**
 * WebDAV 客户端：参考 pojianhuaidao/lx-music-mobile 的 webdavClient.ts 实现
 * 提供登录验证（PROPFIND）、目录列表（PROPFIND Depth:1）、文件下载（GET）
 */
import axios, { AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@ohos.base';
import fs from '@ohos.file.fs';

export class WebdavItem {
  name: string = '';
  href: string = '';
  isDir: boolean = false;
  size: number = 0;

  constructor(name: string = '', href: string = '', isDir: boolean = false, size: number = 0) {
    this.name = name;
    this.href = href;
    this.isDir = isDir;
    this.size = size;
  }
}

export class WebdavConfig {
  host: string = '';
  account: string = '';
  password: string = '';

  constructor(host: string = '', account: string = '', password: string = '') {
    this.host = host;
    this.account = account;
    this.password = password;
  }
}

class WebdavClient {
  /** 去掉末尾斜杠 */
  private normalizeServer(server: string): string {
    return server.trim().replace(/\/+$/, '');
  }

  /** 路径逐段 URL 编码（空格→%20、中文→百分号编码） */
  private encodePath(path: string): string {
    const segments: string[] = path.split('/').filter((s: string) => s.length > 0);
    let result = '';
    for (let i = 0; i < segments.length; i++) {
      result += (i > 0 ? '/' : '') + encodeURIComponent(segments[i]);
    }
    return result;
  }

  /** 拼接完整 URL */
  buildUrl(config: WebdavConfig, path: string): string {
    const base: string = this.normalizeServer(config.host);
    const encoded: string = this.encodePath(path);
    return encoded.length > 0 ? `${base}/${encoded}` : base;
  }

  /** Basic Auth 请求头 */
  private authHeader(config: WebdavConfig): string {
    const input = `${config.account}:${config.password}`;
    const bytes = new Uint8Array(input.length);
    for (let i = 0; i < input.length; i++) {
      bytes[i] = input.charCodeAt(i);
    }
    const base64Helper = new util.Base64Helper();
    const encoded = base64Helper.encodeSync(bytes);
    let base64Str = '';
    for (let i = 0; i < encoded.length; i++) {
      base64Str += String.fromCharCode(encoded[i]);
    }
    return `Basic ${base64Str}`;
  }

  /** 发 WebDAV 请求，返回 axios 响应 */
  private async request(config: WebdavConfig, method: string, path: string, timeout: number = 15000): Promise<AxiosResponse> {
    const requestOptions: AxiosRequestConfig = {
      url: this.buildUrl(config, path),
      method: method,
      headers: {
        'Authorization': this.authHeader(config),
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
        'Accept-Encoding': 'gzip, deflate',
        ...(method === 'PROPFIND' ? { 'Depth': '1' } : {})
      },
      timeout: timeout
    };
    return await axios.request(requestOptions);
  }

  /** 解析 PROPFIND 多状态 XML，提取目录/文件列表 */
  private parsePropfindXml(xml: string): WebdavItem[] {
    const items: WebdavItem[] = [];
    const responseRegex = /<[^>]*response[^>]*>([\s\S]*?)<\/[^>]*response[^>]*>/gi;
    let match = responseRegex.exec(xml);
    while (match) {
      const block: string = match[1];
      const hrefMatch = /<[^>]*href[^>]*>([\s\S]*?)<\/[^>]*href[^>]*>/i.exec(block);
      const isDir = /<[^>]*collection[^>]*\/?>/i.test(block);
      const sizeMatch = /<[^>]*getcontentlength[^>]*>([\s\S]*?)<\/[^>]*getcontentlength[^>]*>/i.exec(block);
      if (hrefMatch) {
        let href = hrefMatch[1].trim();
        try {
          href = decodeURIComponent(href);
        } catch (e) {
          // 保留原始 href
        }
        // href 可能是完整 URL 或路径，取最后一段作为名称
        const segments: string[] = href.split('/').filter((s: string) => s.length > 0);
        const name: string = segments.length > 0 ? decodeURIComponent(segments[segments.length - 1]) : '';
        let size = 0;
        if (sizeMatch) {
          size = parseInt(sizeMatch[1].trim(), 10);
          if (isNaN(size)) {
            size = 0;
          }
        }
        items.push(new WebdavItem(name, href, isDir, size));
      }
      match = responseRegex.exec(xml);
    }
    return items;
  }

  /**
   * 验证登录并列出目录内容。
   * PROPFIND Depth: 1 返回该路径下的子项（含自身）。
   * 返回的列表已过滤掉目录自身（href 与 path 一致），且 href 归一化为相对路径。
   */
  async listDir(config: WebdavConfig, path: string): Promise<WebdavItem[]> {
    try {
      const resp: AxiosResponse = await this.request(config, 'PROPFIND', path);
      if (resp.status !== 200 && resp.status !== 207) {
        throw new Error(`WebDAV PROPFIND 失败: HTTP ${resp.status}`);
      }
      const data: string = String(resp.data);
      const all: WebdavItem[] = this.parsePropfindXml(data);
      const targetPath: string = this.encodePath(path);
      const result: WebdavItem[] = [];
      for (let i = 0; i < all.length; i++) {
        const item: WebdavItem = all[i];
        // href 归一化为相对路径（去掉服务器前缀与开头的 /）
        item.href = this.normalizeHref(item.href, config);
        // 过滤目录自身条目
        const selfHref: string = item.href.split('/').filter((s: string) => s.length > 0).join('/');
        const selfTarget: string = targetPath.split('/').filter((s: string) => s.length > 0).join('/');
        if (selfHref === selfTarget || selfHref === `${selfTarget}/`) {
          continue;
        }
        result.push(item);
      }
      return result;
    } catch (err) {
      const e = err as BusinessError;
      console.error('WebdavClient listDir failed: ', JSON.stringify(e));
      throw e;
    }
  }

  /** 将 WebDAV href 归一化为相对路径（去除服务器前缀与开头斜杠） */
  private normalizeHref(href: string, config: WebdavConfig): string {
    let rest: string = href;
    const base: string = this.normalizeServer(config.host);
    if (rest.startsWith('http://') || rest.startsWith('https://')) {
      if (base.length > 0 && rest.startsWith(base)) {
        rest = rest.substring(base.length);
      } else {
        const schemeIdx: number = rest.indexOf('://');
        if (schemeIdx >= 0) {
          const pathStart: number = rest.indexOf('/', schemeIdx + 3);
          if (pathStart >= 0) {
            rest = rest.substring(pathStart);
          }
        }
      }
    }
    return rest.replace(/^\/+/, '');
  }

  /** 验证登录：对根目录做 PROPFIND，401 表示凭据错误 */
  async verifyLogin(config: WebdavConfig): Promise<boolean> {
    try {
      const resp: AxiosResponse = await this.request(config, 'PROPFIND', '', 15000);
      return resp.status === 200 || resp.status === 207;
    } catch (err) {
      const e = err as BusinessError;
      console.error('WebdavClient verifyLogin failed: ', JSON.stringify(e));
      return false;
    }
  }

  /** 下载文件到指定沙箱路径，返回是否成功 */
  async downloadFile(config: WebdavConfig, path: string, savePath: string): Promise<boolean> {
    try {
      const resp: AxiosResponse = await this.request(config, 'GET', path, 60000);
      if (resp.status !== 200) {
        console.error('WebdavClient downloadFile HTTP: ', resp.status);
        return false;
      }
      const arrayBuf = resp.data as ArrayBuffer;
      const file = fs.openSync(savePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, arrayBuf);
      fs.closeSync(file);
      return true;
    } catch (err) {
      const e = err as BusinessError;
      console.error('WebdavClient downloadFile failed: ', JSON.stringify(e));
      return false;
    }
  }
}

const webdavClient = new WebdavClient();
export default webdavClient as WebdavClient;
