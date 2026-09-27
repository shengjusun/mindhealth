/**
 * 日志工具类
 * @description 统一的日志管理工具
 */

import hilog from '@ohos.hilog';

// 日志配置
const LOG_DOMAIN = 0x0000;  // 日志域
const LOG_PREFIX = 'QingXinAI';  // 日志前缀

/**
 * 日志级别枚举
 */
enum LogLevel {
  DEBUG = 3,
  INFO = 4,
  WARN = 5,
  ERROR = 6
}

/**
 * 日志工具类
 */
export class Logger {
  /**
   * 是否调试模式。默认 false —— release 包里 info/debug 一律不输出，
   * 避免 token、手机号、完整响应体这类敏感内容随日志外泄（hdc hilog 可直接读到）。
   * 本地排查时用 Logger.setDebugMode(true) 临时打开，warn/error 不受此开关影响。
   */
  private static isDebugMode: boolean = false;

  /**
   * 设置调试模式
   */
  static setDebugMode(isDebug: boolean): void {
    Logger.isDebugMode = isDebug;
  }

  /**
   * 调试日志
   */
  static debug(tag: string, message: string, ...args: Object[]): void {
    if (Logger.isDebugMode) {
      hilog.debug(LOG_DOMAIN, tag, `${LOG_PREFIX}: ${message}`, ...args);
    }
  }

  /**
   * 信息日志
   */
  static info(tag: string, message: string, ...args: Object[]): void {
    if (Logger.isDebugMode) {
      hilog.info(LOG_DOMAIN, tag, `${LOG_PREFIX}: ${message}`, ...args);
    }
  }

  /**
   * 警告日志
   */
  static warn(tag: string, message: string, ...args: Object[]): void {
    hilog.warn(LOG_DOMAIN, tag, `${LOG_PREFIX}: ${message}`, ...args);
  }

  /**
   * 错误日志
   */
  static error(tag: string, message: string, ...args: Object[]): void {
    hilog.error(LOG_DOMAIN, tag, `${LOG_PREFIX}: ${message}`, ...args);
  }

  /**
   * 致命错误日志
   */
  static fatal(tag: string, message: string, ...args: Object[]): void {
    hilog.fatal(LOG_DOMAIN, tag, `${LOG_PREFIX}: ${message}`, ...args);
  }
}
