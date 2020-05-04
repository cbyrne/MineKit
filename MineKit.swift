import NIO

public struct MineKit {
    private let hostname: String
    private let port: Int
    private let username: String
    private let context: ChannelHandlerContext
    var connectedToServer: Bool
    
    public init(hostname: String, port: Int, context: ChannelHandlerContext, username: String) {
        self.hostname = hostname
        self.port = port
        self.context = context
        self.username = username
        self.connectedToServer = false
    }
    
    public func connectToServer() {
        sendPacket(packet: HandshakePacket(withHostname: hostname, andPort: port))
        sendPacket(packet: LoginStartPacket(withUsername: "ConorDoesMC"))
    }
    
    public func sendMessage() {
        sendPacket(packet: ChatMessagePacket(withMessage: "hi"))
    }
    
    func sendPacket(packet: MineKitPacket) {
        print("📨 Sending packet: \(String(describing: packet))")
        context.writeAndFlush(NIOAny(packet), promise: nil)
        print("📩 Sent packet: \(String(describing: packet))")
    }
}
