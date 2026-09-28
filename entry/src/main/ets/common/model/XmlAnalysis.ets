/**
 * XmlAnalysis —— 搜索解析（端侧规则引擎实现）
 *
 * 改造前：POST {BASE_URL}/search/analysisBook 远端解析。
 * 改造后：requestUtils 端侧抓取搜索页 -> RuleAnalyzer 本地执行 ruleSearch 规则。
 */
import { SearchRule } from '../../database/entities/rule';
import { SearchBook } from '../../database/entities/SearchBook';
import { BookSource } from '../../database/entities/BookSource';
import { RuleAnalyzer } from './analyzeRule/RuleAnalyzer';
import { SearchConfig } from './SearchConfig';
import requestUtil from '../utils/requestUtils';
import { isNetworkUrl } from '../utils/utils';


export interface IXmlAnalysis {
  baseUrl: string  //搜索地址
  body:string  //请求内容
  bookSource:BookSource//书源
  variable?:string
  searchUrl:string
}
export class XmlAnalysisData {
  baseUrl: string = ''  //搜索地址
  body:string = ''//请求内容
  bookSource?:BookSource//书源
  variable?:string
  searchUrl:string = ''
  constructor(xmlDate?: IXmlAnalysis) {
    this.baseUrl = xmlDate?.baseUrl || ''
    this.body = xmlDate?.body || ''
    this.bookSource = xmlDate?.bookSource
    this.variable = xmlDate?.variable
    this.searchUrl = xmlDate?.searchUrl || ''
  }
}
export class XmlAnalysis {
  xmlDate:XmlAnalysisData = new XmlAnalysisData()
  url:string = ''
  source?:SearchRule
  searchUrl:string = ''
  init(xmlDate:XmlAnalysisData){
    this.xmlDate = xmlDate
    this.url = xmlDate.searchUrl
    this.source = this.xmlDate.bookSource?.ruleSearch
    this.searchUrl = this.xmlDate.searchUrl
  }

  async getBookList(): Promise<SearchBook[]>  {
    const bookList:SearchBook[] = []
    if (!this.source || !this.xmlDate.bookSource) return bookList
    const bookSource = this.xmlDate.bookSource
    // 1. 端侧抓取搜索页
    const config = new SearchConfig('', 'GET', this.xmlDate.body, 'UTF-8', this.searchUrl, false)
    let html = ''
    try {
      html = await requestUtil.requestHtml(config)
    } catch (e) {
      // 兜底：POST/object 响应
      try {
        html = await requestUtil.requestUrlHtml(this.searchUrl)
      } catch (e2) {
        html = ''
      }
    }
    if (html.length === 0) {
      return bookList
    }
    // 2. 本地规则解析
    const analyzer = new RuleAnalyzer()
    analyzer.setBaseUrl(bookSource.bookSourceUrl)
    if (bookSource.jsLib && bookSource.jsLib.length > 0) {
      analyzer.setJsLib(bookSource.jsLib)
    }
    const ruleMap: Record<string, string> = {}
    const searchRule = this.source as Record<string, string | undefined>
    const keys = Object.keys(searchRule)
    for (let i = 0; i < keys.length; i++) {
      const v = searchRule[keys[i]]
      if (v !== undefined) {
        ruleMap[keys[i]] = v
      }
    }
    const rows = analyzer.getBookList(html, ruleMap)
    // 3. 映射为 SearchBook
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i]
      const item = new SearchBook()
      item.name = row['name'] || ''
      item.author = row['author'] || ''
      item.intro = row['intro'] || ''
      item.kind = row['kind'] || ''
      item.latestChapterTitle = row['lastChapter'] || ''
      item.wordCount = row['wordCount'] || ''
      item.origin = bookSource.bookSourceUrl
      item.originName = bookSource.bookSourceName
      item.type = 'text'
      item.bookType = bookSource.bookSourceType ?? 0
      item.source = bookSource
      item.bookUrl = row['bookUrl'] || ''
      item.coverUrl = row['coverUrl'] || ''
      if (item.bookUrl && !isNetworkUrl(item.bookUrl)){
        item.tocUrl = bookSource.bookSourceUrl + item.bookUrl
      } else {
        item.tocUrl = item.bookUrl
      }
      if (item.coverUrl && !isNetworkUrl(item.coverUrl)) {
        item.coverUrl = bookSource.bookSourceUrl + item.coverUrl
      }
      if (item.name.length > 0) {
        bookList.push(item)
      }
    }
    return bookList
  }

  //解析xml
  async analysisXml(): Promise<SearchBook[]> {
    return await this.getBookList();
  }

}
