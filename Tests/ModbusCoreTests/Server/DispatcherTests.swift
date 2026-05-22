// SPDX-License-Identifier: Apache-2.0

@testable import ModbusCore
import Testing

@Suite("dispatchModbusRequest")
struct DispatcherTests {

    // MARK: - Helpers

    private func makeStore(unitIds: Set<UInt8> = [1]) -> InMemoryDataStore {
        InMemoryDataStore(unitIds: unitIds)
    }

    // MARK: - FC 0x03: Read Holding Registers

    @Test("Dispatches read holding registers")
    func readHoldingRegisters() async throws {
        let store = makeStore()
        await store.setHoldingRegisters(unitId: 1, address: 0, values: [0x1234, 0x5678])

        let pdu = buildReadHoldingRegistersPDU(address: 0, count: 2)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.readHoldingRegisters,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseReadRegistersPDU(response)
        #expect(parsed.registers == [0x1234, 0x5678])
    }

    // MARK: - FC 0x04: Read Input Registers

    @Test("Dispatches read input registers")
    func readInputRegisters() async throws {
        let store = makeStore()
        await store.setInputRegisters(unitId: 1, address: 0, values: [0xAAAA])

        let pdu = buildReadInputRegistersPDU(address: 0, count: 1)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.readInputRegisters,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseReadRegistersPDU(response, expectedFunction: 0x04)
        #expect(parsed.registers == [0xAAAA])
    }

    // MARK: - FC 0x01: Read Coils

    @Test("Dispatches read coils")
    func readCoils() async throws {
        let store = makeStore()
        await store.setCoils(unitId: 1, address: 0, values: [true, false, true])

        let pdu = buildReadCoilsPDU(address: 0, count: 3)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.readCoils,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseReadBitsPDU(response, expectedFunction: 0x01, requestedCount: 3)
        #expect(parsed.bits == [true, false, true])
    }

    // MARK: - FC 0x02: Read Discrete Inputs

    @Test("Dispatches read discrete inputs")
    func readDiscreteInputs() async throws {
        let store = makeStore()
        await store.setDiscreteInputs(unitId: 1, address: 0, values: [false, true])

        let pdu = buildReadDiscreteInputsPDU(address: 0, count: 2)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.readDiscreteInputs,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseReadBitsPDU(response, expectedFunction: 0x02, requestedCount: 2)
        #expect(parsed.bits == [false, true])
    }

    // MARK: - FC 0x06: Write Single Register

    @Test("Dispatches write single register")
    func writeSingleRegister() async throws {
        let store = makeStore()

        let pdu = buildWriteSingleRegisterPDU(address: 5, value: 0xBEEF)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.writeSingleRegister,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseWriteSingleRegisterPDU(response)
        #expect(parsed.address == 5)
        #expect(parsed.value == 0xBEEF)

        let stored = try await store.readHoldingRegisters(unitId: 1, address: 5, count: 1)
        #expect(stored == [0xBEEF])
    }

    // MARK: - FC 0x05: Write Single Coil

    @Test("Dispatches write single coil")
    func writeSingleCoil() async throws {
        let store = makeStore()

        let pdu = buildWriteSingleCoilPDU(address: 10, value: true)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.writeSingleCoil,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseWriteSingleCoilPDU(response)
        #expect(parsed.address == 10)
        #expect(parsed.value == true)
    }

    // MARK: - FC 0x10: Write Multiple Registers

    @Test("Dispatches write multiple registers")
    func writeMultipleRegisters() async throws {
        let store = makeStore()

        let values: [UInt16] = [0x000A, 0x000B]
        let pdu = buildWriteMultipleRegistersPDU(address: 0, values: values)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.writeMultipleRegisters,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseWriteMultipleRegistersPDU(response)
        #expect(parsed.address == 0)
        #expect(parsed.quantity == 2)
    }

    // MARK: - FC 0x0F: Write Multiple Coils

