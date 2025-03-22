struct Device: Identifiable, Hashable {
    let id = UUID()
    let ipAddress: String
    var openPorts: [Int] = []
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ipAddress)
    }
}
