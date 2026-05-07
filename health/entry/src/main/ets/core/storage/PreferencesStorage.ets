/**
 * Preferences键值存储封装
 * @description 基于鸿蒙Preferences的键值存储
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../../common/utils/Logger';
import { StorageConfig } from '../../common/constants/AppConstants';

const TAG = 'PreferencesStorage';

/**
 * Preferences存储类
 */
export class PreferencesStorage {
  private static instance: PreferencesStorage;
  private preferences: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): PreferencesStorage {
    if (!PreferencesStorage.instance) {
      PreferencesStorage.instance = new PreferencesStorage();
    }
    return PreferencesStorage.instance;
  }

  /**
   * 初始化Preferences
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.context = context;
      this.preferences = await preferences.getPreferences(context, StorageConfig.PREFERENCES_NAME);
      Logger.info(TAG, 'Preferences初始化成功');
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Preferences初始化失败: ${err.message}`);
      throw new Error(`Preferences初始化失败: ${err.message}`);
    }
  }

  /**
   * 存储数据
   */
  async put(key: string, value: string | number | boolean | Array<string | number | boolean>): Promise<void> {
    if (!this.preferences) {
      throw new Error('Preferences未初始化');
    }

    try {
      if (typeof value === 'string') {
        await this.preferences.put(key, value);
      } else if (typeof value === 'number') {
        await this.preferences.put(key, value);
      } else if (typeof value === 'boolean') {
        await this.preferences.put(key, value);
      } else if (Array.isArray(value)) {
        await this.preferences.put(key, value);
      }
      await this.preferences.flush();
      Logger.debug(TAG, `存储数据: ${key}`);
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `存储数据失败: ${err.message}`);
      throw new Error(`存储数据失败: ${err.message}`);
    }
  }

  /**
   * 获取数据
   */
  async get(key: string, defaultValue?: string | number | boolean | Array<string | number | boolean>): Promise<string | number | boolean | Array<string | number | boolean> | null> {
    if (!this.preferences) {
      throw new Error('Preferences未初始化');
    }

    try {
      const value = await this.preferences.get(key, defaultValue ?? '');
      Logger.debug(TAG, `获取数据: ${key}`);
      return value as string | number | boolean | Array<string | number | boolean>;
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `获取数据失败: ${err.message}`);
      return null;
    }
  }

  /**
   * 删除数据
   */
  async delete(key: string): Promise<void> {
    if (!this.preferences) {
      throw new Error('Preferences未初始化');
    }

    try {
      await this.preferences.delete(key);
      await this.preferences.flush();
      Logger.debug(TAG, `删除数据: ${key}`);
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `删除数据失败: ${err.message}`);
      throw new Error(`删除数据失败: ${err.message}`);
    }
  }

  /**
   * 清空所有数据
   */
  async clear(): Promise<void> {
    if (!this.preferences) {
      throw new Error('Preferences未初始化');
    }

    try {
      await this.preferences.clear();
      await this.preferences.flush();
      Logger.info(TAG, '清空所有数据');
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `清空数据失败: ${err.message}`);
      throw new Error(`清空数据失败: ${err.message}`);
    }
  }

  /**
   * 检查键是否存在
   */
  async has(key: string): Promise<boolean> {
    if (!this.preferences) {
      throw new Error('Preferences未初始化');
    }

    try {
      return await this.preferences.has(key);
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `检查键存在失败: ${err.message}`);
      return false;
    }
  }
}
