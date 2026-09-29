/**
 * @author 2008
 * @datetime 2024/7/14 21:54
 * @className: BookFind
 * 发现公用书籍展示组件
 */
import { isNetworkUrl } from '../../../../common/utils/utils'
import noFind from '../../../../componets/common/noFind'
import { ExploreRule } from '../../../../database/entities/rule'
import { ExploreItem } from '../../../../database/types/BookSourceType'
import exploreParser from '../../../../common/model/exploreParser/ExploreParser'
import mayAlsoLike from '../mayAlsoLike'
import { CardItem } from './CardItem'
import { router } from '@kit.ArkUI'
import { ThemeItem } from '../../../../common/model/Theme'
import { ThemeStorageKey } from '../../../../common/constants/Theme'

@Component
export default struct BookFindContent {
  @Prop currentIndex: number
  @Prop bookSourceUrl: string
  @Prop exploreItem: ExploreItem
  @Prop @Watch('getList') counter: number = 0
  @State loading: boolean = true
  @State errorExplore: boolean = false
  @State bookList: ExploreRule[] = []
  @Prop exploreRule: ExploreRule = {}
  @Prop jsLib: string = ''
  handleClick: () => void = () => {
  }
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem

  aboutToAppear() {
    this.getList()
  }

  getList() {
    this.loading = true
    let url = this.exploreItem.url.replace('{{page}}', "1")
    if (!isNetworkUrl(url)) {
      url = this.bookSourceUrl + url
    }
    exploreParser.parse(this.bookSourceUrl, url, this.exploreRule, this.jsLib).then((bookList: ExploreRule[]) => {
      this.bookList = bookList
      this.loading = false
      this.errorExplore = false
    }).catch((err: Error) => {
      console.log('TagInfo 请求失败：', JSON.stringify(err.message));
      this.loading = false
      this.errorExplore = true
    })
  }

  build() {
    Column({
      space: 16
    }) {
      Column() {
        mayAlsoLike({
          mayAlsoLike: this.exploreItem.title,
          handleClick: this.handleClick
        })
        if (this.loading) {
          Column() {
            LoadingProgress()
              .color(this.theme.mainColor)
              .width('50%')
            Text('内容加载中...')
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        } else if (this.errorExplore) {
          noFind({
            onclick: () => {
              this.getList()
            }
          })
        } else if (this.bookList.length === 0) {
          noFind({
            hintIndex: 0
          })
        } else {
          Column() {
            ForEach(this.bookList, (item: ExploreRule, index) => {
              CardItem({ item: item ,currentIndex:this.currentIndex})
            })
            if (this.bookList.length === 3) {
              Column() {
                Text('查看更多')
                  .lineHeight(20)
                  .fontColor('#73000000')
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .margin({ top: 20 })
              .backgroundColor('#0F000000')
              .borderRadius(4)
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/view/Find/CategoryList/Index',
                  params: {
                    bookSourceUrl: this.bookSourceUrl,
                    exploreItem: this.exploreItem,
                    exploreRule: this.exploreRule,
                    jsLib: this.jsLib,
                    currentIndex: this.currentIndex
                  }
                })
              })
            }
          }
          .height('100%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
        }
      }
      .padding({
        left: 16,
        right: 16,
        top: 20,
        bottom: 20
      })
      .borderRadius(12)
      .backgroundColor(Color.White)
      .height(436)
    }
    .margin({ top: 12 })
  }
}