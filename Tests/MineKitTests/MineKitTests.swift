import XCTest
import NIO

@testable import MineKit

final class MineKitTests: XCTestCase, ChannelInboundHandler {
    let defaultHost = "78.47.18.216"
    let defaultPort: Int = 25565

    public typealias InboundIn = MineKitPacket
    public typealias OutboundIn = MineKitPacket
    public typealias OutboundOut = MineKitPacket
           
    public func channelActive(context: ChannelHandlerContext) {
        var minekit = MineKit.shared
        minekit.setup(hostname: defaultHost, port: defaultPort, context: context, username: "ConorDoesMC")
        
        minekit.logger.info("Client connected to \(context.remoteAddress!)")
        
        do {
            try minekit.connectToServer()
        } catch let error {
            MineKit.shared.logger.error("Error: \(error)")
            context.close(promise: nil)
            XCTFail("Error occured: \(error)")
        }
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = self.unwrapInboundIn(data)
        let handler = MineKitRequestManager.packetHandlerMap[packet.packetID]

        MineKit.shared.logger.debug("Got packet \(String(describing: packet))")
        
        if(handler != nil) {
            let resp = handler!.handle(context: context, packet: packet)
            if(resp == .success) {
                MineKit.shared.logger.info("Successfully handled packet \(String(describing: packet))")
            } else {
                MineKit.shared.logger.error("Failed to handle packet, see stacktrace for errors")
            }
        }
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        MineKit.shared.logger.error("Error: \(error)")
        context.close(promise: nil)
        XCTFail("Error occured: \(error)")
    }

    func testLogin() {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                _ = channel.pipeline.addHandler(ByteToMessageHandler(ByteBufToPacketDecoder()))
                _ = channel.pipeline.addHandler(MessageToByteHandler(ByteBufToLengthBufferEncoder()), name: "1", position: ChannelPipeline.Position.first)
                _ = channel.pipeline.addHandler(self, name: "3", position: ChannelPipeline.Position.last)
                return channel.pipeline.addHandler(MessageToByteHandler(PacketToByteBufEncoder()), name: "2", position: ChannelPipeline.Position.before(self))
            }
        defer {
            try! group.syncShutdownGracefully()
        }

        enum ConnectTo {
            case ip(host: String, port: Int)
            case unixDomainSocket(path: String)
        }

        let connectTarget: ConnectTo = .ip(host: defaultHost, port: defaultPort)

        do {
            let channel = try { () -> Channel in
                switch connectTarget {
                case .ip(let host, let port):
                    return try bootstrap.connect(host: host, port: port).wait()
                case .unixDomainSocket(let path):
                    return try bootstrap.connect(unixDomainSocketPath: path).wait()
                }
            }()

            // Will be closed after we echo-ed back to the server.
            try channel.closeFuture.wait()
        } catch let error {
            MineKit.shared.logger.error("Error: \(error)")
            XCTFail("Error occured: \(error)")
        }

        MineKit.shared.logger.info("Client closed!")
        XCTAssertTrue(true)
    }

    static var allTests = [
        ("testLogin", testLogin),
    ]
}
