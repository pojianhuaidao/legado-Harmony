import { promptAction, router } from '@kit.ArkUI';
import { ThemeItem } from '../../../common/model/Theme';
import { ThemeStorageKey } from '../../../common/constants/Theme';
import webdavClient, { WebdavConfig, WebdavItem } from '../../../common/utils/WebdavClient';
import bookDataPreferences from '../../../common/utils/DataPreferencesUtils';
import fs from '@ohos.file.fs';
import { Books } from '../../../database/entities/Books';
import booksUtil from '../../../common/utils/booksUtils';
import { BusinessError } from '@ohos.base';

@Entry
@Component
struct WebDavFileList {
  @State fileList: WebdavItem[] = []
  @State isLoading: boolean = true
  @State loadError: string = ''
  @State currentPath: string = 'legado'
  @State importingName: string = ''
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  private config: WebdavConfig = new WebdavConfig()
  private filesDir: string = ''
  private bookTypes: string[] = ['txt', 'epub', 'pdf']

  aboutToAppear() {
    this.filesDir = getContext(this).filesDir
    const host = bookDataPreferences.get('webdav_host')
    const account = bookDataPreferences.get('webdav_account')
    const password = bookDataPreferences.get('webdav_password')
    if (host && account && password) {
      this.config = new WebdavConfig(String(host), String(account), String(password))
      this.loadDir('legado')
    } else {
      this.loadError = '未找到登录信息，请先登录'
      this.isLoading = false
    }
  }

  /** 加载指定目录，自动定位 legado 文件夹 */
  private async loadDir(path: string): Promise<void> {
    this.isLoading = true
    this.loadError = ''
    try {
      const items: WebdavItem[] = await webdavClient.listDir(this.config, path)
      // 自动进入 legado 文件夹：若请求根目录且存在 legado 子目录，则进入
      if (path.length === 0) {
        for (let i = 0; i < items.length; i++) {
          if (items[i].isDir && items[i].name === 'legado') {
            this.currentPath = 'legado'
            const inner: WebdavItem[] = await webdavClient.listDir(this.config, 'legado')
            this.fileList = this.filterBooks(inner)
            this.isLoading = false
            return
          }
        }
        this.loadError = '未找到 legado 文件夹'
        this.fileList = []
        this.isLoading = false
        return
      }
      this.fileList = this.filterBooks(items)
      this.isLoading = false
    } catch (err) {
      const e = err as BusinessError
      console.error('WebDAV loadDir error: ', JSON.stringify(e))
      this.loadError = '加载失败，请检查网络或服务器'
      this.isLoading = false
    }
  }

  /** 过滤书籍文件（txt/epub/pdf） */
  private filterBooks(items: WebdavItem[]): WebdavItem[] {
    const result: WebdavItem[] = []
    for (let i = 0; i < items.length; i++) {
      const item: WebdavItem = items[i]
      if (item.isDir) {
        result.push(item)
        continue
      }
      const lowerName: string = item.name.toLowerCase()
      for (let j = 0; j < this.bookTypes.length; j++) {
        if (lowerName.endsWith(`.${this.bookTypes[j]}`)) {
          result.push(item)
          break
        }
      }
    }
    return result
  }

