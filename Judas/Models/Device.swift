import Foundation

// 修改现有的Device结构体，添加openPorts属性
struct Device: Identifiable, Hashable {
    let id = UUID()
    let ipAddress: String
    var openPorts: [Int] = []
    var isOnline: Bool {
           return true // 默认都是在线的，因为扫描时只会找到在线设备
       }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ipAddress)
    }
}
