// SPDX-License-Identifier: Apache-2.0

import ModbusCore
@testable import ModbusKit
import NIOCore
import NIOEmbedded
import Testing

@Suite("ModbusServerHandler")
struct ServerHandlerTests {

    // MARK: - Helpers

    private func makeStore(unitIds: Set<UInt8> = [1]) -> InMemoryDataStore {
        InMemoryDataStore(unitIds: unitIds)
    }

    private func buildRequest(
        transactionId: UInt16 = 1,
        unitId: UInt8 = 1,
        pdu: [UInt8]
    ) -> [UInt8] {
        buildModbusTCPADU(transactionId: transactionId, unitId: unitId, pdu: pdu)
    }

    private func parseResponse(_ frame: [UInt8]) throws -> (header: MBAPHeader, pdu: [UInt8]) {
        try parseModbusTCPADU(frame)
    }

    // MARK: - FC 0x03: Read Holding Registers

    @Test("Read holding registers returns correct values")
    func readHoldingRegisters() async throws {
        let store = makeStore()
        await store.setHoldingRegisters(unitId: 1, address: 100, values: [0x0001, 0x0002, 0x0003])

        let request = buildReadHoldingRegistersPDU(address: 100, count: 3)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (header, pdu) = try parseResponse(response)

        #expect(header.transactionId == 1)
        #expect(header.unitId == 1)

        let parsed = try parseReadRegistersPDU(pdu)
        #expect(parsed.registers == [0x0001, 0x0002, 0x0003])
    }

    // MARK: - FC 0x04: Read Input Registers

    @Test("Read input registers returns correct values")
    func readInputRegisters() async throws {
        let store = makeStore()
        await store.setInputRegisters(unitId: 1, address: 0, values: [0xABCD, 0x1234])

        let request = buildReadInputRegistersPDU(address: 0, count: 2)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseReadRegistersPDU(pdu, expectedFunction: 0x04)
        #expect(parsed.registers == [0xABCD, 0x1234])
    }

    // MARK: - FC 0x06: Write Single Register

    @Test("Write single register echoes address and value")
    func writeSingleRegister() async throws {
        let store = makeStore()

        let request = buildWriteSingleRegisterPDU(address: 10, value: 0xBEEF)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseWriteSingleRegisterPDU(pdu)
        #expect(parsed.address == 10)
        #expect(parsed.value == 0xBEEF)

        let stored = try await store.readHoldingRegisters(unitId: 1, address: 10, count: 1)
        #expect(stored == [0xBEEF])
    }

    // MARK: - FC 0x10: Write Multiple Registers

    @Test("Write multiple registers echoes address and quantity")
    func writeMultipleRegisters() async throws {
        let store = makeStore()

        let values: [UInt16] = [0x000A, 0x000B, 0x000C]
        let request = buildWriteMultipleRegistersPDU(address: 0, values: values)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseWriteMultipleRegistersPDU(pdu)
        #expect(parsed.address == 0)
        #expect(parsed.quantity == 3)

        let stored = try await store.readHoldingRegisters(unitId: 1, address: 0, count: 3)
        #expect(stored == values)
    }

    // MARK: - FC 0x01: Read Coils

    @Test("Read coils returns correct bit values")
    func readCoils() async throws {
        let store = makeStore()
        await store.setCoils(unitId: 1, address: 0, values: [true, false, true, true, false])

        let request = buildReadCoilsPDU(address: 0, count: 5)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseReadBitsPDU(pdu, expectedFunction: 0x01, requestedCount: 5)
        #expect(parsed.bits == [true, false, true, true, false])
    }

    // MARK: - FC 0x02: Read Discrete Inputs

    @Test("Read discrete inputs returns correct bit values")
    func readDiscreteInputs() async throws {
        let store = makeStore()
        await store.setDiscreteInputs(unitId: 1, address: 10, values: [false, true, true])

        let request = buildReadDiscreteInputsPDU(address: 10, count: 3)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseReadBitsPDU(pdu, expectedFunction: 0x02, requestedCount: 3)
        #expect(parsed.bits == [false, true, true])
    }

    // MARK: - FC 0x05: Write Single Coil

    @Test("Write single coil echoes address and value")
    func writeSingleCoil() async throws {
        let store = makeStore()

        let request = buildWriteSingleCoilPDU(address: 20, value: true)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseWriteSingleCoilPDU(pdu)
        #expect(parsed.address == 20)
        #expect(parsed.value == true)

        let stored = try await store.readCoils(unitId: 1, address: 20, count: 1)
        #expect(stored == [true])
    }

    // MARK: - FC 0x0F: Write Multiple Coils

    @Test("Write multiple coils echoes address and quantity")
    func writeMultipleCoils() async throws {
        let store = makeStore()

        let coils: [Bool] = [true, false, true, true, false, false, true, true, true, false]
        let request = buildWriteMultipleCoilsPDU(address: 0x0013, values: coils)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseWriteMultipleCoilsPDU(pdu)
        #expect(parsed.address == 0x0013)
        #expect(parsed.quantity == 10)

        let stored = try await store.readCoils(unitId: 1, address: 0x0013, count: 10)
        #expect(stored == coils)
    }

    // MARK: - FC 0x16: Mask Write Register

    @Test("Mask write register echoes address and masks")
    func maskWriteRegister() async throws {
        let store = makeStore()
        await store.setHoldingRegisters(unitId: 1, address: 4, values: [0x0012])

        let request = buildMaskWriteRegisterPDU(address: 4, andMask: 0x00F2, orMask: 0x0025)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseMaskWriteRegisterPDU(pdu)
        #expect(parsed.address == 4)
        #expect(parsed.andMask == 0x00F2)
        #expect(parsed.orMask == 0x0025)

        let stored = try await store.readHoldingRegisters(unitId: 1, address: 4, count: 1)
        #expect(stored == [0x0037])
    }

