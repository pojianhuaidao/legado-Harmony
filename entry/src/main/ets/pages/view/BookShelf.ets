import ReadShow from '../../componets/common/ReadShow'
import IndexShelf from './bookShelf/IndexShelf'
import { DARK_BG, LIGHT_BG } from '../../../common/utils/ThemeModeManager'

@Component
export default struct BookShelf {
  @StorageProp('isdark') isDark: boolean = false
  @State bookShelf: string = '书架'
  build(){
    Column(){
      IndexShelf()
    }
    .backgroundColor(this.isDark ? DARK_BG : 'rgba(255, 255, 255, 0.8)')
  }
}