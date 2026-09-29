/**
 * exploreUrlUtils —— 书源发现（exploreUrl）格式兼容工具
 *
 * 兼容安卓 legado 书源两种 exploreUrl 格式：
 *  1. 新版 JSON 数组：[{"title":"...","url":"...","style":{...}}, ...]
 *  2. 旧版"标题::url"换行分隔：玄幻魔法::/novels/class/1.htm\n修真武侠::/novels/class/2.htm
 *
 * 历史根因：BodyContent / ContentRefresh 直接 JSON.parse(exploreUrl)，
 * 旧版格式抛 SyntaxError 被 catch 吞掉后书源被过滤 / 发现列表为空，
 * 导致发现页"无小说源 / 该书源暂无发现内容"。
 */
import { ExploreItem } from '../../database/types/BookSourceType';
import { JSON } from '@kit.ArkTS';

/**
 * 解析 exploreUrl 为 ExploreItem 列表。
 *  - JSON 数组：原样解析，自动剔除无效项
 *  - 旧版"标题::url"换行格式：按行切分，取首个 "::" 为分隔
 *  - 非法 / 空：返回空数组（不抛异常）
 */
export function parseExploreUrl(raw: string): ExploreItem[] {
  const out: ExploreItem[] = [];
  if (!raw || raw.trim().length === 0) {
    return out;
  }
  const trimmed = raw.trim();
  if (trimmed.startsWith('[')) {
    try {
      const arr = JSON.parse(trimmed) as ExploreItem[];
      if (Array.isArray(arr)) {
        for (let i = 0; i < arr.length; i++) {
          const item = arr[i];
          if (item === null || item === undefined) {
            continue;
          }
          const t = (item.title || '').trim();
          const u = (item.url || '').trim();
          if (t.length === 0 && u.length === 0) {
            continue;
          }
          out.push({
            title: t,
            url: u,
            style: item.style
          });
        }
      }
    } catch (e) {
      // JSON 解析失败按旧版格式兜底
      return parseLegacyExploreUrl(trimmed);
    }
    return out;
  }
  // 非 JSON：旧版"标题::url"换行格式
  return parseLegacyExploreUrl(trimmed);
}

/**
 * 旧版"标题::url"换行格式解析
 */
function parseLegacyExploreUrl(raw: string): ExploreItem[] {
  const out: ExploreItem[] = [];
  const lines = raw.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line.length === 0) {
      continue;
    }
    const sep = line.indexOf('::');
    if (sep > -1) {
      const title = line.substring(0, sep).trim();
      const url = line.substring(sep + 2).trim();
      if (url.length > 0) {
        out.push({
          title: title,
          url: url,
          style: undefined
        });
      }
    } else if (line.startsWith('@js:') || line.indexOf('=') > -1) {
      // @js: 动态生成式 exploreUrl：端侧无法执行时跳过该条（不阻塞其它条目）
      continue;
    }
  }
  return out;
}

/**
 * 判断书源是否有可展示的发现内容（供 BodyContent 过滤伪发现源）
 */
export function hasExploreUrlContent(raw: string): boolean {
  return parseExploreUrl(raw).length > 0;
}
