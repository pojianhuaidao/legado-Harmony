import { dataItem } from 'ets/componets/dataList/dataItem';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct AboutUsPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @State version: string = "V1.0.0.1"
  @State first_list: dataItem[] = [
    new dataItem("更新日志", 0),
  ];
  @State end_list: dataItem[] = [
    new dataItem("用户隐私与协议", 1),
    new dataItem("开源许可", 2),
    new dataItem("免责声明", 3),
    new dataItem("崩溃日志", 4),
  ]

  firstUrl_list(value: number | string) {
    switch (value) {
      case 0:
      // 更新日志
        router.pushUrl({
          url: "pages/view/myCenter/aboutUs/versionLogPage"
        })
        break
    }
  }

  endUrl_list(value: number | string) {
    switch (value) {
      case 0:
      //用户隐私与协议
        router.pushUrl({
          url: "pages/view/myCenter/aboutUs/PrivacyAgreementPage"
        })
        break
      case 1:
      //开源许可
        router.pushUrl({
          url: "pages/view/myCenter/aboutUs/OpenSourceLicensePage"
        })
        break
      case 2:
      //免责声明
        router.pushUrl({
          url: "pages/view/myCenter/aboutUs/DisclaimerPage"
        })
        break
      case 3:
      //崩溃日志
        router.pushUrl({
          url: "pages/view/myCenter/aboutUs/crashLogPage"
        })
        break
    }
  }

  build() {
    Scroll() {
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
            Text(`关于我们`)
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

        this.middleClick(this.first_list, "app.media.right", null, "first")

        this.middleClick(this.end_list, "app.media.right", null, "end")
      }
      .padding({
        left: 20,
        right: 20,
        top: this.topRectHeight,
        bottom: this.bottomRectHeight
      })
      .height("100%")
      .backgroundColor("rgb(245, 245, 245)")
    }
  }

  @Builder
  middleClick(list: Array<dataItem>, image: string, version: string | null, urlList: string) {
    Column() {
      ForEach(list, (item: dataItem, index) => {
        Row() {
          Text(item.title)
            .lineHeight(22)
            .font({
              // family: "PingFang SC",
              size: 16,
              weight: 400,
              style: FontStyle.Normal,
            })
          Blank(20)
          if (version && index === 0) {
            Text(version)
              .lineHeight(20)
              .font({
                // family: "PingFang SC",
                size: 12,
                weight: 400,
                style: FontStyle.Normal,
              })
              .baselineOffset(4)
              .opacity(0.45)
              .margin({
                right: 4
              })
          }
          Image($r(`${image}`)).size({ width: 24, height: 24 })
        }
        .width("100%")
        .height(48)
        .onClick(() => {
          switch (urlList) {
            case 'first':
              this.firstUrl_list(index)
              break
            case 'end':
              this.endUrl_list(index)
              break
          }
        })
      })
    }

    .padding({
      top: 12,
      bottom: 12,
      left: 20,
      right: 20
    })
    .backgroundColor(Color.White)
    .borderRadius(10)
  }
}
