import MySetConstants from '../../../common/constants/MySetConstants'
import { Attribute } from '../../../common/utils/Attribute'
import { SetList, SetGroupList } from '../../../componets/dataList/SetListGroup'
import { SetHead } from '../../../componets/myset/SetHead'
import { SetListView } from '../../../componets/myset/SetListView'
import settingsManager from '../../../common/utils/SettingsManager'
import bookDataPreferences from '../../../common/utils/DataPreferencesUtils'
import { showMessage } from '../../../componets/common/promptShow'
import { webview } from '@kit.ArkWeb'
import fs from '@ohos.file.fs'
import { common } from '@kit.AbilityKit'

@Entry
@Component
struct MySetPage{
  @State private isShowPreDon: boolean = false
  @State private isShowLanguage: boolean = false
  @State private isShowBookSave: boolean = false
  @State private isShowImgCache: boolean = false
  @State private isShowWebPort: boolean = false
  @State private imgCacheSize: string = '0 B'
  @State private bookSavePath: string = ''

  @StorageLink(MySetConstants.SET_REFRESH) setRefresh: boolean = true
  @StorageLink(MySetConstants.SET_JUMP) setJump: boolean = true
  @StorageLink(MySetConstants.SET_REPLACE) setReplace: boolean = true
  @StorageLink(MySetConstants.SET_TIP) setTip: boolean = true
  @StorageLink(MySetConstants.SET_IMG_ANTI) setImgAnti: boolean = true
  @StorageLink(MySetConstants.SET_AWAKEN) setAwaken: boolean = true
  @StorageLink(MySetConstants.SET_HEAD) setHead: boolean = true
  @StorageLink(MySetConstants.SET_SEARCH) setSearch: boolean = true
  @StorageLink(MySetConstants.SET_PRE_DOWNLOAD) select: number = 10
  @StorageLink(MySetConstants.SET_LANGUAGE) selectLanguage: string = '跟随系统'

  private tempNum: number = 10
  private preDow: string = '预先下载'+this.select+'章正文'
  private fruits: string[] = getRandomStringArray()

  @State languageList: string[] = ['跟随系统','简体中文','繁体中文','英文']
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0


  @State bookSetList: SetList[]=[
    new SetList(false,'自动刷新',this.setRefresh,'','打开软件时自动更新书籍',MySetConstants.SET_REFRESH),
    new SetList(false,'自动跳转最近阅读',this.setJump,'','关闭将以底部弹窗形式提示',MySetConstants.SET_JUMP),
    new SetList(false,'默认启用替换净化',this.setReplace,'','新加入书架的书是否启用替换净化',MySetConstants.SET_REPLACE),
    new SetList(false,'返回时提示放入书架',this.setTip,'','',MySetConstants.SET_TIP)
  ]

  @State cacheSetList: SetList[]=[
    new SetList(true,'书籍保存位置',true,'','打开软件时自动更新书籍',MySetConstants.SET_BOOK_SAVE),
    new SetList(true,'预下载',true,this.preDow,'',MySetConstants.SET_PRE_DOWNLOAD),
    new SetList(true,'图片缓存',true,'当前最大缓存50MB','',MySetConstants.SET_IMG_CACHE),
    new SetList(false,'图片抗锯齿',this.setImgAnti,'','',MySetConstants.SET_IMG_ANTI)
  ]

  @State netWorkSetList: SetList[]=[
    new SetList(false,'Webservice唤醒锁',this.setAwaken,'','如遇杀后台可开启',MySetConstants.SET_AWAKEN),
    new SetList(true,'Web端口',true,'','当前端口1122',MySetConstants.SET_WEB_PORT),
    new SetList(true,'清除webview数据',true,'','清除内置浏览器所有数据',MySetConstants.SET_CLEAR_WEB)
  ]

  @State otherSetList: SetList[]=[
    new SetList(false,'全程响应耳机按键',this.setHead,'','即使退出也响应耳机按键',MySetConstants.SET_HEAD),
    new SetList(false,'文字操作显示搜索',this.setSearch,'','长按文字在操作菜单中显示阅读搜索',MySetConstants.SET_SEARCH),
    new SetList(true,'语言',true,'跟随系统','',MySetConstants.SET_LANGUAGE),
  ]

