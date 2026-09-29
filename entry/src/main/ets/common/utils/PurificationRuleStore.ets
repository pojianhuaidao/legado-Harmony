import dataPreferences from '@ohos.data.preferences';

// 净化规则条目（对应安卓 legado 的 ReplaceRule 结构：pattern/replacement/scope/isRegex/isEnabled）
export interface PurificationRuleItem {
  pattern: string
  replacement: string
  isRegex: boolean
  scope: string
  enabled: boolean
}

// 净化规则组
export interface PurificationRule {
  name: string
  enabled: boolean
  rules: PurificationRuleItem[]
}

// 宽松导入结构（兼容安卓 legado 净化源 JSON，字段均可选）
interface RawRuleItem {
  pattern?: string
  replacement?: string
  isRegex?: boolean
  isEnabled?: boolean
  enabled?: boolean
  scope?: string
}

interface RawRuleGroup {
  name?: string
  enabled?: boolean
  isEnabled?: boolean
  rules?: (RawRuleItem | string)[]
  pattern?: string
  replacement?: string
  isRegex?: boolean
  scope?: string
}

// 净化规则持久化存储（Preferences）
export class PurificationRuleStore {
  preferences?: dataPreferences.Preferences;
  preferencesName: string = 'purification_rules_store';
  key: string = 'purification_rules';

  initPreferences() {
    if (!this.preferences) {
      let context = getContext(this);
      this.preferences = dataPreferences.getPreferencesSync(context, { name: this.preferencesName });
    }
  }

