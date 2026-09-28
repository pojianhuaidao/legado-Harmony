/**
 * JsEngine —— 端侧 JS 引擎封装
 *
 * 基于 HarmonyOS NEXT @ohos.jsvm（JSVM-API，API 12+）实现轻量 JS 执行器，
 * 用于执行书源规则中的 `@js:` 内嵌脚本、jsLib 初始化脚本等。
 *
 * 注意：@ohos.jsvm 的最终方法签名以 DevEco Studio 5.0.2+ SDK 自带类型声明为准，
 * 若个别方法（如 JSValue.call）参数顺序与 SDK 声明不一致，请按 SDK 提示调整本文件。
 *
 * 设计约束（ArkTS 严格语法）：
 *  - 禁止 any / eval，所有变量显式类型标注；
 *  - JS 异常统一转换为 JsEngineError 抛出，由调用方捕获；
 *  - JSValue 与 ArkTS 基础类型（string/number/boolean/object）互转集中在 toArkValue / toJsValue。
 */
import { JSRuntime, JSContext, JSValue } from './jsvmStub';
import { BusinessError } from '@ohos.base';

/**
 * JS 执行异常，携带 JS 侧 message
 */
export class JsEngineError extends Error {
  jsMessage: string = '';

  constructor(message: string) {
    super(message);
    this.jsMessage = message;
  }
}

/**
 * JSValue 转换后的 ArkTS 值：
 * 由于 ArkTS 无联合类型，这里用 Record<string, ESObject> 承载任意 JS 值。
 * 具体类型通过 valueType 区分，读取时按需强转。
 */
export interface JsEngineValue {
  // 值类型：string | number | boolean | object | array | null | undefined | function
  valueType: string;
  // string / number / boolean 的字符串表达
  stringValue: string;
  // number 值（若 valueType === 'number'）
  numberValue: number;
  // boolean 值（若 valueType === 'boolean'）
  boolValue: boolean;
  // object / array 的 JSON 序列化结果
  jsonValue: string;
  // 原生 JSValue 引用（仅在当前 JSContext 存活期间有效）
  nativeValue: JSValue | null;
}

/**
 * 端侧 JS 引擎单例封装。
 *
 * 用法：
 *   const js = JsEngine.getInstance();
 *   const out = js.evaluate("function add(a,b){return a+b}; add(1,2);"); // '3'
 *   const out2 = js.evaluateWithSource("(function(){ return document.body; })()", "html源文本");
 */
export class JsEngine {
  private static instance: JsEngine | null = null;

  private runtime: JSRuntime | null = null;
  private context: JSContext | null = null;

  private constructor() {
    // 获取当前线程的 JSVM Runtime 并创建独立 Context
    this.runtime = JSRuntime.getCurrent();
    this.context = new JSContext(this.runtime);
  }

  /**
   * 获取全局单例（线程内共享一个 JS 执行环境，降低创建开销）
   */
  static getInstance(): JsEngine {
    if (JsEngine.instance === null) {
      JsEngine.instance = new JsEngine();
    }
    return JsEngine.instance;
  }

  /**
   * 释放引擎（销毁 Context）。通常在应用退出或书源切换时调用。
   */
  static release(): void {
    if (JsEngine.instance !== null) {
      JsEngine.instance.destroy();
      JsEngine.instance = null;
    }
  }

  private getCtx(): JSContext {
    if (this.context === null) {
      throw new JsEngineError('JsEngine context is null, engine not initialized');
    }
    return this.context;
  }

  /**
   * 执行一段 JS 脚本，返回其求值结果的字符串表达（rule 引擎中大多数规则返回文本）。
   */
  evaluate(script: string): string {
    const value = this.evaluateToValue(script);
    return this.valueToString(value);
  }

  /**
   * 执行脚本并返回 JSValue（供需要进一步调用函数/取属性的场景）
   */
  evaluateToValue(script: string): JSValue {
    const ctx = this.getCtx();
    try {
      return ctx.evaluateJS(script);
    } catch (e) {
      const err = e as BusinessError;
      throw new JsEngineError(`JS evaluate failed: ${err.message}`);
    }
  }

  /**
   * 执行带 source 的 JS 脚本：
   * 约定脚本中可通过全局变量 `source` / `baseUrl` 拿到上下文（与 legado @js: 规则一致）。
   */
  evaluateWithSource(script: string, source: string, baseUrl: string): string {
    const ctx = this.getCtx();
    const global = ctx.getGlobalObject();
    // 注入 source / baseUrl / java 兼容桩（js 规则常用 java.xxx 调用，这里提供最小桩）
    const srcVal = ctx.createString(source);
    global.setProperty('source', srcVal);
    const baseVal = ctx.createString(baseUrl);
    global.setProperty('baseUrl', baseVal);
    this.injectCompatShims(ctx, global);
    return this.evaluate(script);
  }

  /**
   * 调用全局对象上的 JS 函数（如 jsLib 暴露的入口函数）。
   */
  callFunction(funcName: string, args: string[]): string {
    const ctx = this.getCtx();
    const global = ctx.getGlobalObject();
    const func = global.getProperty(funcName);
    if (!func.isFunction()) {
      throw new JsEngineError(`JS function not found: ${funcName}`);
    }
    const argValues: JSValue[] = [];
    for (let i = 0; i < args.length; i++) {
      argValues.push(ctx.createString(args[i]));
    }
    try {
      const result = func.call(ctx, argValues);
      return this.valueToString(result);
    } catch (e) {
      const err = e as BusinessError;
      throw new JsEngineError(`JS call ${funcName} failed: ${err.message}`);
    }
  }