  @State setGroupList: SetGroupList[] = [
    new SetGroupList('书架',this.bookSetList),
    new SetGroupList('缓存下载',this.cacheSetList),
    new SetGroupList('网络',this.netWorkSetList),
    new SetGroupList('其他',this.otherSetList)
  ]

  // 定义分组设置头部
  @Builder itemHead(text: string) {
    // 分组设置头部组件
    Text(text)
      .fontSize(12)
      .fontColor('#8C8C8C')
      .backgroundColor('#F5F5F5')
      .width('100%')
      .padding({left:40,right:40,top:16,bottom:8})
  }


  build() {
    Column(){
      SetHead({titleName:'我的设置'}).height(48).padding({left:20})

      List(){

        ForEach(this.setGroupList,(group:SetGroupList)=>{
          //分组头部
          ListItemGroup({header:this.itemHead(group.groupValue)}){

            if(group.setList){
              ForEach(group.setList,(item:SetList)=>{
                ListItem(){//设置内容，首尾裁剪
                  if (group.setList.indexOf(item) == 0){
                    SetListView({setList:item,topLeft:20,topRight:20})
                      .onClick(()=>{this.itemOnclick(item.storageName)})

                  }else if (group.setList.indexOf(item) == group.setList.length - 1){
                    SetListView({setList:item,bottomLeft:20,bottomRight:20})
                      .onClick(()=>{this.itemOnclick(item.storageName)})
                  }else {
                    SetListView({setList:item})
                      .onClick(()=>{this.itemOnclick(item.storageName)})
                  }
                }.padding({left:20,right:20})
              })
            }

          }
        })

      }.width('100%')
      .height('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .padding({
      top:this.topRectHeight,
      bottom: this.bottomRectHeight,
    })
    .backgroundColor('#F5F5F5')
    .bindSheet($$this.isShowLanguage, this.languageSheet(), {
      height: 288,
      dragBar: false,
      showClose: false,
    })
    // 通过选定的半模态接口，绑定模态展示界面，style中包含两个参数，一个是设置半模态的高度，不设置时默认高度是Large，一个是是否显示控制条DragBar，默认是true显示控制条
    .bindSheet($$this.isShowPreDon, this.preDowSheet(), {
      height: 288,
      dragBar: false,
      showClose: false,
    })
    .bindSheet($$this.isShowBookSave, this.bookSaveSheet(), {
      height: 220,
      dragBar: false,
      showClose: false,
    })
    .bindSheet($$this.isShowImgCache, this.imgCacheSheet(), {
      height: 260,
      dragBar: false,
      showClose: false,
    })
    .bindSheet($$this.isShowWebPort, this.webPortSheet(), {
      height: 220,
      dragBar: false,
      showClose: false,
    })


  }



  // 通过@Builder构建预下载半模态展示界面
  @Builder preDowSheet() {
    Column() {
      Row(){
        // 分组设置头部组件
        Text('取消')
          .fontSize(14)
          .padding({left:20})
          .onClick(()=>{this.isShowPreDon = false})

        Text('预下载')
          .fontSize(16)

        Text('确定')
          .fontSize(14)
          .padding({right:20})
          .onClick(()=>{
            this.isShowPreDon = false
            this.select = this.tempNum
            this.preDow = '预先下载'+this.select+'章正文'
            this.cacheSetList[1].rightText = this.preDow
          })
      }.width('100%').height(56).justifyContent(FlexAlign.SpaceBetween)
      Column() {
        TextPicker({ range: this.fruits, selected: this.select })
          .onChange((value: string | string[], index: number | number[]) => {
            if (typeof index === "number") {
              this.tempNum = index
            }
          })
          .disappearTextStyle({color: Color.Black, font: {size: 14, weight: FontWeight.Normal}})
          .textStyle({color: Color.Black, font: {size: 14, weight: FontWeight.Normal}})
          .selectedTextStyle({color: Color.Red, font: {size: 16, weight: FontWeight.Bolder}})
      }.width('100%').height('100%')
    }
    .width('100%')
    .height(288)
    .backgroundColor(Color.White)
  }