  /** 下载并导入书架 */
  private async importBook(item: WebdavItem): Promise<void> {
    if (this.importingName.length > 0) {
      return
    }
    this.importingName = item.name
    try {
      const savePath: string = `${this.filesDir}/${item.name}`
      // 已存在则跳过下载（避免重复导入）
      const exists: boolean = await booksUtil.isExistBooks(savePath, item.name)
      if (exists) {
        promptAction.showToast({ message: '该书籍已在书架中', duration: 2000 })
        this.importingName = ''
        return
      }
      const ok: boolean = await webdavClient.downloadFile(this.config, item.href, savePath)
      if (!ok) {
        promptAction.showToast({ message: '下载失败', duration: 2000 })
        this.importingName = ''
        return
      }
      const book: Books = {
        bookName: item.name,
        bookUrl: savePath,
        author: '暂无',
        bookGroup: 3,
        latestChapterTime: 0,
        totalChapterNum: 0,
        durChapterIndex: 0,
        durChapterPos: 0,
        durChapterTime: 0,
        canUpdate: false,
        sort: 0,
        originOrder: 0,
        syncTime: 0,
        bookType: 0,
        isTop: false,
        isJoin: true,
        isLocalBook: true
      }
      await booksUtil.addBooks(book)
      promptAction.showToast({ message: '已导入书架', duration: 2000 })
    } catch (err) {
      const e = err as BusinessError
      console.error('WebDAV import error: ', JSON.stringify(e))
      promptAction.showToast({ message: '导入失败', duration: 2000 })
    }
    this.importingName = ''
  }

  @Builder
  FileItemView(item: WebdavItem) {
    Row({ space: 12 }) {
      if (item.isDir) {
        Image($r('app.media.my_center_file_icon'))
          .width(36)
          .height(36)
      } else {
        Text(this.getExt(item.name))
          .fontSize(10)
          .fontWeight(700)
          .fontColor('#188BFF')
          .backgroundColor('#D8ECFF')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
      }
      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(14)
          .fontWeight(500)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.isDir ? '文件夹' : this.formatSize(item.size))
          .fontSize(11)
          .opacity(0.45)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (!item.isDir) {
        Text(this.importingName === item.name ? '导入中...' : '导入')
          .fontSize(13)
          .fontWeight(600)
          .fontColor(this.theme.mainColor)
      }
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 16, right: 16 })
    .onClick(() => {
      if (item.isDir) {
        this.currentPath = item.name
        this.loadDir(item.href)
      } else {
        this.importBook(item)
      }
    })
  }

  private getExt(name: string): string {
    const idx: number = name.lastIndexOf('.')
    if (idx >= 0) {
      return name.substring(idx + 1).toUpperCase()
    }
    return 'FILE'
  }

  private formatSize(size: number): string {
    if (size < 1024) {
      return `${size} B`
    }
    if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`
    }
    return `${(size / 1024 / 1024).toFixed(1)} MB`
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Image($r('app.media.return_left'))
          .width(24)
          .onClick(() => {
            if (this.currentPath !== 'legado' && this.currentPath.length > 0) {
              this.currentPath = 'legado'
              this.loadDir('legado')
            } else {
              router.back()
            }
          })
        Text('WebDAV 云盘')
          .fontSize(17)
          .fontWeight(600)
        Blank()
        Text(`当前: ${this.currentPath}`)
          .fontSize(12)
          .opacity(0.5)
      }
      .width('100%')
      .padding({ top: 16, bottom: 8, left: 16, right: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(this.theme.mainColor)
          Text('正在连接 WebDAV...')
            .fontSize(14)
            .margin({ top: 12 })
            .opacity(0.5)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadError.length > 0) {
        Column() {
          Text('加载失败')
            .fontSize(16)
            .fontWeight(600)
          Text(this.loadError)
            .fontSize(13)
            .opacity(0.5)
            .margin({ top: 8 })
          Button('重试')
            .margin({ top: 16 })
            .backgroundColor(this.theme.mainColor)
            .onClick(() => {
              this.loadDir(this.currentPath.length > 0 ? this.currentPath : 'legado')
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.fileList.length === 0) {
        Column() {
          Text('该目录暂无 txt/epub/pdf 书籍')
            .fontSize(14)
            .opacity(0.45)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.fileList, (item: WebdavItem) => {
            ListItem() {
              this.FileItemView(item)
            }
            .borderRadius(10)
            .backgroundColor(0xffffffff)
            .margin({ left: 16, right: 16, top: 6, bottom: 6 })
          })
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F2')
  }
}