    // MARK: - FC 0x17: Read/Write Multiple Registers

    @Test("Read/Write multiple registers returns read data after write")
    func readWriteMultipleRegisters() async throws {
        let store = makeStore()
        await store.setHoldingRegisters(unitId: 1, address: 3, values: [0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006])

        let request = buildReadWriteMultipleRegistersPDU(
            readAddress: 3,
            readCount: 6,
            writeAddress: 14,
            writeValues: [0x00FF, 0x00FF, 0x00FF]
        )
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        let parsed = try parseReadWriteMultipleRegistersPDU(pdu)
        #expect(parsed.registers == [0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006])
    }

    // MARK: - Transaction ID Preservation

    @Test("Response preserves transaction ID from request")
    func transactionIdPreserved() async throws {
        let store = makeStore()

        let request = buildReadHoldingRegistersPDU(address: 0, count: 1)
        let frame = buildRequest(transactionId: 0x1234, pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (header, _) = try parseResponse(response)

        #expect(header.transactionId == 0x1234)
    }

    @Test("Response preserves unit ID from request")
    func unitIdPreserved() async throws {
        let store = InMemoryDataStore(unitIds: [5])

        let request = buildReadHoldingRegistersPDU(address: 0, count: 1)
        let frame = buildRequest(unitId: 5, pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (header, _) = try parseResponse(response)

        #expect(header.unitId == 5)
    }

    // MARK: - Exception Responses

    @Test("Unsupported function code returns illegal function exception")
    func unsupportedFunctionCode() async throws {
        let store = makeStore()

        let pdu: [UInt8] = [0x2B, 0x0E, 0x01, 0x00] // Device Identification (not supported)
        let frame = buildRequest(pdu: pdu)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, responsePdu) = try parseResponse(response)

        #expect(responsePdu[0] == 0x2B | 0x80) // FC + exception flag
        #expect(responsePdu[1] == 0x01)         // Illegal Function
    }

    @Test("Invalid unit ID returns slave device failure exception")
    func invalidUnitIdException() async throws {
        let store = makeStore() // Only unit 1

        let request = buildReadHoldingRegistersPDU(address: 0, count: 1)
        let frame = buildRequest(unitId: 99, pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        #expect(pdu[0] == 0x03 | 0x80) // FC 0x03 + exception flag
        #expect(pdu[1] == 0x04)         // Slave Device Failure
    }

    @Test("Out of bounds address returns illegal data address exception")
    func outOfBoundsException() async throws {
        let store = InMemoryDataStore(unitIds: [1], registerCount: 100)

        let request = buildReadHoldingRegistersPDU(address: 99, count: 2)
        let frame = buildRequest(pdu: request)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, pdu) = try parseResponse(response)

        #expect(pdu[0] == 0x03 | 0x80) // FC 0x03 + exception flag
        #expect(pdu[1] == 0x02)         // Illegal Data Address
    }

    @Test("Malformed PDU returns illegal data value exception")
    func malformedPduException() async throws {
        let store = makeStore()

        let pdu: [UInt8] = [0x03, 0x00] // FC 0x03 but too short
        let frame = buildRequest(pdu: pdu)

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        let (_, responsePdu) = try parseResponse(response)

        #expect(responsePdu[0] == 0x03 | 0x80) // FC + exception flag
        #expect(responsePdu[1] == 0x03)          // Illegal Data Value
    }

    @Test("Empty PDU returns empty response")
    func emptyPdu() async {
        let store = makeStore()

        let frame = buildRequest(pdu: [])

        let response = await ModbusServerHandler.processFrame(frame, dataStore: store, logger: nil)
        #expect(response.isEmpty)
    }

    @Test("Invalid MBAP header returns empty response")
    func invalidMbap() async {
        let store = makeStore()

        let response = await ModbusServerHandler.processFrame([0x00, 0x01], dataStore: store, logger: nil)
        #expect(response.isEmpty)
    }

    // MARK: - NIOEmbedded Pipeline Tests

    @Test("Server handler in NIO pipeline processes read request")
    func nioPipelineReadRegisters() throws {
        let store = InMemoryDataStore(unitIds: [1])
        let channel = EmbeddedChannel()
        try channel.pipeline.addHandlers([
            ByteToMessageHandler(ModbusFrameDecoder()),
            ModbusServerHandler(dataStore: store, logger: nil),
        ]).wait()
        defer { _ = try? channel.finish() }

        let request = buildReadHoldingRegistersPDU(address: 0, count: 1)
        let frame = buildModbusTCPADU(transactionId: 1, unitId: 1, pdu: request)

        var buffer = channel.allocator.buffer(capacity: frame.count)
        buffer.writeBytes(frame)
        try channel.writeInbound(buffer)

        // The handler writes the response asynchronously via a promise,
        // so we need to run the embedded event loop
        channel.embeddedEventLoop.run()
    }

    @Test("Server handler closes channel on error")
    func nioHandlerClosesOnError() throws {
        let store = InMemoryDataStore(unitIds: [1])
        let channel = EmbeddedChannel()
        try channel.pipeline.addHandler(
            ModbusServerHandler(dataStore: store, logger: nil)
        ).wait()

        struct TestError: Error {}
        channel.pipeline.fireErrorCaught(TestError())

        #expect(channel.isActive == false)
    }
}