    @Test("Dispatches write multiple coils")
    func writeMultipleCoils() async throws {
        let store = makeStore()

        let coils: [Bool] = [true, false, true]
        let pdu = buildWriteMultipleCoilsPDU(address: 0, values: coils)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.writeMultipleCoils,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseWriteMultipleCoilsPDU(response)
        #expect(parsed.address == 0)
        #expect(parsed.quantity == 3)
    }

    // MARK: - FC 0x16: Mask Write Register

    @Test("Dispatches mask write register")
    func maskWriteRegister() async throws {
        let store = makeStore()
        await store.setHoldingRegisters(unitId: 1, address: 4, values: [0x0012])

        let pdu = buildMaskWriteRegisterPDU(address: 4, andMask: 0x00F2, orMask: 0x0025)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.maskWriteRegister,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseMaskWriteRegisterPDU(response)
        #expect(parsed.address == 4)
        #expect(parsed.andMask == 0x00F2)
        #expect(parsed.orMask == 0x0025)
    }

    // MARK: - FC 0x17: Read/Write Multiple Registers

    @Test("Dispatches read/write multiple registers")
    func readWriteMultipleRegisters() async throws {
        let store = makeStore()
        await store.setHoldingRegisters(unitId: 1, address: 0, values: [0x0001, 0x0002])

        let pdu = buildReadWriteMultipleRegistersPDU(
            readAddress: 0, readCount: 2,
            writeAddress: 10, writeValues: [0x00FF],
        )
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.readWriteMultipleRegisters,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        let parsed = try parseReadWriteMultipleRegistersPDU(response)
        #expect(parsed.registers == [0x0001, 0x0002])
    }

    // MARK: - Exception Responses

    @Test("Unsupported function code returns illegal function exception")
    func unsupportedFunctionCode() async {
        let store = makeStore()

        let pdu: [UInt8] = [0x2B, 0x0E, 0x01, 0x00]
        let response = await dispatchModbusRequest(
            functionCode: 0x2B, pdu: pdu, unitId: 1, dataStore: store,
        )

        #expect(response[0] == 0x2B | 0x80)
        #expect(response[1] == 0x01)
    }

    @Test("Invalid unit ID returns slave device failure")
    func invalidUnitId() async {
        let store = makeStore()

        let pdu = buildReadHoldingRegistersPDU(address: 0, count: 1)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.readHoldingRegisters,
            pdu: pdu, unitId: 99, dataStore: store,
        )

        #expect(response[0] == 0x03 | 0x80)
        #expect(response[1] == 0x04)
    }

    @Test("Out of bounds address returns illegal data address")
    func outOfBounds() async {
        let store = InMemoryDataStore(unitIds: [1], registerCount: 100)

        let pdu = buildReadHoldingRegistersPDU(address: 99, count: 2)
        let response = await dispatchModbusRequest(
            functionCode: ModbusFunctionCode.readHoldingRegisters,
            pdu: pdu, unitId: 1, dataStore: store,
        )

        #expect(response[0] == 0x03 | 0x80)
        #expect(response[1] == 0x02)
    }

    @Test("Malformed PDU returns illegal data value")
    func malformedPdu() async {
        let store = makeStore()

        let pdu: [UInt8] = [0x03, 0x00]
        let response = await dispatchModbusRequest(
            functionCode: 0x03, pdu: pdu, unitId: 1, dataStore: store,
        )

        #expect(response[0] == 0x03 | 0x80)
        #expect(response[1] == 0x03)
    }

    @Test("Log handler receives messages on error")
    func logHandlerCalled() async {
        let store = makeStore()
        var logged = false

        let pdu: [UInt8] = [0x03, 0x00]
        _ = await dispatchModbusRequest(
            functionCode: 0x03, pdu: pdu, unitId: 1, dataStore: store,
            logHandler: { _ in logged = true },
        )

        #expect(logged)
    }
}
