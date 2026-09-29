import { ThemeStorageKey } from '../constants/Theme'
import { ThemeItem } from '../model/Theme'

/** 深色模式统一色板 */
export const DARK_BG: string = '#232323'
export const DARK_CARD: string = '#2d2d2d'
export const DARK_TEXT: string = '#e6e6e6'
export const DARK_SUB_TEXT: string = '#9a9a9a'
export const DARK_DIVIDER: string = '#3a3a3a'
/** 浅色模式统一背景 */
export const LIGHT_BG: string = '#ffffff'

const IS_DARK_KEY: string = 'isdark'

/**
 * 深色/浅色模式管理器：
 * - isdark 全局标志持久化（PersistentStorage）
 * - 切换时同步替换 AppStorage.theme（主题色变量跟随，全局 @StorageProp(theme) 页面即时生效）
 * - 页面背景/文字可读取 DARK_* 常量跟随
 */
export class ThemeModeManager {
  static get isDark(): boolean {
    return AppStorage.get<boolean>(IS_DARK_KEY) ?? false
  }

  static setDark(val: boolean): void {
    AppStorage.setOrCreate<boolean>(IS_DARK_KEY, val)
  }

  /** 返回切换后的深色状态（true=深色） */
  toggle(theme: ThemeItem, index: number): boolean {
    const dark: boolean = !ThemeModeManager.isDark
    ThemeModeManager.setDark(dark)
    if (dark) {
      const darkTheme: ThemeItem = {
        text: theme.text + '·深色',
        mainColor: theme.mainColor,
        secondColor: DARK_BG
      }
      AppStorage.setOrCreate<ThemeItem>(ThemeStorageKey.THEME, darkTheme)
    } else {
      // 恢复浅色主题（从主题列表取当前索引的浅色项，兜底用传入 theme）
      const themeList: ThemeItem[] = AppStorage.get<ThemeItem[]>(ThemeStorageKey.THEMELIST) ?? []
      const idx: number = AppStorage.get<number>(ThemeStorageKey.THEMEINDEX) ?? index
      const light: ThemeItem = themeList[idx] ?? theme
      AppStorage.setOrCreate<ThemeItem>(ThemeStorageKey.THEME, light)
    }
    return dark
  }
}

export default new ThemeModeManager()
