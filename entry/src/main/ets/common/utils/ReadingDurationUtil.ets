import bookDataPreferences from './DataPreferencesUtils';

const READING_DURATION_PREFIX: string = 'reading_duration_'

/**
 * 阅读时长统计工具：按天记录阅读秒数，供"我的"页展示今日阅读时间。
 */
export default class ReadingDurationUtil {

  /**
   * 记录本次阅读时长（秒），累加到当日
   */
  static record(seconds: number): void {
    if (seconds <= 0) {
      return
    }
    const key = ReadingDurationUtil.todayKey()
    const old = bookDataPreferences.get(key)
    let total: number = 0
    if (typeof old === 'number') {
      total = old
    }
    bookDataPreferences.set(key, total + Math.floor(seconds))
  }

  /**
   * 获取今日累计阅读分钟数
   */
  static getTodayMinutes(): number {
    const key = ReadingDurationUtil.todayKey()
    const value = bookDataPreferences.get(key)
    if (typeof value !== 'number' || value <= 0) {
      return 0
    }
    return Math.floor(value / 60)
  }

  private static todayKey(): string {
    const now = new Date()
    const y = now.getFullYear()
    const m = now.getMonth() + 1
    const d = now.getDate()
    return `${READING_DURATION_PREFIX}${y}-${m < 10 ? '0' + m : m}-${d < 10 ? '0' + d : d}`
  }
}
