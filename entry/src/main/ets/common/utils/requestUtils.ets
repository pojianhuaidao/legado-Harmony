/**
 * @author 2008
 * @datetime 2024/8/16 11:49
 * @className: requestUtils
 */
import axios, { AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import { SearchConfig } from '../model/SearchConfig';
import { util } from '@kit.ArkTS';

class requestUtils{

  /**
   * 合并自定义请求头（JSON 字符串）到默认请求头。
   * 优先级：默认 < sourceHeader（书源 header） < configHeaders（URL 配置 headers）
   */
  private mergeHeaders(configHeaders: string, sourceHeader: string): Record<string, string> {
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Cookie': this.generateRandomCookie(),
      'Accept-Language': 'zh-CN,zh;q=0.9'
    };
    const merge = (jsonStr: string): void => {
      if (!jsonStr || jsonStr.length === 0) {
        return;
      }
      try {
        const custom = JSON.parse(jsonStr) as Record<string, string>;
        const keys = Object.keys(custom);
        for (let i = 0; i < keys.length; i++) {
          const v = custom[keys[i]];
          if (v !== undefined && v !== null) {
            headers[keys[i]] = String(v);
          }
        }
      } catch (e) {
        console.warn('requestUtils: 自定义请求头解析失败，已忽略', e);
      }
    };
    merge(sourceHeader);
    merge(configHeaders);
    return headers;
  }

  async requestHtml(config: SearchConfig, sourceHeader: string = ''): Promise<string> {
    // 明确类型声明
    const requestOptions: AxiosRequestConfig = {
      headers: this.mergeHeaders(config.headers, sourceHeader),
      responseType: 'array_buffer', // 使用 arraybuffer 以便处理不同编码的文本
      timeout: 5000
    };

    // 判断请求方法，如果没有指定则默认为POST
    const requestMethod: string = config.method ? config.method.toUpperCase() : 'POST';

    // 处理请求
    let response: AxiosResponse<ArrayBuffer>;
    if (requestMethod === 'GET') {
      try {
        response = await axios.get<ArrayBuffer>(config.url, requestOptions);
      } catch (e) {
        response = await axios.post<ArrayBuffer>(config.url, config.body || '', requestOptions);
      }
    } else {
      try {
        response = await axios.post<ArrayBuffer>(config.url, config.body || '', requestOptions);
      } catch (e) {
        response = await axios.get<ArrayBuffer>(config.url, requestOptions);
      }
    }
    let res = this.textDecoder(response.data,config.charset??'UTF-8')
    // 处理响应数据
    return res
  }



  async requestUrlHtml(url: string): Promise<string> {
    // 明确类型声明
    const requestOptions: AxiosRequestConfig = {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Cookie': this.generateRandomCookie(),
        'Accept-Language': 'zh-CN,zh;q=0.9'
      },
      responseType: 'object', // 使用 arraybuffer 以便处理不同编码的文本
      timeout: 5000
    };
    // 处理请求
    let response: AxiosResponse<string>;

    try {
      response = await axios.get<string>(url, requestOptions);
    } catch (e) {
      response = await axios.post<string>(url, requestOptions);
    }
    // 处理响应数据
    return response.data
  }

  private textDecoder(data:ArrayBuffer, encoding:string = 'UTF-8'):string{
    let textDecoder = util.TextDecoder.create(encoding, { ignoreBOM: true });
    const result = new Uint8Array(data);
    let decodedText = textDecoder.decodeWithStream(result);
    return decodedText
  }

  private generateRandomCookie(){
    const randomValue = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
    return `random-cookie=${randomValue}`;
  }
}

const requestUtil = new requestUtils();
export default requestUtil as requestUtils;