  // 获取全部净化规则（兼容旧版 string[] 结构与安卓 ReplaceRule 结构，统一转换为 PurificationRuleItem[]）
  getAll(): PurificationRule[] {
    this.initPreferences();
    const raw = this.preferences?.getSync(this.key, '[]') as string;
    try {
      const arr = JSON.parse(raw) as RawRuleGroup[];
      const result: PurificationRule[] = [];
      for (let i = 0; i < arr.length; i++) {
        const item = arr[i];
        const name = item.name !== undefined ? item.name : '未命名规则';
        const enabled = item.enabled === undefined ? true : item.enabled === true;
        const rulesRaw = item.rules;
        const rules: PurificationRuleItem[] = [];
        if (rulesRaw !== undefined && rulesRaw instanceof Array) {
          for (let j = 0; j < rulesRaw.length; j++) {
            const r = rulesRaw[j];
            if (typeof r === 'string') {
              const parsed = PurificationRuleStore.parseRuleString(r);
              if (parsed) {
                rules.push(parsed);
              }
            } else {
              const pattern = r.pattern !== undefined ? r.pattern : '';
              if (pattern.length === 0) {
                continue;
              }
              const replacement = r.replacement !== undefined ? r.replacement : '';
              const isRegex = r.isRegex === undefined ? true : r.isRegex === true;
              const scope = r.scope !== undefined ? r.scope : 'content';
              const rEnabled = r.isEnabled === undefined
                ? (r.enabled === undefined ? true : r.enabled === true)
                : r.isEnabled === true;
              rules.push({ pattern: pattern, replacement: replacement, isRegex: isRegex, scope: scope, enabled: rEnabled });
            }
          }
        }
        result.push({ name: name, enabled: enabled, rules: rules });
      }
      return result;
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

  // 解析导入文本：兼容 安卓legado净化源（[{pattern,replacement,scope,isRegex,isEnabled}] / {name,rules:[...]} / 字符串数组）
  static parseImport(text: string): PurificationRule[] {
    const result: PurificationRule[] = [];
    try {
      const data: Object = JSON.parse(text);
      const arr: Object[] = data instanceof Array ? data : [data];
      for (let i = 0; i < arr.length; i++) {
        const item = arr[i];
        if (typeof item === 'string') {
          const parsed = PurificationRuleStore.parseRuleString(item);
          if (parsed) {
            result.push({ name: `净化规则${result.length + 1}`, enabled: true, rules: [parsed] });
          }
          continue;
        }
        if (item === null || typeof item !== 'object') {
          continue;
        }
        const obj = item as RawRuleGroup;
        const name = obj.name !== undefined ? obj.name : `净化规则${result.length + 1}`;
        const groupEnabled = obj.isEnabled === undefined
          ? (obj.enabled === undefined ? true : obj.enabled === true)
          : obj.isEnabled === true;
        const rulesRaw = obj.rules;
        const rules: PurificationRuleItem[] = [];
        if (rulesRaw !== undefined && rulesRaw instanceof Array) {
          // 旧鸿蒙格式：{name, rules:[string | {pattern,...}]}
          for (let j = 0; j < rulesRaw.length; j++) {
            const r = rulesRaw[j];
            if (typeof r === 'string') {
              const parsed = PurificationRuleStore.parseRuleString(r);
              if (parsed) {
                rules.push(parsed);
              }
            } else {
              const pattern = r.pattern !== undefined ? r.pattern : '';
              if (pattern.length === 0) {
                continue;
              }
              const replacement = r.replacement !== undefined ? r.replacement : '';
              const isRegex = r.isRegex === undefined ? true : r.isRegex === true;
              const scope = r.scope !== undefined ? r.scope : 'content';
              const rEnabled = r.isEnabled === undefined
                ? (r.enabled === undefined ? true : r.enabled === true)
                : r.isEnabled === true;
              rules.push({ pattern: pattern, replacement: replacement, isRegex: isRegex, scope: scope, enabled: rEnabled });
            }
          }
        } else {
          // 安卓 legado 单条替换规则：对象自身即规则
          const pattern = obj.pattern !== undefined ? obj.pattern : '';
          if (pattern.length > 0) {
            const replacement = obj.replacement !== undefined ? obj.replacement : '';
            const isRegex = obj.isRegex === undefined ? true : obj.isRegex === true;
            const scope = obj.scope !== undefined ? obj.scope : 'content';
            const rEnabled = obj.isEnabled === undefined
              ? (obj.enabled === undefined ? true : obj.enabled === true)
              : obj.isEnabled === true;
            rules.push({ pattern: pattern, replacement: replacement, isRegex: isRegex, scope: scope, enabled: rEnabled });
          }
        }
        if (rules.length > 0) {
          result.push({ name: name, enabled: groupEnabled, rules: rules });
        }
      }
    } catch (e) {
      return [];
    }
    return result;
  }

  // 旧格式规则字符串解析：pattern##replacement（无 ## 时视为删除型正则）
  static parseRuleString(s: string): PurificationRuleItem | null {
    const text = s.trim();
    if (text.length === 0) {
      return null;
    }
    const idx = text.indexOf('##');
    if (idx >= 0) {
      return {
        pattern: text.substring(0, idx),
        replacement: text.substring(idx + 2),
        isRegex: true,
        scope: 'content',
        enabled: true
      };
    }
    return { pattern: text, replacement: '', isRegex: true, scope: 'content', enabled: true };
  }

  // 应用全部启用规则到正文（scope 匹配 content/all/空）
  applyContent(content: string): string {
    let out = content;
    const groups = this.getAll();
    for (let g = 0; g < groups.length; g++) {
      const group = groups[g];
      if (!group.enabled) {
        continue;
      }
      for (let i = 0; i < group.rules.length; i++) {
        const item = group.rules[i];
        if (!item.enabled) {
          continue;
        }
        const scope = item.scope;
        if (scope !== 'content' && scope !== 'all' && scope !== '') {
          continue;
        }
        out = this.applyItem(out, item);
      }
    }
    return out;
  }

  // 应用全部启用规则到标题（scope 匹配 title/all/空）
  applyTitle(title: string): string {
    let out = title;
    const groups = this.getAll();
    for (let g = 0; g < groups.length; g++) {
      const group = groups[g];
      if (!group.enabled) {
        continue;
      }
      for (let i = 0; i < group.rules.length; i++) {
        const item = group.rules[i];
        if (!item.enabled) {
          continue;
        }
        const scope = item.scope;
        if (scope !== 'title' && scope !== 'all' && scope !== '') {
          continue;
        }
        out = this.applyItem(out, item);
      }
    }
    return out;
  }

  // 单条规则应用：正则替换或全量文本替换；非法正则跳过
  private applyItem(src: string, item: PurificationRuleItem): string {
    if (item.pattern.length === 0) {
      return src;
    }
    try {
      if (item.isRegex) {
        const re = new RegExp(item.pattern, 'g');
        return src.replace(re, item.replacement);
      }
      // 文本替换：替换全部出现位置
      if (src.indexOf(item.pattern) < 0) {
        return src;
      }
      return src.split(item.pattern).join(item.replacement);
    } catch (e) {
      return src;
    }
  }
}

const purificationRuleStore = new PurificationRuleStore();
export default purificationRuleStore as PurificationRuleStore;
