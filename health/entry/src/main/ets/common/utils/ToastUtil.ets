// import promptAction from '@ohos.promptAction';
// import { Logger } from './Logger';
//
// const TAG = 'ToastUtil';
//
// /**
//  * Toast提示工具类
//  */
// export class ToastUtil {
//   /**
//    * 显示短Toast
//    */
//   static showShort(message: string): void {
//     try {
//       promptAction.showToast({
//         message: message,
//         duration: 2000
//       });
//       Logger.info(TAG, `Toast: ${message}`);
//     } catch (error) {
//       const err = error as Error;
//       Logger.error(TAG, `Toast显示失败: ${err.message}`);
//     }
//   }
//
//   /**
//    * 显示长Toast
//    */
//   static showLong(message: string): void {
//     try {
//       promptAction.showToast({
//         message: message,
//         duration: 3500
//       });
//       Logger.info(TAG, `Toast: ${message}`);
//     } catch (error) {
//       const err = error as Error;
//       Logger.error(TAG, `Toast显示失败: ${err.message}`);
//     }
//   }
//
//   /**
//    * 显示成功提示
//    */
//   static showSuccess(message: string): void {
//     this.showShort(`✓ ${message}`);
//   }
//
//   /**
//    * 显示错误提示
//    */
//   static showError(message: string): void {
//     this.showShort(`✗ ${message}`);
//   }
//
//   /**
//    * 显示警告提示
//    */
//   static showWarning(message: string): void {
//     this.showShort(`⚠ ${message}`);
//   }
//
//   /**
//    * 显示信息提示
//    */
//   static showInfo(message: string): void {
//     this.showShort(`ℹ ${message}`);
//   }
//
//   /**
//    * 显示加载提示
//    */
//   static showLoading(message: string = '加载中...'): void {
//     this.showShort(message);
//   }
//
//   /**
//    * 显示操作成功
//    */
//   static showOperationSuccess(): void {
//     this.showSuccess('操作成功');
//   }
//
//   /**
//    * 显示操作失败
//    */
//   static showOperationFailed(): void {
//     this.showError('操作失败');
//   }
//
//   /**
//    * 显示保存成功
//    */
//   static showSaveSuccess(): void {
//     this.showSuccess('保存成功');
//   }
//
//   /**
//    * 显示保存失败
//    */
//   static showSaveFailed(): void {
//     this.showError('保存失败');
//   }
//
//   /**
//    * 显示删除成功
//    */
//   static showDeleteSuccess(): void {
//     this.showSuccess('删除成功');
//   }
//
//   /**
//    * 显示删除失败
//    */
//   static showDeleteFailed(): void {
//     this.showError('删除失败');
//   }
//
//   /**
//    * 显示网络错误
//    */
//   static showNetworkError(): void {
//     this.showError('网络连接失败,请检查网络');
//   }
//
//   /**
//    * 显示登录成功
//    */
//   static showLoginSuccess(): void {
//     this.showSuccess('登录成功');
//   }
//
//   /**
//    * 显示登录失败
//    */
//   static showLoginFailed(): void {
//     this.showError('登录失败');
//   }
//
//   /**
//    * 显示退出成功
//    */
//   static showLogoutSuccess(): void {
//     this.showSuccess('已退出登录');
//   }
//
//   /**
//    * 显示复制成功
//    */
//   static showCopySuccess(): void {
//     this.showSuccess('已复制到剪贴板');
//   }
//
//   /**
//    * 显示分享成功
//    */
//   static showShareSuccess(): void {
//     this.showSuccess('分享成功');
//   }
//
//   /**
//    * 显示功能开发中
//    */
//   static showDeveloping(): void {
//     this.showInfo('功能开发中,敬请期待');
//   }
//
//   /**
//    * 显示输入不能为空
//    */
//   static showInputEmpty(): void {
//     this.showWarning('输入不能为空');
//   }
//
//   /**
//    * 显示手机号格式错误
//    */
//   static showPhoneFormatError(): void {
//     this.showWarning('请输入正确的手机号');
//   }
//
//   /**
//    * 显示密码格式错误
//    */
//   static showPasswordFormatError(): void {
//     this.showWarning('密码至少6位,需包含数字和字母');
//   }
//
//   /**
//    * 显示验证码格式错误
//    */
//   static showVerifyCodeFormatError(): void {
//     this.showWarning('请输入6位数字验证码');
//   }
//
//   /**
//    * 显示两次密码不一致
//    */
//   static showPasswordNotMatch(): void {
//     this.showWarning('两次输入的密码不一致');
//   }
// }
