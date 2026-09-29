import faultLogger from '@ohos.faultLogger'
import dayjs from 'dayjs'
import { router } from '@kit.ArkUI';
import { ThemeStorageKey } from '../../../../common/constants/Theme';
import { ThemeItem } from '../../../../common/model/Theme';

interface CrashLogItem {
  timeText: string
  typeText: string
  module: string
  reason: string
  summary: string
  stack: string
  expanded: boolean
}

@Entry
@Component
struct CrashLogPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @State crashList: CrashLogItem[] = []
  @State loading: boolean = true
  @State errorText: string = ''
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem

  aboutToAppear() {
    this.queryFaultLog()
  }

  async queryFaultLog() {
    this.loading = true
    this.errorText = ''
    try {
      const logs = await faultLogger.querySelfFaultLog(faultLogger.FaultType.NO_SPECIFIC)
      const list: CrashLogItem[] = []
      for (const log of logs) {
        const typeText: string = this.faultTypeText(log.type)
        const timeText: string = dayjs(log.time ?? Date.now()).format('YYYY-MM-DD HH:mm:ss')
        list.push({
          timeText: timeText,
          typeText: typeText,
          module: log.module,
          reason: log.reason,
          summary: log.summary,
          stack: log.stack ?? '',
          expanded: false
        })
      }
      this.crashList = list
      if (!this.crashList.length) {
        this.errorText = '暂无崩溃日志'
      }
    } catch (err) {
      console.error('TagInfo, 查询崩溃日志失败, ' + JSON.stringify(err))
      this.errorText = '查询崩溃日志失败'
    }
    this.loading = false
  }

  faultTypeText(type: number): string {
    switch (type) {
      case faultLogger.FaultType.JS_CRASH:
        return 'JS崩溃'
      case faultLogger.FaultType.CPP_CRASH:
        return 'C++崩溃'
      case faultLogger.FaultType.APP_FREEZE:
        return '应用无响应'
      default:
        return '其他'
    }
  }

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
          Text(`崩溃日志`)
            .lineHeight(24)
            .font({
              family: "PingFang SC",
              size: 16,
              weight: 500,
              style: FontStyle.Normal,
            })
        }.width('33%')

        Column() {
          Text('刷新')
            .fontSize(14)
            .fontColor(this.theme.mainColor)
            .onClick(() => {
              this.queryFaultLog()
            })
        }
        .alignItems(HorizontalAlign.End)
        .width('33%')
      }
      .padding({
        top: 12,
        bottom: 12,
      })
      .height(48)
      .width("100%")

      if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress()
            .color(this.theme.mainColor)
            .width(48)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#66000000')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      } else if (this.errorText && !this.crashList.length) {
        Column({ space: 8 }) {
          Text(this.errorText)
            .fontSize(14)
            .fontColor('#66000000')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 12 }) {
          ForEach(this.crashList, (item: CrashLogItem, index: number) => {
            ListItem() {
              this.crashCard(item, index)
            }
          })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .width('100%')
      }
    }
    .height("100%")
    .padding({
      top: this.topRectHeight,
      left: 20,
      right: 20,
      bottom: this.bottomRectHeight
    })
    .backgroundColor("rgb(245, 245, 245)")
  }

  @Builder
  crashCard(item: CrashLogItem, index: number) {
    Column() {
      Row() {
        Text(item.timeText)
          .lineHeight(20)
          .fontColor("#000000")
          .font({
            family: "PingFang SC",
            size: 14,
            weight: 500,
            style: FontStyle.Normal,
          })
        Blank()
        Text(item.typeText)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(this.theme.mainColor)
          .borderRadius(4)
          .padding({
            left: 8,
            right: 8,
            top: 2,
            bottom: 2
          })
      }
      .width("100%")
      .margin({ bottom: 8 })

      if (item.reason) {
        Text(`原因：${item.reason}`)
          .lineHeight(20)
          .fontSize(13)
          .fontColor("#000000")
          .opacity(0.75)
          .width("100%")
          .textOverflow({
            overflow: TextOverflow.Ellipsis
          })
          .maxLines(item.expanded ? 99 : 2)
      }

      if (item.module) {
        Text(`模块：${item.module}`)
          .lineHeight(20)
          .fontSize(13)
          .fontColor("#000000")
          .opacity(0.75)
          .width("100%")
          .textOverflow({
            overflow: TextOverflow.Ellipsis
          })
          .maxLines(item.expanded ? 99 : 2)
      }

      if (item.summary) {
        Text(`摘要：${item.summary}`)
          .lineHeight(20)
          .fontSize(13)
          .fontColor("#000000")
          .opacity(0.75)
          .width("100%")
          .textOverflow({
            overflow: TextOverflow.Ellipsis
          })
          .maxLines(item.expanded ? 99 : 2)
      }

      if (item.stack) {
        Text(item.stack)
          .lineHeight(18)
          .fontSize(12)
          .fontColor("#66000000")
          .width("100%")
          .textOverflow({
            overflow: TextOverflow.Ellipsis
          })
          .maxLines(item.expanded ? 99 : 4)
          .margin({ top: 4 })
      }
    }
    .borderRadius(12)
    .backgroundColor("#FFFFFF")
    .padding(16)
    .width("100%")
    .onClick(() => {
      const updated: CrashLogItem = this.crashList[index]
      updated.expanded = !updated.expanded
      this.crashList[index] = updated
    })
  }
}