  // 通过@Builder构建半模态展示界面
  @Builder languageSheet() {
    Column() {
      Text('语言')
        .fontSize(16)
        .textAlign(TextAlign.Center)
        .width('100%').height(56)
      ForEach(this.languageList,(value:string)=>{
        Text(value)
          .fontSize(16)
          .textAlign(TextAlign.Start)
          .width('100%').height(56)
          .padding({left:40})
          .onClick(()=>{
            this.selectLanguage = value
            settingsManager.setStr(MySetConstants.SET_LANGUAGE, value)
            this.isShowLanguage = false
            showMessage('语言已切换为' + value)
          })
      })
    }
    .width('100%')
    .height(288)
    .backgroundColor(Color.White)
  }

  // 通过@Builder构建书籍保存位置半模态
  @Builder bookSaveSheet() {
    Column({ space: 12 }) {
      Text('书籍保存位置')
        .fontSize(16)
        .fontWeight(600)
        .width('100%').height(48)
        .textAlign(TextAlign.Center)
      Text('书籍文件保存在应用沙箱目录：')
        .fontSize(13)
        .opacity(0.6)
        .width('100%')
        .padding({left:20,right:20})
      Text(this.bookSavePath)
        .fontSize(12)
        .fontColor('#188BFF')
        .width('100%')
        .padding({left:20,right:20})
        .textOverflow({overflow:TextOverflow.Ellipsis})
        .maxLines(3)
      Text('关闭')
        .fontSize(14)
        .fontColor('#188BFF')
        .width('100%')
        .height(44)
        .textAlign(TextAlign.Center)
        .margin({top:8})
        .onClick(()=>{this.isShowBookSave = false})
    }
    .width('100%')
    .height(220)
    .backgroundColor(Color.White)
  }

