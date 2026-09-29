import { promptAction, router } from '@kit.ArkUI';
import { ColumnModifier } from '../../../common/utils/ComponetModifier';
import { ThemeItem } from '../../../common/model/Theme';
import { ThemeStorageKey } from '../../../common/constants/Theme';
import webdavClient, { WebdavConfig } from '../../../common/utils/WebdavClient';
import bookDataPreferences from '../../../common/utils/DataPreferencesUtils';
import { BusinessError } from '@ohos.base';

@Entry
@Component
struct WebDav {
  @State host: string = ''
  @State account: string = ''
  @State password: string = ''
  @State isLogining: boolean = false
  @State inputs: Input_items[] = [
    new Input_items('', '服务器地址', InputType.Normal),
    new Input_items('', '账号', InputType.Email),
    new Input_items('', '密码', InputType.Password)
  ]
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  @State helper_status: boolean = false
  Column = new ColumnModifier().setPadding(0, 0)

  @Builder input_type(item: Input_items) {
    Column() {
      TextInput({ text: item.text, placeholder: item.placeholder })
        .placeholderColor(Color.Grey)
        .type(item.type)
        .caretColor(Color.Blue)
        .height(50)
        .fontSize(14)
        .fontColor(Color.Black)
        .borderRadius(10)
        .padding({ left: 20 })
        .onChange((value: string) => {
          item.text = value
          if (item.placeholder === '服务器地址') {
            this.host = value
          } else if (item.placeholder === '账号') {
            this.account = value
          } else if (item.placeholder === '密码') {
            this.password = value
          }
        })
    }
  }

  /** 读取已保存的 WebDAV 凭据 */
  private loadSavedConfig(): boolean {
    const savedHost = bookDataPreferences.get('webdav_host')
    const savedAccount = bookDataPreferences.get('webdav_account')
    const savedPassword = bookDataPreferences.get('webdav_password')
    if (savedHost && savedAccount && savedPassword) {
      this.host = String(savedHost)
      this.account = String(savedAccount)
      this.password = String(savedPassword)
      return true
    }
    return false
  }

  /** 保存 WebDAV 凭据（会话保持） */
  private saveConfig(): void {
    bookDataPreferences.set('webdav_host', this.host)
    bookDataPreferences.set('webdav_account', this.account)
    bookDataPreferences.set('webdav_password', this.password)
  }

  /** 进入文件列表页 */
  private goFileList(): void {
    router.pushUrl({
      url: 'pages/view/cloud/WebDavFileList'
    })
  }

  /** 授权并登录 */
  private async doLogin(): Promise<void> {
    if (this.isLogining) {
      return
    }
    if (this.host.length === 0 || this.account.length === 0 || this.password.length === 0) {
      promptAction.showToast({
        message: '请填写完整的服务器地址、账号和密码',
        duration: 2000
      })
      return
    }
    this.isLogining = true
    promptAction.showToast({
      message: '正在验证 WebDAV 连接...',
      duration: 1000
    })
    const config: WebdavConfig = new WebdavConfig(this.host, this.account, this.password)
    try {
      const ok: boolean = await webdavClient.verifyLogin(config)
      if (ok) {
        this.saveConfig()
        promptAction.showToast({
          message: '登录成功',
          duration: 1500
        })
        setTimeout(() => {
          this.isLogining = false
          this.goFileList()
        }, 600)
      } else {
        this.isLogining = false
        promptAction.showToast({
          message: '登录失败，请检查地址或账号密码',
          duration: 2500
        })
      }
    } catch (err) {
      this.isLogining = false
      const e = err as BusinessError
      console.error('WebDAV login error: ', JSON.stringify(e))
      promptAction.showToast({
        message: '连接失败，请检查网络或服务器地址',
        duration: 2500
      })
    }
  }

  aboutToAppear() {
    // 已保存凭据则直接进入文件管理（会话保持）
    if (this.loadSavedConfig()) {
      setTimeout(() => {
        this.goFileList()
      }, 300)
    }
  }

  build() {
    Column() {
      Column() {
        Column({ space: 30 }) {
          Text('WebDav云盘登录')
            .fontSize(30)
            .fontWeight(700)
          Column({ space: 30 }) {
            ForEach(this.inputs, (item: Input_items) => {
              this.input_type(item)
            })
          }.width('80%')
          Button(this.isLogining ? '登录中...' : '授权并登录')
            .width('80%').height(50)
            .backgroundColor(this.theme.mainColor)
            .borderRadius(10)
            .enabled(!this.isLogining)
            .onClick(() => {
              this.doLogin()
            })
        }
        .width('100%').height('95%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      Text('不会填写？查看帮助')
        .fontColor(this.theme.mainColor)
        .fontSize(14)
        .onClick(() => {
          this.helper_status = true
        })
        .width('100%').height(20)
    }
    .justifyContent(FlexAlign.Start)
    .attributeModifier(this.Column)
  }
}

class Input_items {
  text: string
  placeholder: string
  type: InputType

  constructor(text: string, placeholder: string, type: InputType) {
    this.text = text
    this.placeholder = placeholder
    this.type = type
  }
}
