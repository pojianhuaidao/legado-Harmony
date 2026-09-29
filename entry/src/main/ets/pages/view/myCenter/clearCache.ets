import { PublicConstants } from '../../../common/constants/PublicConstants'
import { ColumnModifier } from '../../../common/utils/ComponetModifier'
import { dataItem } from '../../../componets/dataList/dataItem'
import { MyCenterTitle } from '../../../componets/myCenter/MyCenterTitle'
import { serviceDialog } from '../../../componets/webDavService/serviceDialog'
import fs from '@ohos.file.fs'
import { common } from '@kit.AbilityKit'
import dbUtil from '../../../common/utils/DbUtil'
import { showMessage } from '../../../componets/common/promptShow'

// 递归清空目录下所有内容（保留目录本身）
function deleteDirContent(dirPath: string): void {
  try {
    if (!fs.accessSync(dirPath)) {
      return
    }
    const names: string[] = fs.listFileSync(dirPath)
    for (let i = 0; i < names.length; i++) {
      const childPath: string = dirPath + '/' + names[i]
      const stat = fs.statSync(childPath)
      if (stat.isDirectory()) {
        deleteDirContent(childPath)
        fs.rmdirSync(childPath)
      } else {
        fs.unlinkSync(childPath)
      }
    }
  } catch (e) {
    console.error('clearCache deleteDirContent error: ' + JSON.stringify(e))
  }
}

@Entry
@Component
struct clearCache{
  @State clearList:dataItem[]=[
    new dataItem("系统缓存",34.35),
    new dataItem("小说缓存",34.35),
    new dataItem("漫画缓存",34.35),
    new dataItem("听书缓存",34.35),
    new dataItem("字体缓存",34.35),
  ]
  @State @Watch("ClearChange") clearDialogStatus:boolean=false
  @State index:number=0
  Column = new ColumnModifier().setCustom({left:20,right:20})
  build() {
    Column({space:12}){
      //标题栏
      MyCenterTitle({title:"清理缓存"})
      Column(){
        ForEach(this.clearList,(item:dataItem,index:number)=>{
          Row({space:10}){
            Text(item.title).width("65%").fontSize(14).lineHeight(22)
            Text(item.value+"MB").fontSize(12).lineHeight(20).fontColor("rgba(0, 0, 0, 0.45)")
            Image($r("app.media.right"))
              .size({width:24,height:24})
              .clickEffect({level:ClickEffectLevel.LIGHT, scale: 0.5})
          }.width("100%").padding({top:12,bottom:12})
          .justifyContent(FlexAlign.End)
          .onClick(()=>{
            this.index=index
            this.clearDialogStatus=true
          })

        })
      }
      .backgroundColor(PublicConstants.THEME_COLOR_WHITE)
      .padding({ left:20,right:20 })
      .borderRadius(15)

    }.width("100%")
    .height("100%")
    .attributeModifier(this.Column)
  }


  //弹窗关闭
  exitApp() {
    this.clearDialogStatus = false
  }
  onCancel() {
    this.clearDialogStatus = false
  }

  onAccept(index:number) {
    console.log(index.toString());
    this.clear(index)
    this.clearDialogStatus = false
  }
  ClearChange(){
    if (this.clearDialogStatus) {
      this.clearInfoDel?.open()
    }
  }
  clearInfoDel: CustomDialogController | null = new CustomDialogController({
    builder: serviceDialog({
      title:"确认清除"+this.clearList[this.index].title+"吗？",
      value:"",
      cancel: ()=> { this.onCancel() },
      confirm: ()=> { this.onAccept(this.index) }
    }),
    cancel: this.exitApp,
    autoCancel: true,
    alignment: DialogAlignment.Center,
    offset:{dx:0,dy:20},
    customStyle: true
  })
  //清除方法
  clear(index:number){
    const context = getContext(this) as common.UIAbilityContext
    switch (index){
      case 0:
      //系统缓存：清空沙箱 cache 目录（含 WebView 等缓存）
        deleteDirContent(context.cacheDir)
        break;
      case 1:
      //小说缓存：清空通用 KV 缓存表（caches），不影响书架/章节等用户数据
        dbUtil.delete(dbUtil.getPredicates('caches')).then(() => {
          console.info("clearCache: caches 表已清空")
        }).catch((err: Error) => {
          console.error("清除小说缓存失败：" + JSON.stringify(err))
        })
        break;
      case 2:
      //漫画缓存：当前版本无独立落盘实现
        break;
      case 3:
      //听书缓存：当前版本无独立落盘实现
        break;
      case 4:
      //字体缓存：当前版本无独立落盘实现
        break;
    }
    this.clearList[index].value = 0
    showMessage(this.clearList[index].title + '已清理')
  }
}