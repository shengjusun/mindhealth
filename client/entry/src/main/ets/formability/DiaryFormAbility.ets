/**
 * 快捷入口卡片的生命周期载体（Form Kit）。
 *
 * 这张卡片是「纯静态交互」：四个入口点击后通过 postCardAction(router) 拉起主应用，
 * 不需要向卡片下发动态数据，所以 onAddForm 返回空绑定数据即可，
 * form_config 里也不开 updateEnabled —— 不开动态刷新就不占系统的刷新配额。
 */
import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility'
import formBindingData from '@ohos.app.form.formBindingData'
import { Want } from '@kit.AbilityKit'

export default class DiaryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData({})
  }
}
