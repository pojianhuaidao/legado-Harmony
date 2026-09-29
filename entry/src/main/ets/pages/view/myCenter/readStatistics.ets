import { ColumnModifier } from '../../../common/utils/ComponetModifier';
import { router } from '@kit.ArkUI';
import CommonConstants from '../../../common/constants/CommonConstants';
import { dataItem } from '../../../componets/dataList/dataItem';
import { readStatisticsDataList } from '../../../componets/myCenter/readStatisticsDataList';
import { readBookList } from '../../../componets/dataList/readBookList';
import { readTabs } from '../../../componets/myCenter/readTabs';
import { serviceDialog } from '../../../componets/webDavService/serviceDialog';
import { PublicConstants } from '../../../common/constants/PublicConstants';
import bookHistoryDao from '../../../database/dao/BookHistoryDao';
import { BookHistory } from '../../../database/entities/BookHistory';
import booksDao from '../../../database/dao/BooksDao';
import { Books } from '../../../database/entities/Books';
import DbUtil from '../../../common/utils/DbUtil';
import AppDatabaseUtil from '../../../database/AppDatabaseUtil';
import { ColumnInfo } from '../../../database/types/ColumnInfo';

// 书签表行结构（bookmarks 表：time INTEGER 主键）
interface BookmarkRow {
  time: number
  bookName: string
  bookAuthor: string
  chapterIndex: number
  chapterPos: number
  chapterName: string
  bookText: string
  content: string
}


@Entry
@Component
struct readStatistics {

  Column = new ColumnModifier()
  @State type:number|string=(router.getParams() as dataItem).value
  @State read_list:dataItem[]=[
    new dataItem("小说",0),
    new dataItem("漫画",0),
    new dataItem("有声书",0),
  ]
  @State title_list:dataItem[]=[
    new dataItem("读过",0),
    new dataItem("读完",0),
    new dataItem("书签",0),
  ]
  @State read_index:number=0
  @State translateNum:number=0
  @State translateX:number=120
  @State dateValue:number[]=[0,0]
  @Provide delStatus:boolean=false

  @State delDialog:boolean=false
  @State bookList:readBookList[]=[]

  async loadBookList() {
    // 基于真实数据源统计：读过=book_history，读完=books 进度，书签=bookmarks 表
    const now = new Date()
    const mapped: readBookList[] = []
    try {
      if (this.type === 0) {
        // 读过：全部阅读历史（search 默认按 durChapterTime 倒序）
        const list = await bookHistoryDao.search({})
        list.forEach((item: BookHistory) => {
          const dur = Math.max(0, item.durChapterTime)
          const coverUrl: string = item.coverUrl ?? ''
          mapped.push(new readBookList(
            item.bookName,
            coverUrl !== '' ? coverUrl : $r("app.media.book_cover"),
            item.author,
            [Math.floor(dur / 3600000), Math.floor((dur % 3600000) / 60000)],
            new Date(dur),
            0,
            0,
            0,
            false,
            item.id !== undefined ? item.id : 0
          ))
        })
        // 最近活跃年份（列表已按最近阅读时间倒序，取第一条）
        const activeYear = list.length > 0 && list[0].durChapterTime > 0
          ? new Date(list[0].durChapterTime).getFullYear()
          : now.getFullYear()
        this.dateValue = list.length > 0 ? [activeYear, list.length] : [0, 0]
      } else if (this.type === 1) {
        // 读完：书架中已读完的书籍（总章节数>0 且当前章节>=总章节-1）
        const shelf = await booksDao.search({}) as Books[]
        shelf.forEach((b: Books) => {
          const total = b.totalChapterNum ?? 0
          const current = b.durChapterIndex ?? 0
          if (total > 0 && current >= total - 1) {
            const dur = Math.max(0, b.durChapterTime ?? 0)
            const coverUrl: string = b.coverUrl ?? ''
            mapped.push(new readBookList(
              b.bookName,
              coverUrl !== '' ? coverUrl : $r("app.media.book_cover"),
              b.author,
              [Math.floor(dur / 3600000), Math.floor((dur % 3600000) / 60000)],
              new Date(dur),
              100,
              0,
              0,
              false,
              b.id !== undefined ? b.id : 0
            ))
          }
        })
        this.dateValue = mapped.length > 0 ? [now.getFullYear(), mapped.length] : [0, 0]
      } else {
        // 书签：bookmarks 表按书籍去重，取每本书最新书签
        const seen: string[] = []
        const rows = await this.loadBookmarks()
        rows.forEach((row: BookmarkRow) => {
          if (seen.indexOf(row.bookName) >= 0) {
            return
          }
          seen.push(row.bookName)
          mapped.push(new readBookList(
            row.bookName,
            $r("app.media.book_cover"),
            row.bookAuthor,
            [0, 0],
            new Date(row.time),
            0,
            0,
            0,
            false,
            0
          ))
        })
        this.dateValue = mapped.length > 0 ? [now.getFullYear(), mapped.length] : [0, 0]
      }
    } catch (e) {
      this.dateValue = [0, 0]
    }
    this.bookList = mapped
    // 顶部统计（真实）：读过/读完/书签
    const historyAll = await this.countHistory()
    const finishedAll = await this.countFinished()
    const bookmarkAll = await this.countBookmarks()
    this.title_list = [
      new dataItem("读过", historyAll),
      new dataItem("读完", finishedAll),
      new dataItem("书签", bookmarkAll),
    ]
    // tab 条：按书籍类型统计阅读历史（小说0/漫画1/有声2）
    const novelCount = await this.countByType(0)
    const comicCount = await this.countByType(1)
    const audioCount = await this.countByType(2)
    this.read_list = [
      new dataItem("小说", novelCount),
      new dataItem("漫画", comicCount),
      new dataItem("有声书", audioCount),
    ]
  }

