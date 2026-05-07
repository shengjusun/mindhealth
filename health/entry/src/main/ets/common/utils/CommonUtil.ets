/**
 * 通用工具类
 */
export class CommonUtil {
  /**
   * 格式化日期
   */
  static formatDate(date: Date | string): string {
    const d = typeof date === 'string' ? new Date(date) : date;
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    
    // 小于1分钟
    if (diff < 60000) {
      return '刚刚';
    }
    
    // 小于1小时
    if (diff < 3600000) {
      return `${Math.floor(diff / 60000)}分钟前`;
    }
    
    // 小于1天
    if (diff < 86400000) {
      return `${Math.floor(diff / 3600000)}小时前`;
    }
    
    // 小于7天
    if (diff < 604800000) {
      return `${Math.floor(diff / 86400000)}天前`;
    }
    
    // 其他
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /**
   * 格式化时间
   */
  static formatTime(date: Date | string): string {
    const d = typeof date === 'string' ? new Date(date) : date;
    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');
    return `${hours}:${minutes}`;
  }

  /**
   * 格式化日期时间
   */
  static formatDateTime(date: Date | string): string {
    const d = typeof date === 'string' ? new Date(date) : date;
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  }

  /**
   * 验证手机号
   */
  static validatePhone(phone: string): boolean {
    const reg = /^1[3-9]\d{9}$/;
    return reg.test(phone);
  }

  /**
   * 验证密码
   */
  static validatePassword(password: string): boolean {
    // 至少6位,包含数字和字母
    const reg = /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{6,}$/;
    return reg.test(password);
  }

  /**
   * 验证验证码
   */
  static validateVerifyCode(code: string): boolean {
    const reg = /^\d{6}$/;
    return reg.test(code);
  }

  /**
   * 验证昵称
   */
  static validateNickname(name: string): boolean {
    return name.length >= 2 && name.length <= 20;
  }

  /**
   * 验证年龄
   */
  static validateAge(age: number): boolean {
    return age >= 1 && age <= 150;
  }

  /**
   * 验证内容长度
   */
  static validateContent(content: string, min: number, max: number): boolean {
    const length = content.trim().length;
    return length >= min && length <= max;
  }

  /**
   * 生成唯一ID
   */
  static generateId(): string {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 8);
    return `${timestamp}${random}`;
  }

  /**
   * 防抖函数
   */
  static debounce(func: (...args: Object[]) => void, wait: number): (...args: Object[]) => void {
    let timeout: number | null = null;
    return (...args: Object[]) => {
      if (timeout) {
        clearTimeout(timeout);
      }
      timeout = setTimeout(() => {
        func(...args);
      }, wait);
    };
  }

  /**
   * 节流函数
   */
  static throttle(func: (...args: Object[]) => void, wait: number): (...args: Object[]) => void {
    let lastTime: number = 0;
    return (...args: Object[]) => {
      const now = Date.now();
      if (now - lastTime >= wait) {
        func(...args);
        lastTime = now;
      }
    };
  }

  /**
   * 深拷贝
   */
  static deepClone<T>(obj: T): T {
    if (obj === null || obj === undefined) {
      return obj;
    }

    return JSON.parse(JSON.stringify(obj)) as T;
  }

  /**
   * 获取心情图标
   */
  static getMoodIcon(mood: string): string {
    const moodMap: Record<string, string> = {
      '开心': '😊',
      '平静': '😌',
      '焦虑': '😰',
      '难过': '😢',
      '愤怒': '😤',
      '兴奋': '🤩',
      '疲惫': '😴',
      '困惑': '😕'
    };
    return moodMap[mood] || '😊';
  }

  /**
   * 获取心情颜色
   */
  static getMoodColor(mood: string): string {
    const colorMap: Record<string, string> = {
      '开心': '#D1FAE5',
      '平静': '#E0F2FE',
      '焦虑': '#FEE2E2',
      '难过': '#DBEAFE',
      '愤怒': '#FED7AA',
      '兴奋': '#FDE68A',
      '疲惫': '#E5E7EB',
      '困惑': '#F3E8FF'
    };
    return colorMap[mood] || '#E0F2FE';
  }

  /**
   * 获取测评结果文本
   */
  static getAssessmentResult(type: string, score: number): string {
    if (type === 'phq9') {
      if (score <= 4) return '无抑郁症状';
      if (score <= 9) return '轻度抑郁';
      if (score <= 14) return '中度抑郁';
      if (score <= 19) return '中重度抑郁';
      return '重度抑郁';
    }
    
    if (type === 'gad7') {
      if (score <= 4) return '无焦虑症状';
      if (score <= 9) return '轻度焦虑';
      if (score <= 14) return '中度焦虑';
      return '重度焦虑';
    }
    
    return '未知';
  }

  /**
   * 获取测评建议
   */
  static getAssessmentSuggestion(type: string, score: number): string {
    if (type === 'phq9') {
      if (score <= 4) {
        return '保持良好的生活习惯,关注心理健康。';
      }
      if (score <= 9) {
        return '建议寻求专业心理咨询,与AI助手聊聊你的感受。';
      }
      if (score <= 14) {
        return '强烈建议寻求专业心理帮助,可以拨打心理援助热线。';
      }
      if (score <= 19) {
        return '请尽快寻求专业心理医生帮助,我们随时陪伴您。';
      }
      return '请立即寻求专业帮助,拨打心理援助热线: 400-161-9995';
    }
    
    if (type === 'gad7') {
      if (score <= 4) {
        return '保持放松心态,适当运动和休息。';
      }
      if (score <= 9) {
        return '尝试放松训练,如深呼吸、冥想等。';
      }
      if (score <= 14) {
        return '建议寻求专业帮助,学习焦虑管理技巧。';
      }
      return '请尽快寻求专业帮助,焦虑是可以治疗的。';
    }
    
    return '如有需要,请寻求专业帮助。';
  }

  /**
   * 截断文本
   */
  static truncateText(text: string, maxLength: number): string {
    if (text.length <= maxLength) {
      return text;
    }
    return text.substring(0, maxLength) + '...';
  }

  /**
   * 判断是否为空
   */
  static isEmpty(value: string | Object | null | undefined): boolean {
    if (value === null || value === undefined) {
      return true;
    }
    if (typeof value === 'string') {
      return value.trim() === '';
    }
    if (Array.isArray(value)) {
      return value.length === 0;
    }
    if (typeof value === 'object' && value !== null) {
      return Object.getOwnPropertyNames(value).length === 0;
    }
    return false;
  }

  /**
   * 延迟执行
   */
  static delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