  // 通过@Builder构建图片缓存半模态
  @Builder imgCacheSheet() {
    Column({ space: 12 }) {
      Text('图片缓存')
        .fontSize(16)
        .fontWeight(600)
        .width('100%').height(48)
        .textAlign(TextAlign.Center)
      Text('当前缓存大小：' + this.imgCacheSize)
        .fontSize(14)
        .width('100%')
        .textAlign(TextAlign.Center)
      Row({space:20}) {
        Button('清空缓存')
          .backgroundColor('#FF3B30')
          .onClick(()=>{
            this.clearImgCache()
          })
        Button('取消')
          .backgroundColor(Color.Grey)
          .onClick(()=>{
            this.isShowImgCache = false
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({top:12})
    }
    .width('100%')
    .height(260)
    .backgroundColor(Color.White)
  }

  // 通过@Builder构建Web端口说明半模态
  @Builder webPortSheet() {
    Column({ space: 12 }) {
      Text('Web 端口')
        .fontSize(16)
        .fontWeight(600)
        .width('100%').height(48)
        .textAlign(TextAlign.Center)
      Text('当前版本预留端口 1122（Web 服务功能尚未开放）')
        .fontSize(13)
        .opacity(0.6)
        .width('100%')
        .textAlign(TextAlign.Center)
      Text('关闭')
        .fontSize(14)
        .fontColor('#188BFF')
        .width('100%')
        .height(44)
        .textAlign(TextAlign.Center)
        .margin({top:8})
        .onClick(()=>{this.isShowWebPort = false})
    }
    .width('100%')
    .height(220)
    .backgroundColor(Color.White)
  }

  /**
   * 设置列表点击事件
   * @param value
   */
  itemOnclick(value:string){
    switch (value){
      case MySetConstants.SET_REFRESH:
        this.setRefresh = !this.setRefresh
        this.bookSetList[0].toggleStatus = this.setRefresh;
        settingsManager.setBool(MySetConstants.SET_REFRESH, this.setRefresh);
        showMessage(this.setRefresh ? '已开启自动刷新' : '已关闭自动刷新');
        break;
      case MySetConstants.SET_JUMP:
        this.setJump = !this.setJump
        this.bookSetList[1].toggleStatus = this.setJump;
        settingsManager.setBool(MySetConstants.SET_JUMP, this.setJump);
        showMessage(this.setJump ? '已开启自动跳转最近阅读' : '已关闭自动跳转最近阅读');
        break;
      case MySetConstants.SET_REPLACE:
        this.setReplace = !this.setReplace
        this.bookSetList[2].toggleStatus = this.setReplace;
        settingsManager.setBool(MySetConstants.SET_REPLACE, this.setReplace);
        showMessage(this.setReplace ? '已开启默认替换净化' : '已关闭默认替换净化');
        break;
      case MySetConstants.SET_TIP:
        this.setTip = !this.setTip
        this.bookSetList[3].toggleStatus = this.setTip;
        settingsManager.setBool(MySetConstants.SET_TIP, this.setTip);
        showMessage(this.setTip ? '已开启返回提示' : '已关闭返回提示');
        break;
      case MySetConstants.SET_IMG_ANTI:
        this.setImgAnti = !this.setImgAnti
        this.cacheSetList[3].toggleStatus = this.setImgAnti;
        settingsManager.setBool(MySetConstants.SET_IMG_ANTI, this.setImgAnti);
        showMessage(this.setImgAnti ? '已开启图片抗锯齿' : '已关闭图片抗锯齿');
        break;
      case MySetConstants.SET_AWAKEN:
        this.setAwaken = !this.setAwaken
        this.netWorkSetList[0].toggleStatus = this.setAwaken;
        settingsManager.setBool(MySetConstants.SET_AWAKEN, this.setAwaken);
        showMessage(this.setAwaken ? '已开启唤醒锁' : '已关闭唤醒锁');
        break;
      case MySetConstants.SET_HEAD:
        this.setHead = !this.setHead
        this.otherSetList[0].toggleStatus = this.setHead;
        settingsManager.setBool(MySetConstants.SET_HEAD, this.setHead);
        showMessage(this.setHead ? '已开启耳机按键响应' : '已关闭耳机按键响应');
        break;
      case MySetConstants.SET_SEARCH:
        this.setSearch = !this.setSearch
        this.otherSetList[1].toggleStatus = this.setSearch;
        settingsManager.setBool(MySetConstants.SET_SEARCH, this.setSearch);
        showMessage(this.setSearch ? '已开启文字操作搜索' : '已关闭文字操作搜索');
        break;
      case MySetConstants.SET_BOOK_SAVE:
        this.refreshBookSavePath();
        this.isShowBookSave = !this.isShowBookSave;
        break;
      case MySetConstants.SET_PRE_DOWNLOAD:
        this.isShowPreDon = !this.isShowPreDon;
        break;
      case MySetConstants.SET_IMG_CACHE:
        this.refreshImgCacheSize();
        this.isShowImgCache = !this.isShowImgCache;
        break;
      case MySetConstants.SET_WEB_PORT:
        this.isShowWebPort = !this.isShowWebPort;
        break;
      case MySetConstants.SET_CLEAR_WEB:
        this.clearWebViewData();
        break;
      case MySetConstants.SET_LANGUAGE:
        this.isShowLanguage = !this.isShowLanguage;
        break;
    }
  }

  /** 展示书籍保存位置（应用沙箱目录） */
  private refreshBookSavePath(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    this.bookSavePath = ctx.filesDir
  }

  /** 计算缓存目录大小（递归） */
  private calcDirSize(dirPath: string): number {
    let total: number = 0
    try {
      if (!fs.accessSync(dirPath)) {
        return 0
      }
      const names: string[] = fs.listFileSync(dirPath)
      for (let i = 0; i < names.length; i++) {
        const childPath: string = dirPath + '/' + names[i]
        const stat = fs.statSync(childPath)
        if (stat.isDirectory()) {
          total += this.calcDirSize(childPath)
        } else {
          total += stat.size
        }
      }
    } catch (e) {
      console.error('calcDirSize error: ' + JSON.stringify(e))
    }
    return total
  }

  /** 刷新图片缓存大小（系统 cache 目录） */
  private refreshImgCacheSize(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const size: number = this.calcDirSize(ctx.cacheDir)
    if (size < 1024) {
      this.imgCacheSize = size + ' B'
    } else if (size < 1024 * 1024) {
      this.imgCacheSize = (size / 1024).toFixed(1) + ' KB'
    } else {
      this.imgCacheSize = (size / 1024 / 1024).toFixed(1) + ' MB'
    }
  }

  /** 清空图片缓存目录内容（保留目录本身） */
  private clearImgCache(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    try {
      if (!fs.accessSync(ctx.cacheDir)) {
        this.isShowImgCache = false
        showMessage('缓存目录不存在')
        return
      }
      const names: string[] = fs.listFileSync(ctx.cacheDir)
      for (let i = 0; i < names.length; i++) {
        const childPath: string = ctx.cacheDir + '/' + names[i]
        const stat = fs.statSync(childPath)
        if (stat.isDirectory()) {
          this.removeDirRecursively(childPath)
        } else {
          fs.unlinkSync(childPath)
        }
      }
      this.refreshImgCacheSize()
      showMessage('图片缓存已清理')
    } catch (e) {
      console.error('clearImgCache error: ' + JSON.stringify(e))
      showMessage('清理失败')
    }
  }

  private removeDirRecursively(dirPath: string): void {
    try {
      if (!fs.accessSync(dirPath)) {
        return
      }
      const names: string[] = fs.listFileSync(dirPath)
      for (let i = 0; i < names.length; i++) {
        const childPath: string = dirPath + '/' + names[i]
        const stat = fs.statSync(childPath)
        if (stat.isDirectory()) {
          this.removeDirRecursively(childPath)
        } else {
          fs.unlinkSync(childPath)
        }
      }
      fs.rmdirSync(dirPath)
    } catch (e) {
      console.error('removeDirRecursively error: ' + JSON.stringify(e))
    }
  }

  /** 真实清除 WebView 数据（Cookie + 存储） */
  private clearWebViewData(): void {
    try {
      webview.WebCookieManager.clearAllCookies()
        .then(() => {
          webview.WebStorage.deleteAllData()
          showMessage('WebView 数据已清除')
        })
        .catch((err: Error) => {
          console.error('clearAllCookies err: ' + JSON.stringify(err))
          showMessage('清除失败')
        })
    } catch (e) {
      console.error('clearWebViewData error: ' + JSON.stringify(e))
      showMessage('清除失败')
    }
  }

  /** 从持久化设置恢复开关状态 */
  aboutToAppear() {
    // 无损删除历史遗留的"用户代理"持久化字段
    bookDataPreferences.shared.delete('setUserAgent');
    this.setRefresh = settingsManager.getBool(MySetConstants.SET_REFRESH)
    this.setJump = settingsManager.getBool(MySetConstants.SET_JUMP)
    this.setReplace = settingsManager.getBool(MySetConstants.SET_REPLACE)
    this.setTip = settingsManager.getBool(MySetConstants.SET_TIP)
    this.setImgAnti = settingsManager.getBool(MySetConstants.SET_IMG_ANTI)
    this.setAwaken = settingsManager.getBool(MySetConstants.SET_AWAKEN)
    this.setHead = settingsManager.getBool(MySetConstants.SET_HEAD)
    this.setSearch = settingsManager.getBool(MySetConstants.SET_SEARCH)
    this.bookSetList[0].toggleStatus = this.setRefresh
    this.bookSetList[1].toggleStatus = this.setJump
    this.bookSetList[2].toggleStatus = this.setReplace
    this.bookSetList[3].toggleStatus = this.setTip
    this.cacheSetList[3].toggleStatus = this.setImgAnti
    this.netWorkSetList[0].toggleStatus = this.setAwaken
    this.otherSetList[0].toggleStatus = this.setHead
    this.otherSetList[1].toggleStatus = this.setSearch
  }
}

function getRandomStringArray():string[]{
  let list: string[] = []
  for (let i = 0; i < 100; i++) {
    list.push(i.toString())
  }
  return list;
}
