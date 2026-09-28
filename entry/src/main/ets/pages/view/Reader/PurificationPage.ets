import { router } from '@kit.ArkUI'
import fs from '@kit.CoreFileKit'
import { FileHandler } from '../../../common/utils/FileHandler'
import { getPasteDataSync } from '../../../common/utils/utils'
import { showMessage } from '../../../componets/common/promptShow'
import purificationRuleStore, { PurificationRule } from '../../../common/utils/PurificationRuleStore'

@Entry
@Component
struct PurificationPage {
  @State ruleList: PurificationRule[] = []
  @State isShowEdit: boolean = false
  @State editIndex: number = -1
  @State editName: string = ''
  @State editRules: string = ''

  aboutToAppear() {
    this.reload()
  }

  reload() {
    this.ruleList = purificationRuleStore.getAll()
  }

  async pasteImport() {
    const text = getPasteDataSync()
    if (!text) {
      showMessage('未获取到粘贴信息')
      return
    }
    const parsed = purificationRuleStore.parseImport(text)
    if (parsed.length === 0) {
      showMessage('解析失败，请检查粘贴内容是否为净化源JSON')
      return
    }
    const all = purificationRuleStore.getAll()
    parsed.forEach(item => all.push(item))
    purificationRuleStore.saveAll(all)
    this.reload()
    showMessage(`成功导入${parsed.length}条净化规则`)
  }

  async localImport() {
    try {
      const paths: string[] = await FileHandler.documentPickerFile(1, ['.json', '.txt'])
      if (paths.length === 0) {
        return
      }
      const text = await fs.readText(paths[0])
      const parsed = purificationRuleStore.parseImport(text)
      if (parsed.length === 0) {
        showMessage('解析失败，请检查文件内容是否为净化源JSON')
        return
      }
      const all = purificationRuleStore.getAll()
      parsed.forEach(item => all.push(item))
      purificationRuleStore.saveAll(all)
      this.reload()
      showMessage(`成功导入${parsed.length}条净化规则`)
    } catch (e) {
      showMessage('导入失败')
    }
  }

  toggleRule(index: number, value: boolean) {
    if (index < 0 || index >= this.ruleList.length) {
      return
    }
    this.ruleList[index].enabled = value
    purificationRuleStore.saveAll(this.ruleList)
  }

  deleteRule(index: number) {
    if (index < 0 || index >= this.ruleList.length) {
      return
    }
    this.ruleList.splice(index, 1)
    purificationRuleStore.saveAll(this.ruleList)
    this.reload()
  }

  openEdit(index: number) {
    if (index < 0 || index >= this.ruleList.length) {
      return
    }
    this.editIndex = index
    this.editName = this.ruleList[index].name
    this.editRules = JSON.stringify(this.ruleList[index].rules)
    this.isShowEdit = true
  }

  saveEdit() {
    if (this.editIndex < 0 || this.editIndex >= this.ruleList.length) {
      return
    }
    const item = this.ruleList[this.editIndex]
    item.name = this.editName
    try {
      const parsed = JSON.parse(this.editRules)
      if (Array.isArray(parsed)) {
        item.rules = parsed.map((r: Object) => String(r))
      }
    } catch (e) {
      showMessage('规则内容JSON格式不正确')
      return
    }
    purificationRuleStore.saveAll(this.ruleList)
    this.isShowEdit = false
    this.reload()
  }

  @Builder importMenu() {
    Column({ space: 4 }) {
      Column() {
        Row() {
          Text('粘贴导入').fontSize(14).fontColor('#000000')
        }.height(44).width('100%').justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.pasteImport()
        })
        Divider().color('#f0f0f0')
        Row() {
          Text('本地导入').fontSize(14).fontColor('#000000')
        }.height(44).width('100%').justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.localImport()
        })
      }
      .width(120)
      .borderRadius(8)
      .backgroundColor(Color.White)
      .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.12)' })
    }
  }

  @Builder editSheet() {
    Column({ space: 16 }) {
      Text('编辑净化规则').fontSize(16).fontWeight(600)
      TextInput({ placeholder: '规则名称', text: this.editName })
        .onChange((value: string) => {
          this.editName = value
        })
      TextArea({ placeholder: '规则内容JSON数组', text: this.editRules })
        .height(180)
        .onChange((value: string) => {
          this.editRules = value
        })
      Row({ space: 12 }) {
        Button('取消').fontSize(14).layoutWeight(1)
          .onClick(() => {
            this.isShowEdit = false
          })
        Button('保存').fontSize(14).layoutWeight(1)
          .onClick(() => {
            this.saveEdit()
          })
      }
    }
    .padding(20)
  }

  @Builder ruleItem(item: PurificationRule, index: number) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(item.name).fontSize(15).fontWeight(500).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`规则数：${item.rules.length}`).fontSize(12).fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: item.enabled })
        .selectedColor('#F60')
        .onChange((value: boolean) => {
          this.toggleRule(index, value)
        })
      Text('编辑')
        .fontSize(13)
        .fontColor('#F60')
        .onClick(() => {
          this.openEdit(index)
        })
      Text('删除')
        .fontSize(13)
        .fontColor(Color.Red)
        .onClick(() => {
          this.deleteRule(index)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
    .borderRadius(10)
    .margin({ bottom: 10 })
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.return_left'))
          .width(24).height(24)
          .onClick(() => {
            router.back()
          })
        Text('净化管理').fontSize(17).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center)
        Image($r('app.media.icon_rule_export'))
          .width(24).height(24)
          .bindMenu(this.importMenu(), { borderRadius: 12 })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      if (this.ruleList.length === 0) {
        Column({ space: 8 }) {
          Text('暂无净化规则').fontSize(15).fontColor('#999999')
          Text('点击右上角图标，通过粘贴或本地文件导入净化源').fontSize(12).fontColor('#bbbbbb')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 0 }) {
            ForEach(this.ruleList, (item: PurificationRule, index: number) => {
              this.ruleItem(item, index)
            })
          }
          .width('100%')
          .padding(12)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
    .bindSheet($$this.isShowEdit, this.editSheet(), {
      height: 420,
      showClose: false,
      dragBar: true,
      backgroundColor: Color.White,
      onDisappear: () => {
        this.isShowEdit = false
      }
    })
  }
}