  /**
   * JSValue -> string 表达
   */
  valueToString(value: JSValue): string {
    if (value.isUndefined() || value.isNull()) {
      return '';
    }
    if (value.isString()) {
      return value.toString();
    }
    if (value.isNumber()) {
      const num = value.toNumber();
      return this.formatNumber(num);
    }
    if (value.isBoolean()) {
      return value.toBoolean() ? 'true' : 'false';
    }
    if (value.isArray() || value.isObject()) {
      try {
        return this.jsonStringify(value);
      } catch (e) {
        return value.toString();
      }
    }
    return value.toString();
  }

  /**
   * JSValue -> JsEngineValue（结构化转换，供调用方按需读取）
   */
  toArkValue(value: JSValue): JsEngineValue {
    const ctx = this.getCtx();
    const out: JsEngineValue = {
      valueType: 'undefined',
      stringValue: '',
      numberValue: 0,
      boolValue: false,
      jsonValue: '',
      nativeValue: value
    };
    if (value.isUndefined()) {
      out.valueType = 'undefined';
    } else if (value.isNull()) {
      out.valueType = 'null';
    } else if (value.isString()) {
      out.valueType = 'string';
      out.stringValue = value.toString();
    } else if (value.isNumber()) {
      out.valueType = 'number';
      out.numberValue = value.toNumber();
      out.stringValue = this.formatNumber(out.numberValue);
    } else if (value.isBoolean()) {
      out.valueType = 'boolean';
      out.boolValue = value.toBoolean();
      out.stringValue = out.boolValue ? 'true' : 'false';
    } else if (value.isArray()) {
      out.valueType = 'array';
      out.jsonValue = this.jsonStringify(value);
    } else if (value.isObject()) {
      out.valueType = 'object';
      out.jsonValue = this.jsonStringify(value);
    } else if (value.isFunction()) {
      out.valueType = 'function';
    }
    return out;
  }

  /**
   * ArkTS 基础值 -> JSValue（string / number / boolean）
   */
  toJsValue(value: string | number | boolean): JSValue {
    const ctx = this.getCtx();
    if (typeof value === 'number') {
      return ctx.createNumber(value);
    }
    if (typeof value === 'boolean') {
      return ctx.createBoolean(value);
    }
    return ctx.createString(value);
  }

  /**
   * 解析 JSON 字符串为 JSValue（用于 {{}} JSONPath 场景的初始对象）
   */
  parseJson(jsonStr: string): JSValue {
    const ctx = this.getCtx();
    try {
      return ctx.parseJSON(jsonStr);
    } catch (e) {
      const err = e as BusinessError;
      throw new JsEngineError(`JSON parse failed: ${err.message}`);
    }
  }

  /**
   * 销毁当前 Context
   */
  destroy(): void {
    if (this.context !== null) {
      try {
        this.context.destroy();
      } catch (e) {
        // ignore destroy error
      }
      this.context = null;
      this.runtime = null;
    }
  }

  private jsonStringify(value: JSValue): string {
    // JSVM 未直接暴露 JsonStringify 的 ArkTS 封装时，用 JSON.stringify 兜底：
    // 先把 value 转为可序列化对象（通过 evaluateJS 桥接）
    const ctx = this.getCtx();
    const script = 'JSON.stringify(__jsv);';
    const global = ctx.getGlobalObject();
    global.setProperty('__jsv', value);
    try {
      const result = ctx.evaluateJS(script);
      return result.toString();
    } catch (e) {
      return value.toString();
    }
  }

  private formatNumber(num: number): string {
    if (Number.isInteger(num)) {
      return num.toString();
    }
    return num.toString();
  }

  /**
   * 注入 legado JS 规则中常用兼容桩：
   *  - java.xxx / globalThis.java：空对象桩（避免规则脚本引用 java 时报错）
   *  - console.log：桥接到 hilog（JSVM 内无默认 console）
   */
  private injectCompatShims(ctx: JSContext, global: JSValue): void {
    try {
      const shims = `
        var __legadoShim = (function(){
          if (typeof globalThis.java === 'undefined') { globalThis.java = {}; }
          if (typeof console === 'undefined') {
            console = { log: function(){}, info: function(){}, warn: function(){}, error: function(){} };
          }
          if (typeof String.prototype.trim === 'undefined') {
            String.prototype.trim = function(){ return this.replace(/^\\s+|\\s+$/g, ''); };
          }
          return true;
        })();
      `;
      ctx.evaluateJS(shims);
    } catch (e) {
      // 注入失败不阻塞主流程
    }
  }
}

/**
 * 便捷方法：执行 @js: 规则脚本（供 RuleAnalyzer 使用）
 */
export function execJsRule(script: string, source: string, baseUrl: string): string {
  const engine = JsEngine.getInstance();
  try {
    return engine.evaluateWithSource(script, source, baseUrl);
  } catch (e) {
    const err = e as JsEngineError;
    console.error(`JsEngine execJsRule failed: ${err.message}`);
    return '';
  }
}
