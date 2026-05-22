// SPDX-License-Identifier: Apache-2.0

import Logging
import ModbusCore
import NIOCore

// MARK: - ModbusServerHandler

/// NIO channel handler that processes Modbus TCP requests.
///
/// Receives decoded frames from `ModbusFrameDecoder`, dispatches to a
/// `ModbusDataStore`, and writes response frames back to the channel.
final class ModbusServerHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = [UInt8]
    typealias OutboundOut = ByteBuffer

    private let dataStore: any ModbusDataStore
    private let logger: Logger?
    private var channelContext: ChannelHandlerContext?

    init(dataStore: any ModbusDataStore, logger: Logger?) {
        self.dataStore = dataStore
        self.logger = logger
    }

    func handlerAdded(context: ChannelHandlerContext) {
        channelContext = context
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        channelContext = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)

        logger?.trace("RX: \(frame.hexString)")

        let promise = context.eventLoop.makePromise(of: [UInt8].self)

        promise.completeWithTask { [dataStore, logger] in
            await Self.processFrame(frame, dataStore: dataStore, logger: logger)
        }

        promise.futureResult.whenSuccess { [self] responseBytes in
            guard !responseBytes.isEmpty, let ctx = self.channelContext else { return }
            self.logger?.trace("TX: \(responseBytes.hexString)")
            var buffer = ctx.channel.allocator.buffer(capacity: responseBytes.count)
            buffer.writeBytes(responseBytes)
            ctx.writeAndFlush(Self.wrapOutbound(buffer), promise: nil)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger?.warning("Server handler error: \(error)")
        context.close(promise: nil)
    }

    // MARK: - Frame Processing

    static func processFrame(
        _ frame: [UInt8],
        dataStore: any ModbusDataStore,
        logger: Logger?
    ) async -> [UInt8] {
        let header: MBAPHeader
        let pdu: [UInt8]
        do {
            (header, pdu) = try parseModbusTCPADU(frame)
        } catch {
            logger?.warning("Failed to parse MBAP: \(error)")
            return []
        }

        guard !pdu.isEmpty else {
            logger?.warning("Empty PDU")
            return []
        }

        let functionCode = pdu[0]
        let unitId = header.unitId

        let responsePDU = await dispatchModbusRequest(
            functionCode: functionCode,
            pdu: pdu,
            unitId: unitId,
            dataStore: dataStore,
            logHandler: logger.map { log in { msg in log.debug("\(msg)") } },
        )

        return buildModbusTCPADU(
            transactionId: header.transactionId,
            unitId: unitId,
            pdu: responsePDU,
        )
    }

    // MARK: - Helper

    private static func wrapOutbound(_ buffer: ByteBuffer) -> NIOAny {
        NIOAny(buffer)
    }
}
