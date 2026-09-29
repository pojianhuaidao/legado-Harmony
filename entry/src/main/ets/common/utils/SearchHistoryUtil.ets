import bookDataPreferences from './DataPreferencesUtils'
import { JSON } from '@kit.ArkTS'

const SEARCH_HISTORY_KEY: string = 'searchHistory'
const MAX_HISTORY: number = 20

/**
 * 搜索历史持久化工具：基于 dataPreferences 存储，支持读取/写入/清空。
 * 替换原硬编码假数据，使搜索历史可删除、可持久化。
 */
export class SearchHistoryUtil {

  static getHistory(): string[] {
    const raw = bookDataPreferences.shared.get(SEARCH_HISTORY_KEY)
    if (typeof raw === 'string' && raw) {
      try {
        const arr = JSON.parse(raw) as string[]
        return Array.isArray(arr) ? arr : []
      } catch (e) {
        return []
      }
    }
    return []
  }

  static saveHistory(keyword: string): void {
    if (!keyword) {
      return
    }
    const list = SearchHistoryUtil.getHistory()
    const idx = list.indexOf(keyword)
    if (idx >= 0) {
      list.splice(idx, 1)
    }
    list.unshift(keyword)
    const final = list.slice(0, MAX_HISTORY)
    bookDataPreferences.shared.set(SEARCH_HISTORY_KEY, JSON.stringify(final))
  }

  static clearHistory(): void {
    bookDataPreferences.shared.delete(SEARCH_HISTORY_KEY)
  }
}
