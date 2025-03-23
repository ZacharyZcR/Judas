import Foundation
import Network
import SystemConfiguration

class NetworkScanner: ObservableObject {
    // MARK: - 公共属性
    @Published var discoveredDevices: [String] = []
    @Published var currentIPAddress: String = "未知"
    @Published var currentSubnet: String = "未知"
    @Published var isNetworkConnected: Bool = false
    @Published var scanningErrorMessage: String? = nil
    @Published var isScanningInProgress: Bool = false
    @Published var customSubnet: String = ""
    
    // MARK: - 枚举和常量
    enum ScanType {
        case localSubnet
        case customSubnet
    }
    
    // MARK: - 添加全局超时相关属性
    @Published var globalTimeoutSeconds: Int = 60 // 默认1分钟超时
    @Published var isGlobalTimeoutEnabled: Bool = true // 是否启用全局超时
    private var globalTimeoutWorkItem: DispatchWorkItem?
    
    var scanType: ScanType = .localSubnet
    
    // 扩展常用端口列表
    private let commonPorts: [UInt16] = [80, 443, 22, 21, 8080, 8443, 3389, 5900, 7000, 9000, 554]
    
    // 内部属性
    private let scanQueue = DispatchQueue(label: "com.judas.NetworkScanner", qos: .utility)
    private var scanCancelled = false
    private var currentScanTask: DispatchWorkItem?
    
    // 活动连接追踪
    private var activeConnections = [NWConnection]()
    private let connectionsLock = NSLock()
    
    // 扫描时间间隔和并发控制
    private let scanInterval: TimeInterval = 0.05  // 每个IP扫描间隔50毫秒
    private let maxConcurrentScans = 2  // 最大并发扫描数量
    
    // MARK: - 初始化
    init() {
        getCurrentIPAddress()
    }
    
    // MARK: - 公共方法
    
    /// 获取当前设备的IP地址和子网信息
    func getCurrentIPAddress() {
        print("获取当前IP地址信息...")
        var address: String = "未知"
        var subnet: String = "未知"
        var connected = false
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        // 获取网络接口信息
        if getifaddrs(&ifaddr) == 0 {
            defer { freeifaddrs(ifaddr) } // 确保总是释放内存
            
            var ptr = ifaddr
            
            // 遍历所有网络接口
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee,
                      let addr = interface.ifa_addr else { continue }
                
                // 只处理IPv4地址
                let addrFamily = addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    
                    let name = String(cString: interface.ifa_name)
                    
                    // 只关注WiFi或蜂窝数据接口
                    if name == "en0" || name == "en1" || name == "pdp_ip0" {
                        
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        
                        address = String(cString: hostname)
                        print("发现接口: \(name), IP地址: \(address)")
                        
                        // 验证是否为有效的内网IP
                        if isPrivateIP(address) {
                            connected = true
                            
                            // 获取子网掩码
                            if let netmask = interface.ifa_netmask {
                                var netmaskHostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                getnameinfo(netmask, socklen_t(netmask.pointee.sa_len),
                                           &netmaskHostname, socklen_t(netmaskHostname.count),
                                           nil, socklen_t(0), NI_NUMERICHOST)
                                
                                let netmaskString = String(cString: netmaskHostname)
                                subnet = extractSubnetPrefix(ipAddress: address, subnetMask: netmaskString)
                                print("找到有效内网接口: \(name), IP: \(address), 子网掩码: \(netmaskString), 子网前缀: \(subnet)")
                            }
                            break
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentIPAddress = address
            self.currentSubnet = subnet
            self.isNetworkConnected = connected
            
            if !connected {
                self.scanningErrorMessage = "请连接到WiFi或热点后再试"
                print("未连接到有效网络")
            } else {
                self.scanningErrorMessage = nil
                print("成功获取IP地址: \(address), 子网: \(subnet)")
            }
        }
    }
    
    /// 开始扫描网络
    func startScan() {
        print("NetworkScanner.startScan 被调用")
        
        // 先确保主线程更新 UI 状态
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanningInProgress = true
            // 显式发送变更通知
            self.objectWillChange.send()
        }
        
        // 停止之前可能正在进行的扫描
        if currentScanTask != nil {
            print("检测到正在进行的扫描，先停止它")
            stopScan()
            // 添加短暂延迟确保资源正确释放
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("延迟0.5秒后开始新扫描")
                self?.initiateNewScan()
            }
        } else {
            initiateNewScan()
        }
    }
    
