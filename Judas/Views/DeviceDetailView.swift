import SwiftUI
import Network

class PortScanner: ObservableObject {
    @Published var openPorts: [Int] = []
    @Published var scanProgress: Double = 0.0
    @Published var totalPorts: Int = 0
    @Published var scannedPorts: Int = 0
    
    private let queue = DispatchQueue(label: "PortScanner", qos: .utility)
    
    func scanPorts(for ipAddress: String, completion: @escaping () -> Void) {
        openPorts.removeAll()
        scanProgress = 0.0
        scannedPorts = 0
        
        // 扩展更多常见端口
        let commonPorts = [
            20, 21, 22, 23, 25, 53, 80, 81, 88, 110, 115, 135, 139, 143, 194, 389, 443,
            445, 465, 515, 543, 544, 548, 554, 587, 631, 636, 646, 873, 902, 990, 993,
            995, 1080, 1194, 1433, 1521, 1723, 2049, 2082, 2083, 2086, 2087, 2095, 2096,
            3306, 3389, 4500, 5060, 5061, 5432, 5500, 5800, 5900, 5938, 6000, 6665, 6669,
            6697, 7070, 8000, 8008, 8080, 8081, 8443, 8888, 9000, 9090, 9100, 9418, 10000
        ]
        
        totalPorts = commonPorts.count
        
        let group = DispatchGroup()
        
        for (index, port) in commonPorts.enumerated() {
            group.enter()
            checkPort(ip: ipAddress, port: port) { isOpen in
                DispatchQueue.main.async {
                    self.scannedPorts += 1
                    self.scanProgress = Double(self.scannedPorts) / Double(self.totalPorts)
                    
                    if isOpen {
                        self.openPorts.append(port)
                    }
                }
                group.leave()
            }
            
            // 增加短暂延迟以降低网络负载
            if index % 10 == 0 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }
    
    private func checkPort(ip: String, port: Int, completion: @escaping (Bool) -> Void) {
        guard let ipv4Address = try? IPv4Address(ip) else {
            completion(false)
            return
        }
        
        let endpoint = NWEndpoint.hostPort(host: .ipv4(ipv4Address), port: .init(integerLiteral: UInt16(port)))
        let connection = NWConnection(to: endpoint, using: .tcp)
        let serialQueue = DispatchQueue(label: "com.judas.portscanner.\(ip).\(port)")
        var connectionComplete = false
        
        connection.stateUpdateHandler = { state in
            serialQueue.sync {
                if connectionComplete { return }
                
                switch state {
                case .ready:
                    print("端口开放: \(ip):\(port)")
                    connectionComplete = true
                    connection.cancel()
                    completion(true)
                    
                case .failed(_), .cancelled:
                    if !connectionComplete {
                        connectionComplete = true
                        connection.cancel()
                        completion(false)
                    }
                    
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
        
        // 增加超时时间以提高检测可靠性
        queue.asyncAfter(deadline: .now() + 2.0) {
            serialQueue.sync {
                if !connectionComplete {
                    connectionComplete = true
                    connection.cancel()
                    completion(false)
                }
            }
        }
    }
}

struct DeviceDetailView: View {
    let device: Device
    @State private var isPortScanning = false
    @StateObject private var portScanner = PortScanner()
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPortCategory: PortCategory = .all
    
    enum PortCategory: String, CaseIterable, Identifiable {
        case all = "全部"
        case web = "Web服务"
        case database = "数据库"
        case remoteAccess = "远程访问"
        case fileSharing = "文件服务"
        case other = "其他"
        
        var id: String { self.rawValue }
    }
    
    var filteredPorts: [Int] {
        switch selectedPortCategory {
        case .all:
            return portScanner.openPorts
        case .web:
            return portScanner.openPorts.filter { [80, 81, 443, 8000, 8008, 8080, 8081, 8443, 8888, 9000].contains($0) }
        case .database:
            return portScanner.openPorts.filter { [1433, 1521, 3306, 5432, 6379, 27017].contains($0) }
        case .remoteAccess:
            return portScanner.openPorts.filter { [22, 23, 3389, 5900, 5938].contains($0) }
        case .fileSharing:
            return portScanner.openPorts.filter { [20, 21, 115, 139, 445, 548, 2049, 873].contains($0) }
        case .other:
            let specialPorts = [80, 81, 443, 8000, 8008, 8080, 8081, 8443, 8888, 9000,
                              1433, 1521, 3306, 5432, 6379, 27017,
                              22, 23, 3389, 5900, 5938,
                              20, 21, 115, 139, 445, 548, 2049, 873]
            return portScanner.openPorts.filter { !specialPorts.contains($0) }
        }
    }
    
    var body: some View {
        List {
            // 设备信息部分
            deviceInfoSection
            
            // 端口扫描部分
            portScanSection
            
            // 操作部分
            actionsSection
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("设备详情")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // 刷新
                    if !isPortScanning {
                        isPortScanning = true
                        portScanner.scanPorts(for: device.ipAddress) {
                            isPortScanning = false
                        }
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                        .disabled(isPortScanning)
                }
            }
        }
        .onAppear {
            // 自动开始端口扫描
            if !isPortScanning && portScanner.openPorts.isEmpty {
                isPortScanning = true
                portScanner.scanPorts(for: device.ipAddress) {
                    isPortScanning = false
                }
            }
        }
    }
    
    // 设备信息部分
    private var deviceInfoSection: some View {
        Section {
            // 设备图标与IP地址
            VStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "network")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
                
                Text(device.ipAddress)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("设备在线")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // 设备详细信息
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                Text("IP地址")
                Spacer()
                Text(device.ipAddress)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(.green)
                    .frame(width: 24, height: 24)
                Text("状态")
                Spacer()
                Text("在线")
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 4)
        } header: {
            Text("设备信息")
                .font(.headline)
        }
    }
    
    // 端口扫描部分
    private var portScanSection: some View {
        Section {
            if isPortScanning {
                scanningView
            } else if portScanner.openPorts.isEmpty {
                emptyPortsView
            } else {
                portCategoryPicker
                
                if !filteredPorts.isEmpty {
                    portListView
                } else {
                    Text("此类别下没有开放端口")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            
            scanButton
        } header: {
            HStack {
                Text("开放端口")
                    .font(.headline)
                
                Spacer()
                
                if !portScanner.openPorts.isEmpty {
                    Text("\(portScanner.openPorts.count) 个开放端口")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            Text("扫描常用端口以检测设备提供的服务")
                .font(.caption)
        }
    }
    
    // 正在扫描视图
    private var scanningView: some View {
        VStack(spacing: 16) {
            ZStack {
                // 进度环
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.3)
                    .foregroundColor(Color.blue)
                
                Circle()
                    .trim(from: 0.0, to: portScanner.scanProgress)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: portScanner.scanProgress)
                
                // 进度文本
                VStack {
                    Text("\(Int(portScanner.scanProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(portScanner.scannedPorts)/\(portScanner.totalPorts)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)
            
            Text("正在扫描端口...")
                .font(.headline)
                .foregroundColor(.primary)
            
            if !portScanner.openPorts.isEmpty {
                Text("已发现 \(portScanner.openPorts.count) 个开放端口")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // 无开放端口视图
    private var emptyPortsView: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                Text("未发现开放端口")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("此设备可能有防火墙或没有运行网络服务")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
    
    // 端口类别选择器
    private var portCategoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PortCategory.allCases) { category in
                    Button(action: {
                        selectedPortCategory = category
                    }) {
                        Text(category.rawValue)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(selectedPortCategory == category ? .white : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedPortCategory == category ? Color.blue : Color.blue.opacity(0.1))
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // 端口列表视图
    private var portListView: some View {
        ForEach(filteredPorts, id: \.self) { port in
            HStack(spacing: 12) {
                // 端口图标
                ZStack {
                    Circle()
                        .fill(getServiceColor(for: port).opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: getServiceIcon(for: port))
                        .foregroundColor(getServiceColor(for: port))
                }
                
                // 端口信息
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(port)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        Text(getServiceName(for: port))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if getServiceDescription(for: port) != "" {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(getServiceDescription(for: port))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // 操作按钮
                if canOpenInBrowser(port) {
                    Button(action: {
                        openInBrowser(port)
                    }) {
                        Image(systemName: "safari")
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.vertical, 4)
            .contextMenu {
                Button(action: {
                    UIPasteboard.general.string = "\(device.ipAddress):\(port)"
                }) {
                    Label("复制地址和端口", systemImage: "doc.on.doc")
                }
                
                if canOpenInBrowser(port) {
                    Button(action: {
                        openInBrowser(port)
                    }) {
                        Label("在浏览器中打开", systemImage: "safari")
                    }
                }
                
                if port == 22 {
                    Button(action: {
                        UIPasteboard.general.string = "ssh user@\(device.ipAddress)"
                    }) {
                        Label("复制SSH命令", systemImage: "terminal")
                    }
                }
            }
        }
    }
    
    // 扫描按钮
    private var scanButton: some View {
        Button(action: {
            if !isPortScanning {
                isPortScanning = true
                portScanner.scanPorts(for: device.ipAddress) {
                    isPortScanning = false
                }
            }
        }) {
            HStack {
                Image(systemName: isPortScanning ? "stop.circle.fill" : "bolt.horizontal.circle.fill")
                Text(isPortScanning ? "扫描中..." : "重新扫描端口")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        }
        .disabled(isPortScanning)
        .buttonStyle(BorderlessButtonStyle())
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(isPortScanning ? 0.1 : 0.2))
                .padding(4)
        )
    }
    
    // 操作部分
    private var actionsSection: some View {
        Section {
            Button(action: {
                UIPasteboard.general.string = device.ipAddress
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                    Text("复制IP地址")
                    Spacer()
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            
            // Web服务操作
            if hasOpenWebPort() {
                Button(action: {
                    openPreferredWebPort()
                }) {
                    HStack {
                        Image(systemName: "safari")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        Text("在浏览器中打开")
                        Spacer()
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // SSH操作
            if portScanner.openPorts.contains(22) {
                Button(action: {
                    UIPasteboard.general.string = "ssh user@\(device.ipAddress)"
                }) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        Text("复制SSH连接命令")
                        Spacer()
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // 文件服务操作
            if hasFileSharing() {
                Button(action: {
                    // 根据不同的文件共享协议复制不同的连接字符串
                    let protocolName: String
                    if portScanner.openPorts.contains(445) {
                        protocolName = "smb"
                    } else if portScanner.openPorts.contains(548) {
                        protocolName = "afp"
                    } else {
                        protocolName = "ftp"
                    }
                    UIPasteboard.general.string = "\(protocolName)://\(device.ipAddress)"
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        Text("复制文件共享地址")
                        Spacer()
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        } header: {
            Text("操作")
                .font(.headline)
        }
    }
    
    // 获取端口对应的服务图标
    func getServiceIcon(for port: Int) -> String {
        switch port {
        case 80, 81, 443, 8000, 8008, 8080, 8081, 8443, 8888: return "globe"
        case 22: return "terminal"
        case 23: return "keyboard"
        case 21, 115, 548: return "folder"
        case 25, 110, 143, 465, 587, 993, 995: return "envelope"
        case 53: return "dot.radiowaves.up.forward"
        case 1433, 1521, 3306, 5432, 6379, 27017: return "database.fill"
        case 3389: return "rectangle.on.rectangle"
        case 5900, 5938: return "display"
        case 139, 445: return "network"
        case 1194, 4500: return "lock.shield"
        case 5060, 5061: return "phone.fill"
        case 9100: return "printer.fill"
        case 8008, 9000, 9090: return "server.rack"
        default: return "circle.grid.cross"
        }
    }
    
    // 获取服务颜色
    func getServiceColor(for port: Int) -> Color {
        switch port {
        case 80, 81, 443, 8000, 8008, 8080, 8081, 8443, 8888: return .blue
        case 22, 23, 3389, 5900, 5938: return .purple
        case 21, 115, 139, 445, 548, 2049, 873: return .orange
        case 1433, 1521, 3306, 5432, 6379, 27017: return .green
        case 25, 110, 143, 465, 587, 993, 995: return .pink
        case 53: return .teal
        default: return .gray
        }
    }
    
    // 获取端口对应的服务名称
    func getServiceName(for port: Int) -> String {
        switch port {
        case 20: return "FTP-Data"
        case 21: return "FTP"
        case 22: return "SSH"
        case 23: return "Telnet"
        case 25: return "SMTP"
        case 53: return "DNS"
        case 80: return "HTTP"
        case 81: return "HTTP备用"
        case 88: return "Kerberos"
        case 110: return "POP3"
        case 115: return "SFTP"
        case 135: return "RPC"
        case 139: return "NetBIOS"
        case 143: return "IMAP"
        case 194: return "IRC"
        case 389: return "LDAP"
        case 443: return "HTTPS"
        case 445: return "SMB"
        case 465: return "SMTPS"
        case 515: return "打印服务"
        case 543, 544: return "Kerberos"
        case 548: return "AFP"
        case 554: return "RTSP"
        case 587: return "SMTP提交"
        case 631: return "IPP打印"
        case 636: return "LDAPS"
        case 873: return "Rsync"
        case 990: return "FTPS"
        case 993: return "IMAPS"
        case 995: return "POP3S"
        case 1080: return "SOCKS"
        case 1194: return "OpenVPN"
        case 1433: return "MSSQL"
        case 1521: return "Oracle"
        case 1723: return "PPTP"
        case 2049: return "NFS"
        case 2082, 2083: return "cPanel"
        case 2086, 2087: return "WHM"
        case 2095, 2096: return "Webmail"
        case 3306: return "MySQL"
        case 3389: return "RDP"
        case 4500: return "IPsec"
        case 5060, 5061: return "SIP"
        case 5432: return "PostgreSQL"
        case 5500: return "VNC"
        case 5800, 5900, 5938: return "VNC"
        case 6000: return "X11"
        case 6379: return "Redis"
        case 6665, 6666, 6667, 6668, 6669, 6697: return "IRC"
        case 7070: return "RTSP"
        case 8000: return "Web缓存"
        case 8008, 8080: return "Web代理"
        case 8081: return "Web代理"
        case 8443: return "HTTPS备用"
        case 8888: return "Web服务"
        case 9000: return "Web服务"
        case 9090: return "Web控制台"
        case 9100: return "打印服务"
        case 9418: return "Git"
        case 27017: return "MongoDB"
        case 10000: return "Webmin"
        default: return "未知服务"
        }
    }
    
    // 获取服务描述
    func getServiceDescription(for port: Int) -> String {
        switch port {
        case 80, 81, 8000, 8008, 8080, 8081, 8888, 9000: return "网页服务"
        case 443, 8443: return "安全网页"
        case 22: return "远程终端"
        case 23: return "远程登录"
        case 21, 115, 990: return "文件传输"
        case 139, 445: return "Windows共享"
        case 548: return "苹果共享"
        case 3389: return "远程桌面"
        case 5900, 5938: return "远程控制"
        case 1433: return "SQL Server数据库"
        case 1521: return "Oracle数据库"
        case 3306: return "MySQL数据库"
        case 5432: return "PostgreSQL数据库"
        case 6379: return "缓存数据库"
        case 27017: return "文档数据库"
        case 25, 465, 587: return "邮件发送"
        case 110, 995: return "邮件接收"
        case 143, 993: return "邮件访问"
        case 53: return "域名解析"
        case 1194, 4500: return "VPN服务"
        case 5060, 5061: return "网络电话"
        case 9100, 515, 631: return "打印服务"
        default: return ""
        }
    }
    
    // 是否可以在浏览器中打开
    func canOpenInBrowser(_ port: Int) -> Bool {
        let webPorts = [80, 81, 443, 8000, 8008, 8080, 8081, 8443, 8888, 9000, 9090]
        return webPorts.contains(port)
    }
    
    // 在浏览器中打开
    func openInBrowser(_ port: Int) {
        let scheme = port == 443 || port == 8443 ? "https" : "http"
        if let url = URL(string: "\(scheme)://\(device.ipAddress):\(port)") {
            UIApplication.shared.open(url)
        }
    }
    
    // 是否有开放的Web端口
    func hasOpenWebPort() -> Bool {
        let webPorts = [80, 81, 443, 8000, 8008, 8080, 8081, 8443, 8888, 9000, 9090]
        return portScanner.openPorts.contains { webPorts.contains($0) }
    }
    
    // 打开首选Web端口
    func openPreferredWebPort() {
        // 优先尝试标准端口
        let preferredOrder = [80, 443, 8080, 8443, 8000, 8888, 9000]
        
        for port in preferredOrder {
            if portScanner.openPorts.contains(port) {
                openInBrowser(port)
                return
            }
        }
        
        // 如果没有优先端口，使用第一个可用的Web端口
        let webPorts = [80, 81, 443, 8000, 8008, 8080, 8081, 8443, 8888, 9000, 9090]
        if let firstOpenWebPort = portScanner.openPorts.first(where: { webPorts.contains($0) }) {
            openInBrowser(firstOpenWebPort)
        }
    }
    
    // 是否有文件共享服务
    func hasFileSharing() -> Bool {
        let fileSharingPorts = [21, 115, 139, 445, 548, 2049, 873]
        return portScanner.openPorts.contains { fileSharingPorts.contains($0) }
    }
}
