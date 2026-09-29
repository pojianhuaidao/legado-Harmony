import bookDataPreferences from './DataPreferencesUtils'

/**
 * 设置项持久化管理器：所有"我的设置"开关统一走 Preferences 持久化，
 * 保证开关状态真实保存、重启不丢失，并可供全局消费点读取。
 */
export class SettingsManager {
  private BOOL_KEYS: string[] = [
    'setRefresh', 'setJump', 'setReplace', 'setTip',
    'setImgAnti', 'setAwaken', 'setHead', 'setSearch'
  ];

  getBool(key: string): boolean {
    if (key.length === 0) {
      return true;
    }
    const v = bookDataPreferences.shared.get(key);
    if (v === null || v === undefined) {
      return true;
    }
    return v === true || String(v) === 'true';
  }

  setBool(key: string, val: boolean): void {
    bookDataPreferences.shared.set(key, val);
  }

  getNum(key: string, def: number): number {
    const v = bookDataPreferences.shared.get(key);
    if (v === null || v === undefined) {
      return def;
    }
    const n = Number(v);
    return Number.isNaN(n) ? def : n;
  }

  setNum(key: string, val: number): void {
    bookDataPreferences.shared.set(key, val);
  }

  getStr(key: string, def: string): string {
    const v = bookDataPreferences.shared.get(key);
    if (v === null || v === undefined) {
      return def;
    }
    return String(v);
  }

  setStr(key: string, val: string): void {
    bookDataPreferences.shared.set(key, val);
  }
}

export default new SettingsManager();