    /// 停止当前扫描
    func stopScan() {
        print("停止扫描...")
        scanCancelled = true
        currentScanTask?.cancel()
        currentScanTask = nil
        
        // 取消全局超时任务
        globalTimeoutWorkItem?.cancel()
        globalTimeoutWorkItem = nil
        
        // 取消所有活动连接
        cancelAllConnections()
        
        // 立即在主线程更新 UI 状态
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanningInProgress = false
            // 显式发送变更通知
            self.objectWillChange.send()
        }
    }

    
    // 取消所有活动连接
    private func cancelAllConnections() {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        
        print("取消 \(activeConnections.count) 个活动连接")
        for connection in activeConnections {
            connection.cancel()
        }
        activeConnections.removeAll()
    }
    
    /// 验证自定义子网格式
    func validateCustomSubnet() -> Bool {
        print("验证自定义子网: \(customSubnet)")
        // 检查是否为空
        if customSubnet.isEmpty {
            scanningErrorMessage = "请输入子网地址"
            print("子网为空")
            return false
        }
        
        // 验证格式 - 仅支持单IP和C类网络
        let singleIPPattern = "^(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})$"
        let cClassPattern = "^(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.$"
        
        let patterns = [singleIPPattern, cClassPattern]
        var isValidFormat = false
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: customSubnet, range: NSRange(location: 0, length: customSubnet.utf16.count)) != nil {
                isValidFormat = true
                break
            }
        }
        
        if !isValidFormat {
            scanningErrorMessage = "子网格式无效，请使用以下格式之一:\n- 单个IP: 192.168.1.1\n- C类网络: 192.168.1."
            print("子网格式无效")
            return false
        }
        
        // 检查IP段是否有效
        let components = customSubnet.components(separatedBy: ".")
        for (index, component) in components.enumerated() {
            if !component.isEmpty {
                if let value = Int(component) {
                    if value > 255 {
                        scanningErrorMessage = "IP地址段数值不能超过255"
                        print("IP段数值超过255")
                        return false
                    }
                    
                    // 对于单IP格式，检查最后一段是否为0或255
                    if components.count == 4 && index == 3 && (value == 0 || value == 255) {
                        scanningErrorMessage = "IP地址最后一段不应为0或255（保留地址）"
                        print("IP最后一段为保留地址")
                        return false
                    }
                }
            }
        }
        
        scanningErrorMessage = nil
        print("子网格式有效")
        return true
    }
    
    // 更新全局超时时间
    func updateGlobalTimeout(seconds: Int) {
        globalTimeoutSeconds = max(10, min(seconds, 300)) // 限制在10秒到5分钟之间
    }

    // 切换全局超时启用状态
    func toggleGlobalTimeout() {
        isGlobalTimeoutEnabled.toggle()
    }
    
    // MARK: - 私有方法
    
    /// 启动新的扫描过程
    private func initiateNewScan() {
        print("开始新的扫描过程")
        
        // 启动全局超时计时器
        startGlobalTimeoutTimer()
        
        // 重置状态
        scanningErrorMessage = nil
        discoveredDevices.removeAll()
        scanCancelled = false
        cancelAllConnections()
        
        // 确保扫描状态为正在进行
        DispatchQueue.main.async { [weak self] in
            self?.isScanningInProgress = true
        }
        
        // 根据扫描类型选择子网
        var subnetToScan: String
        
        switch scanType {
        case .localSubnet:
            // 验证网络连接状态
            print("使用本地子网模式")
            getCurrentIPAddress()
            
            guard isNetworkConnected else {
                DispatchQueue.main.async { [weak self] in
                    self?.scanningErrorMessage = "请连接到WiFi或热点后再试"
                    self?.isScanningInProgress = false
                }
                print("网络未连接，扫描终止")
                return
            }
            
            guard currentSubnet != "未知" else {
                DispatchQueue.main.async { [weak self] in
                    self?.scanningErrorMessage = "无法获取子网信息，请检查网络连接"
                    self?.isScanningInProgress = false
                }
                print("无法获取子网信息，扫描终止")
                return
            }
            
            subnetToScan = currentSubnet
            
        case .customSubnet:
            print("使用自定义子网模式")
            guard validateCustomSubnet() else {
                DispatchQueue.main.async { [weak self] in
                    self?.isScanningInProgress = false
                }
                print("自定义子网验证失败，扫描终止")
                return
            }
            
            subnetToScan = customSubnet
        }
        
        print("开始扫描子网: \(subnetToScan)")
        
        // 生成要扫描的IP列表
        let ipsToScan = generateIPsToScan(fromSubnet: subnetToScan)
        
        if ipsToScan.isEmpty {
            DispatchQueue.main.async {
                self.scanningErrorMessage = "无效的子网地址范围"
                self.isScanningInProgress = false
            }
            print("无效的子网地址范围，未生成IP地址")
            return
        }
        
        print("总共需要检查 \(ipsToScan.count) 个IP地址")
        
        // 创建扫描任务
        let scanTask = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 使用操作组进行扫描
            let operationQueue = OperationQueue()
            operationQueue.maxConcurrentOperationCount = self.maxConcurrentScans
            
            var scannedCount = 0
            
            // 依次添加扫描任务，但每个任务有延迟启动
            for (ipIndex, ip) in ipsToScan.enumerated() {
                if self.scanCancelled { break }
                
                let operation = BlockOperation { [weak self] in
                    guard let self = self, !self.scanCancelled else { return }
                    
                    print("开始扫描IP: \(ip) (\(ipIndex+1)/\(ipsToScan.count))")
                    
                    // 使用HTTP方法检测设备
                    self.quickCheckDevice(ip) { isAlive in
                        if self.scanCancelled { return }
                        
                        if isAlive {
                            print("设备响应: \(ip)")
                            DispatchQueue.main.async {
                                if !self.discoveredDevices.contains(ip) {
                                    self.discoveredDevices.append(ip)
                                    print("发现新设备并添加到列表: \(ip), 当前设备数: \(self.discoveredDevices.count)")
                                }
                            }
                        }
                        
                        // 更新已扫描数量
                        scannedCount += 1
                        print("已扫描: \(scannedCount)/\(ipsToScan.count)")
                        
                        // 强制短暂等待，让系统有时间处理和释放资源
                        Thread.sleep(forTimeInterval: self.scanInterval)
                    }
                }
                
                // 添加依赖关系，确保按顺序执行
                if ipIndex > 0 {
                    let delay = Double(ipIndex) * scanInterval
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        if !self.scanCancelled {
                            operationQueue.addOperation(operation)
                        }
                    }
                } else {
                    operationQueue.addOperation(operation)
                }
            }
            
            // 等待所有操作完成或取消
            operationQueue.waitUntilAllOperationsAreFinished()
            
            // 确保清理所有连接
            self.cancelAllConnections()
            
            // 完成时确保更新UI状态
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 如果扫描被取消，不显示结果消息
                if self.scanCancelled {
                    print("扫描被用户取消")
                } else {
                    print("扫描完成! 发现设备数: \(self.discoveredDevices.count)")
                    self.scanningErrorMessage = nil
                }
                
