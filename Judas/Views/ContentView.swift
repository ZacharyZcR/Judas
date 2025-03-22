import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScannerViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("当前内网: 192.168.1.x")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                
                List(viewModel.devices) { device in  // 确保device类型可被推断
                    NavigationLink(destination: DeviceDetailView(device: device)) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                            Text(device.ipAddress)
                            Spacer()
                            Text("\(device.openPorts.count) 端口")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(action: {
                    viewModel.startScan()
                }) {
                    HStack {
                        Image(systemName: viewModel.isScanning ? "stop.fill" : "play.fill")
                        Text(viewModel.isScanning ? "停止扫描" : "开始扫描")
                    }
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Judas 网络扫描")
        }
    }
}
