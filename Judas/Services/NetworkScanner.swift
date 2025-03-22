import Foundation
import Network

class NetworkScanner: ObservableObject {
    @Published var discoveredDevices: [String] = []
    private let queue = DispatchQueue(label: "NetworkScanner", qos: .utility)
    private var scanningInProgress = false
    
    // 获取当前WiFi的IP地址和子网
    func getCurrentIPAddress() -> (ipAddress: String, subnetMask: String)? {
        // 这里需要更多代码来获取当前的IP地址和子网掩码
        // 简化版本，实际应用中请实现完整的获取逻辑
        return ("192.168.1.100", "255.255.255.0")
    }
    
    func startScan() {
        guard !scanningInProgress else { return }
        
        scanningInProgress = true
        discoveredDevices.removeAll()
        
        // 使用多个常见子网进行扫描
        let subnets = ["192.168.1.", "192.168.0.", "10.0.0."]
        
        for subnet in subnets {
            for i in 1...254 {
                let ip = "\(subnet)\(i)"
                scanIPAddress(ip)
            }
        }
    }
    
    private func scanIPAddress(_ ip: String) {
        // 扫描常见端口
        let commonPorts = [80, 443, 22, 21, 8080, 3306, 5432]
        
        for port in commonPorts {
            scanPort(ip: ip, port: port)
        }
    }
    
    private func scanPort(ip: String, port: Int) {
        let endpoint = NWEndpoint.hostPort(host: .ipv4(ip), port: .init(integerLiteral: UInt16(port)))
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    if !self!.discoveredDevices.contains(ip) {
                        self?.discoveredDevices.append(ip)
                    }
                }
                connection.cancel()
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        
        // 设置3秒超时
        connection.start(queue: queue)
        
        // 5秒后如果还在连接，就取消
        queue.asyncAfter(deadline: .now() + 5) {
            if connection.state != .cancelled && connection.state != .failed {
                connection.cancel()
            }
        }
    }
}
