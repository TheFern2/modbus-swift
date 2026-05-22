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

        let responsePDU = await dispatchRequest(
            functionCode: functionCode,
            pdu: pdu,
            unitId: unitId,
            dataStore: dataStore,
            logger: logger,
        )

        return buildModbusTCPADU(
            transactionId: header.transactionId,
            unitId: unitId,
            pdu: responsePDU,
        )
    }

    // MARK: - Request Dispatch

    static func dispatchRequest(
        functionCode: UInt8,
        pdu: [UInt8],
        unitId: UInt8,
        dataStore: any ModbusDataStore,
        logger: Logger?
    ) async -> [UInt8] {
        do {
            switch functionCode {
            case ModbusFunctionCode.readCoils:
                return try await handleReadCoils(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.readDiscreteInputs:
                return try await handleReadDiscreteInputs(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.readHoldingRegisters:
                return try await handleReadHoldingRegisters(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.readInputRegisters:
                return try await handleReadInputRegisters(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.writeSingleCoil:
                return try await handleWriteSingleCoil(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.writeSingleRegister:
                return try await handleWriteSingleRegister(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.writeMultipleCoils:
                return try await handleWriteMultipleCoils(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.writeMultipleRegisters:
                return try await handleWriteMultipleRegisters(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.maskWriteRegister:
                return try await handleMaskWriteRegister(pdu: pdu, unitId: unitId, dataStore: dataStore)

            case ModbusFunctionCode.readWriteMultipleRegisters:
                return try await handleReadWriteMultipleRegisters(pdu: pdu, unitId: unitId, dataStore: dataStore)

            default:
                return buildExceptionResponsePDU(
                    functionCode: functionCode,
                    exception: .illegalFunction,
                )
            }
        } catch let error as ModbusServerError {
            return buildExceptionResponsePDU(
                functionCode: functionCode,
                exception: error.modbusException,
            )
        } catch let error as PDUError {
            logger?.debug("PDU parse error for FC 0x\(String(functionCode, radix: 16)): \(error)")
            return buildExceptionResponsePDU(
                functionCode: functionCode,
                exception: .illegalDataValue,
            )
        } catch {
            logger?.warning("Unexpected error for FC 0x\(String(functionCode, radix: 16)): \(error)")
            return buildExceptionResponsePDU(
                functionCode: functionCode,
                exception: .slaveDeviceFailure,
            )
        }
    }

    // MARK: - FC Handlers

    private static func handleReadCoils(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseReadRequestPDU(pdu)
        let bits = try await dataStore.readCoils(unitId: unitId, address: req.address, count: req.count)
        return buildReadBitsResponsePDU(functionCode: ModbusFunctionCode.readCoils, bits: bits)
    }

    private static func handleReadDiscreteInputs(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseReadRequestPDU(pdu)
        let bits = try await dataStore.readDiscreteInputs(unitId: unitId, address: req.address, count: req.count)
        return buildReadBitsResponsePDU(functionCode: ModbusFunctionCode.readDiscreteInputs, bits: bits)
    }

    private static func handleReadHoldingRegisters(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseReadRequestPDU(pdu)
        let regs = try await dataStore.readHoldingRegisters(unitId: unitId, address: req.address, count: req.count)
        return buildReadRegistersResponsePDU(
            functionCode: ModbusFunctionCode.readHoldingRegisters,
            registers: regs,
        )
    }

    private static func handleReadInputRegisters(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseReadRequestPDU(pdu)
        let regs = try await dataStore.readInputRegisters(unitId: unitId, address: req.address, count: req.count)
        return buildReadRegistersResponsePDU(
            functionCode: ModbusFunctionCode.readInputRegisters,
            registers: regs,
        )
    }

    private static func handleWriteSingleCoil(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseWriteSingleCoilRequestPDU(pdu)
        try await dataStore.writeSingleCoil(unitId: unitId, address: req.address, value: req.value)
        return buildWriteSingleCoilResponsePDU(address: req.address, value: req.value)
    }

    private static func handleWriteSingleRegister(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseWriteSingleRegisterRequestPDU(pdu)
        try await dataStore.writeSingleRegister(unitId: unitId, address: req.address, value: req.value)
        return buildWriteSingleRegisterResponsePDU(address: req.address, value: req.value)
    }

    private static func handleWriteMultipleCoils(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseWriteMultipleCoilsRequestPDU(pdu)
        try await dataStore.writeMultipleCoils(unitId: unitId, address: req.address, values: req.values)
        return buildWriteMultipleCoilsResponsePDU(address: req.address, quantity: UInt16(req.values.count))
    }

    private static func handleWriteMultipleRegisters(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseWriteMultipleRegistersRequestPDU(pdu)
        try await dataStore.writeMultipleRegisters(unitId: unitId, address: req.address, values: req.values)
        return buildWriteMultipleRegistersResponsePDU(address: req.address, quantity: UInt16(req.values.count))
    }

    private static func handleMaskWriteRegister(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseMaskWriteRegisterRequestPDU(pdu)
        try await dataStore.maskWriteRegister(
            unitId: unitId,
            address: req.address,
            andMask: req.andMask,
            orMask: req.orMask,
        )
        return buildMaskWriteRegisterResponsePDU(
            address: req.address,
            andMask: req.andMask,
            orMask: req.orMask,
        )
    }

    private static func handleReadWriteMultipleRegisters(
        pdu: [UInt8], unitId: UInt8, dataStore: any ModbusDataStore
    ) async throws -> [UInt8] {
        let req = try parseReadWriteMultipleRegistersRequestPDU(pdu)
        let regs = try await dataStore.readWriteMultipleRegisters(
            unitId: unitId,
            readAddress: req.readAddress,
            readCount: req.readCount,
            writeAddress: req.writeAddress,
            writeValues: req.writeValues,
        )
        return buildReadWriteMultipleRegistersResponsePDU(registers: regs)
    }

    // MARK: - Helper

    private static func wrapOutbound(_ buffer: ByteBuffer) -> NIOAny {
        NIOAny(buffer)
    }
}
