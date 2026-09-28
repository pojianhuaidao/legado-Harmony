import { router } from '@kit.ArkUI';
import { ThemeStorageKey } from '../../../../common/constants/Theme';
import { ThemeItem } from '../../../../common/model/Theme';

@Entry
@Component
struct VersionLogPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @State List: Array<string> = [
    '书源解析端侧化改造：搜索、发现、详情、目录、正文解析由远端服务迁移至本地JS引擎，无远端依赖',
    '发现页支持展示书源内容（书籍列表）',
    '新增阅读时长统计：按天记录阅读时间，我的页展示今日阅读分钟数',
    '读过、读完、书签列表改为持久化数据，支持删除与全选批量删除',
    '新增书源管理入口：书源列表、启用/停用、编辑、删除、导入、分组',
    '新增净化管理：净化规则列表、导入净化源（粘贴/本地文件）、启用/停用、编辑、删除',
    '关于我们精简：移除检查更新、开发人员、官网、公众号、QQ频道、QQ群',
    '移除文件管理入口',
    '支持CI流水线自动出包',
  ]
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem

  build() {
    Column({ space: 16 }) {
      Flex() {
        Column() {
          Image($r("app.media.return_left"))
            .size({ width: 24, height: 24 })
            .interpolation(ImageInterpolation.Medium)
            .onClick(() => {
              router.back()
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('33%')

        Column() {
          Text(`版本更新日志`)
            .lineHeight(24)
            .font({
              family: "PingFang SC",
              size: 16,
              weight: 500,
              style: FontStyle.Normal,
            })
        }.width('33%')
      }
      .padding({
        top: 12,
        bottom: 12,
      })
      .height(48)
      .width("100%")

      this.versionCard("V1.0.0.2", "2026/9/28", this.List)
      //this.versionCard("V5.1.1", "2024/5/9", this.List)
    }
    .height("100%")
    .padding({
      top:this.topRectHeight,
      left:20,
      right:20
    })
    .backgroundColor("rgb(245, 245, 245)")
  }

  @Builder
  versionCard(version: string, date: string, updateInfo: Array<string>) {
    Column() {
      Row() {
        Line({ width: 4, height: 16 })
          .backgroundColor(this.theme.mainColor)
          .margin({ right: 8 })
        Text(version)
          .lineHeight(24)
          .fontColor("#000000")
          .font({
            family: "PingFang SC",
            size: 16,
            weight: 500,
            style:FontStyle.Normal,
          })
        Blank(20)
        Text(date)
          .fontColor("#000000")
          .opacity(0.45)
          .lineHeight(20)
          .font({
            family: "PingFang SC",
            size:12,
            weight:400,
            style:FontStyle.Normal
          })
      }
      .margin({ bottom: 12 })
      .width("100%")

      ForEach(updateInfo, (item: string) => {
        Row() {
          // todo:这里有个点
          Text(item).lineHeight(20)
            .font({
              family: "PingFang SC",
              size:12,
              weight:400,
              style:FontStyle.Normal
            })
        }
        .width("100%")
      })
    }
    .borderRadius(12)
    .backgroundColor("#FFFFFF")
    .padding(16)
    .width("100%")
  }
}