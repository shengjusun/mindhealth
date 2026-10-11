/**
 * 模块级 AbilityStage：在这里开启「应用故障恢复」（appRecovery）。
 *
 * 开了之后，进程被 JS 异常 / 应用冻结 / Native 崩溃杀死时，系统会**自动重启 Ability**，
 * 并把 onSaveState() 保存的数据通过 onCreate 的 want 带回来（launchReason = APP_RECOVERY）。
 * 用户感知：闪退后重新打开，还停在原来的 Tab，而不是被甩回首页。
 *
 * 为什么必须放在 AbilityStage：enableAppRecovery 的官方约定调用点是 AbilityStage.onCreate，
 * 而 UIAbility 的 onCreate 每次实例化都会走，时机不对会重复开启。
 */
import AbilityStage from '@ohos.app.ability.AbilityStage'
import { appRecovery } from '@kit.AbilityKit'
import { Logger } from '../common/utils/Logger'

const TAG = 'MyAbilityStage'

export default class MyAbilityStage extends AbilityStage {
  onCreate(): void {
    // ALWAYS_RESTART：JS 异常 / 应用冻结 / Native 崩溃都自动重启；
    // SAVE_WHEN_ERROR | SAVE_WHEN_BACKGROUND：出错时保存现场 + 退后台时也保存（后台存的是最新现场）；
    // SAVE_WITH_FILE：状态落文件（我们只存几十字节，文件方式最稳，不受共享内存大小限制）。
    appRecovery.enableAppRecovery(
      appRecovery.RestartFlag.ALWAYS_RESTART,
      appRecovery.SaveOccasionFlag.SAVE_WHEN_ERROR | appRecovery.SaveOccasionFlag.SAVE_WHEN_BACKGROUND,
      appRecovery.SaveModeFlag.SAVE_WITH_FILE
    )
    Logger.warn(TAG, '应用故障恢复已开启（异常自动重启 + 现场回传）')
  }
}
