


export class readBookList{
  //记录id（对应book_history.id，用于持久化删除）
  id:number
  //书名
  bookName:string
  //封面
  coverImage:ResourceStr
  //作者
  author:string
  //阅读时长
  readingDuration:number[]
  //当前时间
  dateTime:Date
  //进度
  schedule:number
  //书签
  bookmark:number
  //读完次数
  readFrequency:number
  //选中
  status:boolean

  constructor(bookName: string, coverImage: ResourceStr, author: string, readingDuration: number[], dateTime: Date,
    schedule: number, bookmark: number,readFrequency:number=0, status: boolean=false, id: number=0) {
    this.bookName = bookName
    this.coverImage = coverImage
    this.author = author
    this.readingDuration = readingDuration
    this.dateTime = dateTime
    this.schedule = schedule
    this.bookmark = bookmark
    this.readFrequency=readFrequency
    this.status = status
    this.id = id
  }


}