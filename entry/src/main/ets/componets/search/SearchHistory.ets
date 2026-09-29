
import { SearchHistoryUtil } from '../../common/utils/SearchHistoryUtil'
import { promptAction } from '@kit.ArkUI'

@Component
export struct SearchHistory{

  @State historyBookNames: string[] = []
  @State rankingList: string[] = ["小说热搜榜", "漫画热搜榜", "听书热搜榜"]
  @State rotateImages: number= 0;
  @State rotateState: boolean=false;
  scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.loadHistory()
  }

  loadHistory(): void {
    this.historyBookNames = SearchHistoryUtil.getHistory()
  }

  clearHistory(): void {
    SearchHistoryUtil.clearHistory()
    this.historyBookNames = []
    promptAction.showToast({
      message: '搜索历史已清空',
      duration: 1500
    })
  }

  build() {
    Column() {
      //搜索历史
      Row({ space: 90 }) {
        Text("搜索历史").width("40%").height(40).fontWeight(600).fontSize(20);
        Row({ space: 10 }) {
          Row() {
            Text(this.rotateState?"收起":"展开").fontColor($r("app.color.search_launch"))
            Image("/common/images/search_launch.svg").width(24).height(24).fillColor($r("app.color.search_launch"))
              .onClick((event: ClickEvent) => {
                if(this.rotateState==true){
                  this.rotateImages=0;
                  this.rotateState=false;
                }else{
                  this.rotateImages=180;
                  this.rotateState=true;
                }
              })
              .animation({
                duration: 1000,
                tempo:2
              })
              .rotate({angle: this.rotateImages})
          }

          Image("/common/images/search_del.svg").width(24).height(24).fillColor($r("app.color.search_launch"))
            .onClick(() => {
              if (this.historyBookNames.length > 0) {
                this.clearHistory()
              } else {
                promptAction.showToast({
                  message: '暂无搜索历史',
                  duration: 1500
                })
              }
            })
        }
      }.width("100%").padding({ top:10 });

      //历史记录
      if (this.historyBookNames.length === 0) {
        Column() {
          Text("暂无搜索历史")
            .fontSize(13)
            .fontColor('#73000000')
            .margin({ top: 20, bottom: 20 })
        }.width("100%")
      } else {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
          ForEach(this.historyBookNames, (item: String, index) => {
            Text(item.toString())
              .padding({ top: 5, left: 15, right: 15})
              .backgroundColor($r("app.color.search_history"))
              .margin({ right: 10, bottom: 10 })
              .fontSize(13)
          })
        }.width("100%").height(this.rotateState?180:100)
        .padding({ top: 10 ,bottom:10 }).clip(true);
      }

      //排行榜
      // Scroll(this.scroller) {
      //   Row({ space: 20 }) {
      //     ForEach(this.rankingList, (item) => {
      //       //排行榜内容组件
      //       Ranking()
      //     })
      //   }.width("50%").height("80%").alignItems(VerticalAlign.Top).margin({ top: 20 })
      // }
      // .scrollable(ScrollDirection.Horizontal)
      // .width(1700)
    }.padding({
      left:20,
      right:20
    })
  }
}