//                // 最后设置扫描状态为完成
//                self.isScanningInProgress = false
            }
        }
        
        self.currentScanTask = scanTask
        scanQueue.async(execute: scanTask)
    }
    
    /// 快速检测设备 - 只检查最常用的端口
    private func quickCheckDevice(_ ip: String, completion: @escaping (Bool) -> Void) {
        // 优先检查最常见的Web服务端口
        checkHttpPort(ip, port: 80) { [weak self] isAlive in
            guard let self = self, !self.scanCancelled else {
                completion(false)
                return
            }
            
            if isAlive {
                completion(true)
                return
            }
            
            // 如果80端口不可用，尝试8080端口
            self.checkHttpPort(ip, port: 8080) { isAlive in
                if isAlive {
                    completion(true)
                    return
                }
                
                // 如果Web端口都不可用，尝试常见的SSH端口
                self.checkTcpPort(ip, port: 22) { isAlive in
                    completion(isAlive)
                }
            }
        }
    }
    
    /// 检查HTTP端口
    private func checkHttpPort(_ ip: String, port: Int, completion: @escaping (Bool) -> Void) {
        guard !scanCancelled else {
            completion(false)
            return
        }
        
        let urlString = "http://\(ip):\(port)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.8  // 较短超时
        request.httpMethod = "HEAD"
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self, !self.scanCancelled else {
                completion(false)
                return
            }
            
            if error == nil, response != nil {
                print("HTTP响应成功: \(urlString)")
                completion(true)
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    /// 检查TCP端口
    private func checkTcpPort(_ ip: String, port: UInt16, completion: @escaping (Bool) -> Void) {
        guard !scanCancelled, let ipv4Address = try? IPv4Address(ip) else {
            completion(false)
            return
        }
        
        let endpoint = NWEndpoint.hostPort(host: .ipv4(ipv4Address), port: .init(integerLiteral: port))
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        // 跟踪连接
        connectionsLock.lock()
        activeConnections.append(connection)
        connectionsLock.unlock()
        
        var completed = false
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self, !completed, !self.scanCancelled else { return }
            
            switch state {
            case .ready:
                print("端口连接成功: \(ip):\(port)")
                completed = true
                
                // 从活动连接列表中移除并取消
                self.removeConnection(connection)
                
                completion(true)
                
            case .failed, .cancelled:
                if !completed {
                    completed = true
                    
                    // 从活动连接列表中移除
                    self.removeConnection(connection)
                    
                    completion(false)
                }
                
            default:
                break
            }
        }
        
        connection.start(queue: scanQueue)
        
        // 设置超时时间 - 较短以加快扫描
        scanQueue.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, !completed, !self.scanCancelled else { return }
            
            completed = true
            print("端口连接超时: \(ip):\(port)")
            
            // 从活动连接列表中移除并取消
            self.removeConnection(connection)
            
            completion(false)
        }
    }
    
    /// 移除并取消连接
    private func removeConnection(_ connection: NWConnection) {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        
        connection.cancel()
        
        if let index = activeConnections.firstIndex(where: { $0 === connection }) {
            activeConnections.remove(at: index)
        }
    }
    
    /// 根据子网生成IP列表
    private func generateIPsToScan(fromSubnet subnet: String) -> [String] {
        print("根据子网 \(subnet) 生成IP列表")
        var ips: [String] = []
        
        // 检查是否为单个IP地址
        if subnet.components(separatedBy: ".").count == 4 && !subnet.hasSuffix(".") {
            // 单个IP地址，直接添加
            ips.append(subnet)
            print("单个IP地址: \(subnet)")
            return ips
        }
        
        let components = subnet.components(separatedBy: ".")
        
        // 必须是C类网络 (xxx.xxx.xxx.)
        if components.count >= 3 && subnet.hasSuffix(".") {
            let prefix = components[0...2].joined(separator: ".")
            print("C类网络前缀: \(prefix)")
            for i in 1...254 { // 避开0（网络地址）和255（广播地址）
                ips.append("\(prefix).\(i)")
            }
        }
        
        // 添加当前设备IP - 确保扫描到自己
        if !ips.contains(currentIPAddress) && isNetworkConnected &&
           currentIPAddress.starts(with: components[0...1].joined(separator: ".")) {
            ips.insert(currentIPAddress, at: 0)
            print("添加当前IP地址到扫描列表: \(currentIPAddress)")
        }
        
        print("生成了 \(ips.count) 个IP地址")
        if !ips.isEmpty {
            print("IP范围示例: \(ips.first!) 到 \(ips.last!)")
        }
        
        return ips
    }
    
    /// 检查IP是否为私有IP地址(内网IP)
    private func isPrivateIP(_ ip: String) -> Bool {
        let components = ip.components(separatedBy: ".")
        guard components.count == 4,
              let first = Int(components[0]),
              let second = Int(components[1]) else {
            print("IP格式无效: \(ip)")
            return false
        }
        
        // 检查常见的内网IP范围
        let isPrivate = (first == 10) ||
               (first == 172 && second >= 16 && second <= 31) ||
               (first == 192 && second == 168) ||
               (first == 169 && second == 254) // 链路本地地址
        
        return isPrivate
    }
    
    /// 从IP地址和子网掩码中提取子网前缀
    private func extractSubnetPrefix(ipAddress: String, subnetMask: String) -> String {
        print("提取子网前缀 - IP: \(ipAddress), 掩码: \(subnetMask)")
        let ipComponents = ipAddress.components(separatedBy: ".")
        let maskComponents = subnetMask.components(separatedBy: ".")
        
        guard ipComponents.count == 4 && maskComponents.count == 4 else {
            print("IP或掩码格式无效")
            return "未知"
        }
        
        // 计算网络地址
        var networkParts: [String] = []
        for i in 0..<4 {
            if let ipPart = UInt8(ipComponents[i]), let maskPart = UInt8(maskComponents[i]) {
                networkParts.append(String(ipPart & maskPart))
            }
        }
        
        // 仅返回C类网络前缀
        return networkParts.count >= 3 ? "\(networkParts[0]).\(networkParts[1]).\(networkParts[2])." : "未知"
    }
    
    // 启动全局超时计时器
    private func startGlobalTimeoutTimer() {
        // 仅在启用全局超时时启动计时器
        guard isGlobalTimeoutEnabled else {
            print("全局超时已禁用")
            return
        }
        
        // 取消之前可能存在的超时任务
        globalTimeoutWorkItem?.cancel()
        
        // 创建新的超时任务
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            print("全局扫描超时 (\(self.globalTimeoutSeconds)秒)")
            
            // 停止扫描
            self.stopScan()
        }
        
        self.globalTimeoutWorkItem = timeoutWork
        
        // 安排超时任务在指定时间后执行
        print("设置全局扫描超时: \(globalTimeoutSeconds)秒")
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(globalTimeoutSeconds), execute: timeoutWork)
    }
}