  async loadBookmarks(): Promise<BookmarkRow[]> {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn('bookmarks')
      const rows = await DbUtil.querySqlForList<BookmarkRow>(`SELECT * FROM bookmarks ORDER BY time DESC`, column)
      return rows
    } catch (e) {
      return []
    }
  }

  async countHistory(): Promise<number> {
    try {
      return (await bookHistoryDao.search({})).length
    } catch (e) {
      return 0
    }
  }

  async countFinished(): Promise<number> {
    try {
      const shelf = await booksDao.search({}) as Books[]
      let count = 0
      shelf.forEach((b: Books) => {
        const total = b.totalChapterNum ?? 0
        const current = b.durChapterIndex ?? 0
        if (total > 0 && current >= total - 1) {
          count++
        }
      })
      return count
    } catch (e) {
      return 0
    }
  }

  async countBookmarks(): Promise<number> {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn('bookmarks')
      const predicates = DbUtil.getPredicates('bookmarks')
      return await DbUtil.queryForCount(predicates, column)
    } catch (e) {
      return 0
    }
  }

  async countByType(t: number): Promise<number> {
    try {
      return (await bookHistoryDao.search({ type: t })).length
    } catch (e) {
      return 0
    }
  }

  @Builder head(){
    Row(){
      Row(){
        Image($r("app.media.return_left"))
          .size({width:CommonConstants.TITLE_IMG_SIZE,height:CommonConstants.TITLE_IMG_SIZE})
          .onClick(()=>{
            router.back()
          })
      }.width("33%")
      Row(){
        Text(this.title_list[this.type].title).fontSize(16).fontWeight(600).lineHeight(24)
      }.width("33%")
      .justifyContent(FlexAlign.Center)
      Row({space:12}){
        if(this.delStatus){
          Text("全选")
            .fontSize(14)
            .fontWeight(500)
            .lineHeight(22)
            .fontColor("rgba(0, 0, 0, 0.45)")
            .onClick(()=>{
              this.bookList.forEach(item=>{item.status=true})
            })
        }
        Text(this.delStatus?"完成":"管理")
          .fontSize(14)
          .fontWeight(500)
          .lineHeight(22)
          .fontColor("rgba(0, 0, 0, 0.45)")
          .onClick(()=>{
            this.delStatus=!this.delStatus
          })
      }.width("33%").justifyContent(FlexAlign.End)
    }.width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({top:12,bottom:12})
  }

  @Builder delBottom(){
      Button({ type: ButtonType.Normal, stateEffect: true }){
        Row(){
          Text("删除").fontColor(Color.Red)
        }.height("100%")
      }.backgroundColor(PublicConstants.THEME_COLOR_WHITE)
      .width("100%")
      .height(50)
      .borderColor("rgba(0, 0, 0, 0.06)")
      .borderWidth({
        top:1
      })
      .visibility(this.delStatus?Visibility.Visible:Visibility.None)
      .transition(
        TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.animation({ duration: 500 }).combine(
            TransitionEffect.translate({ y: 50 }).animation({  duration: 500 }))
          ,
          TransitionEffect.OPACITY.animation({ duration: 500 }).combine(
            TransitionEffect.translate({ y: 0}).animation({ duration: 500 }))
        )
      )
    .onClick(()=>{
      this.deleteList()
    })
  }
  build() {
    Column(){
      Column(){
        this.head()
        readTabs({
          read_list:this.read_list
        })
        //tab条 小说漫画有声书切换
        //书籍组件
        readStatisticsDataList({
          dateValue:this.dateValue,
          bookList:this.bookList
        })
      }.attributeModifier(this.Column)
      .height(CommonConstants.FULL_HEIGHT)
      .width(CommonConstants.FULL_WIDTH)
    }.overlay( this.delBottom(), {
      align: Alignment.Bottom,
      offset: { x: 0, y: 0 }
    })

  }

  //删除列表
  deleteList(){
    this.clearInfoDel?.open()
  }
  onCancel(){

  }
  async onAccept(){
    const selected = this.bookList.filter(item=>item.status==true)
    for (let i = 0; i < selected.length; i++) {
      const item = selected[i]
      if (item.id > 0) {
        await bookHistoryDao.deleteBookHistory(item.id)
      }
    }
    this.delStatus=!this.delStatus
    await this.loadBookList()
  }
  exitApp() {
    this.delDialog = false
  }
  clearInfoDel: CustomDialogController | null = new CustomDialogController({
    builder: serviceDialog({
      title:"确认删除吗？",
      value:"",
      cancel: ()=> { this.onCancel() },
      confirm: ()=> { this.onAccept() }
    }),
    cancel: this.exitApp,
    autoCancel: true,
    alignment: DialogAlignment.Center,
    offset:{dx:0,dy:20},
    customStyle: true
  })
  aboutToAppear(): void {
      console.log(this.type+"------")
      this.loadBookList()
  }

}
