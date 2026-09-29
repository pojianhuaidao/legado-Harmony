import IndexSubscription from './Subscription/IndexSubscription'
import SubscriptionIndex from './Subscription/SubscriptionIndex'
import { DARK_BG, LIGHT_BG } from '../../../common/utils/ThemeModeManager'

@Component
export default struct Subscription {
  @StorageProp('isdark') isDark: boolean = false
  @State subscription: string = '订阅源'
  @Prop currentTabIndex: number
  build(){
    Column(){
      SubscriptionIndex({
        currentTabIndex:this.currentTabIndex,
      })
    }
    .backgroundColor('F3F4F8')
  }
}