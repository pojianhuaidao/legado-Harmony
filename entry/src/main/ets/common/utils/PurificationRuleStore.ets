import dataPreferences from '@ohos.data.preferences';

// 净化规则数据模型
export interface PurificationRule {
  name: string
  enabled: boolean
  rules: string[]
}

// 净化规则持久化存储（Preferences）
class PurificationRuleStore {
  preferences?: dataPreferences.Preferences;
  preferencesName: string = 'purification_rules_store';
  key: string = 'purification_rules';

  initPreferences() {
    if (!this.preferences) {
      let context = getContext(this);
      this.preferences = dataPreferences.getPreferencesSync(context, { name: this.preferencesName });
    }
  }

  // 获取全部净化规则
  getAll(): PurificationRule[] {
    this.initPreferences();
    const raw = this.preferences?.getSync(this.key, '[]') as string;
    try {
      const arr = JSON.parse(raw) as PurificationRule[];
      return arr;
    } catch (e) {
      return [];
    }
  }

  // 保存全部净化规则
  saveAll(list: PurificationRule[]) {
    this.initPreferences();
    this.preferences?.putSync(this.key, JSON.stringify(list));
    this.preferences?.flush();
  }

  // 解析导入文本（安卓legado净化源格式：数组或单对象）
  static parseImport(text: string): PurificationRule[] {
    const result: PurificationRule[] = [];
    try {
      const data = JSON.parse(text);
      if (Array.isArray(data)) {
        data.forEach((item: object) => {
          const obj = item as Record<string, Object>;
          const name = obj['name'] !== undefined ? String(obj['name']) : '未命名规则';
          const rules = obj['rules'] !== undefined && Array.isArray(obj['rules']) ? obj['rules'].map((r: Object) => String(r)) : [];
          result.push({ name: name, enabled: true, rules: rules });
        });
      } else {
        const obj = data as Record<string, Object>;
        const name = obj['name'] !== undefined ? String(obj['name']) : '未命名规则';
        const rules = obj['rules'] !== undefined && Array.isArray(obj['rules']) ? obj['rules'].map((r: Object) => String(r)) : [];
        result.push({ name: name, enabled: true, rules: rules });
      }
    } catch (e) {
      return [];
    }
    return result;
  }
}

const purificationRuleStore = new PurificationRuleStore();
export default purificationRuleStore as PurificationRuleStore;
