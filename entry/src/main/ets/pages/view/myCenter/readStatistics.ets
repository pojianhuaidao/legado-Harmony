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


@Entry
@Component
struct readStatistics {

  Column = new ColumnModifier()
  @State type:number|string=(router.getParams() as dataItem).value
  @State read_list:dataItem[]=[
    new dataItem("小说",12),
    new dataItem("漫画",12),
    new dataItem("有声书",12),
  ]
  @State title_list:dataItem[]=[
    new dataItem("读过",12),
    new dataItem("读完",12),
    new dataItem("书签",12),
  ]
  @State read_index:number=0
  @State translateNum:number=0
  @State translateX:number=120
  @State dateValue:number[]=[2023,36]
  @Provide delStatus:boolean=false

  @State delDialog:boolean=false
  @State bookList:readBookList[]=[]

  async loadBookList() {
    // 加载全部阅读历史（读过/读完/书签共用真实历史数据，删除后持久化，不再出现测试假数据）
    const list = await bookHistoryDao.search({})
    const mapped: readBookList[] = []
    list.forEach((item: BookHistory) => {
      const dur = Math.max(0, item.durChapterTime)
      mapped.push(new readBookList(
        item.bookName,
        item.coverUrl !== '' ? item.coverUrl : $r("app.media.book_cover"),
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
    this.bookList = mapped
    const now = new Date()
    this.dateValue = [now.getFullYear(), mapped.length]
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