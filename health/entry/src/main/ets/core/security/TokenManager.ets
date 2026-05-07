/**
 * Token管理器
 * @description 管理用户Token的存储、获取和刷新
 */

import { Logger } from '../../common/utils/Logger';
import { SecurityConfig } from '../../common/constants/AppConstants';
import { PreferencesStorage } from '../storage/PreferencesStorage';
import { TokenInfo } from '../../common/types/Types';

const TAG = 'TokenManager';

/**
 * Token管理器类
 */
export class TokenManager {
  private static instance: TokenManager;
  private tokenInfo: TokenInfo | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): TokenManager {
    if (!TokenManager.instance) {
      TokenManager.instance = new TokenManager();
    }
    return TokenManager.instance;
  }

  /**
   * 保存Token信息
   */
  async saveToken(tokenInfo: TokenInfo): Promise<void> {
    try {
      const storage = PreferencesStorage.getInstance();
      await storage.put(SecurityConfig.TOKEN_KEY, tokenInfo.accessToken);
      await storage.put(SecurityConfig.REFRESH_TOKEN_KEY, tokenInfo.refreshToken);
      
      this.tokenInfo = tokenInfo;
      Logger.info(TAG, 'Token保存成功');
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Token保存失败: ${err.message}`);
      throw new Error(`Token保存失败: ${err.message}`);
    }
  }

  /**
   * 获取访问Token
   */
  async getAccessToken(): Promise<string | null> {
    try {
      if (this.tokenInfo?.accessToken) {
        return this.tokenInfo.accessToken;
      }

      const storage = PreferencesStorage.getInstance();
      const token = await storage.get(SecurityConfig.TOKEN_KEY) as string;
      return token || null;
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `获取Token失败: ${err.message}`);
      return null;
    }
  }

  /**
   * 获取刷新Token
   */
  async getRefreshToken(): Promise<string | null> {
    try {
      if (this.tokenInfo?.refreshToken) {
        return this.tokenInfo.refreshToken;
      }

      const storage = PreferencesStorage.getInstance();
      const token = await storage.get(SecurityConfig.REFRESH_TOKEN_KEY) as string;
      return token || null;
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `获取RefreshToken失败: ${err.message}`);
      return null;
    }
  }

  /**
   * 清除Token
   */
  async clearToken(): Promise<void> {
    try {
      const storage = PreferencesStorage.getInstance();
      await storage.delete(SecurityConfig.TOKEN_KEY);
      await storage.delete(SecurityConfig.REFRESH_TOKEN_KEY);
      
      this.tokenInfo = null;
      Logger.info(TAG, 'Token清除成功');
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Token清除失败: ${err.message}`);
      throw new Error(`Token清除失败: ${err.message}`);
    }
  }

  /**
   * 检查Token是否有效
   */
  async isTokenValid(): Promise<boolean> {
    const token = await this.getAccessToken();
    return token !== null && token.length > 0;
  }
}
