/**
 * @ohos.jsvm 本地类型 Stub（仅用于无 jsvm 的 CI 构建产物）
 *
 * 背景：OpenHarmony 开源 SDK（setup-ohos 提供的 5.0.13.200 等 CLI tools）
 * 不包含 HarmonyOS NEXT 商业 API @ohos.jsvm（JSVM-API），导致远程 CI 编译
 * JsEngine.ets 时 "could not be resolved" 失败。
 *
 * 本文件以相同类名/方法签名占位，使 CI 可编译产出 unsigned HAP；
 * 但运行时调用 JSVM 能力会抛出明确错误，提示改用本机 DevEco Studio
 * 完整 SDK 环境构建以启用书源 JS 规则执行。
 *
 * 注意：真机/模拟器安装 CI 产物后，@js: 规则、jsLib 脚本等将不可用，
 * 如需完整书源解析功能请在 DevEco Studio 中构建安装。
 */
export class JSRuntime {
  static getCurrent(): JSRuntime {
    return new JSRuntime();
  }
}

export class JSContext {
  private rt: JSRuntime;

  constructor(runtime: JSRuntime) {
    this.rt = runtime;
  }

  evaluateJS(script: string): JSValue {
    throw new Error('@ohos.jsvm is stubbed in CI build; build with DevEco Studio for JS rules');
  }

  getGlobalObject(): JSValue {
    return new JSValue();
  }

  createString(value: string): JSValue {
    return new JSValue();
  }

  createNumber(value: number): JSValue {
    return new JSValue();
  }

  createBoolean(value: boolean): JSValue {
    return new JSValue();
  }

  parseJSON(jsonStr: string): JSValue {
    throw new Error('@ohos.jsvm is stubbed in CI build; build with DevEco Studio for JS rules');
  }

  destroy(): void {
  }
}

export class JSValue {
  isUndefined(): boolean {
    return true;
  }

  isNull(): boolean {
    return false;
  }

  isString(): boolean {
    return false;
  }

  isNumber(): boolean {
    return false;
  }

  isBoolean(): boolean {
    return false;
  }

  isArray(): boolean {
    return false;
  }

  isObject(): boolean {
    return false;
  }

  isFunction(): boolean {
    return false;
  }

  toString(): string {
    return '';
  }

  toNumber(): number {
    return 0;
  }

  toBoolean(): boolean {
    return false;
  }

  getProperty(name: string): JSValue {
    return new JSValue();
  }

  setProperty(name: string, value: JSValue): void {
  }

  call(ctx: JSContext, args: JSValue[]): JSValue {
    throw new Error('@ohos.jsvm is stubbed in CI build; build with DevEco Studio for JS rules');
  }
}
