// SPDX-License-Identifier: Apache-2.0

@testable import ModbusKit
import Testing

@Suite("InMemoryDataStore")
struct DataStoreTests {

    // MARK: - Holding Registers

    @Test("Read holding registers returns seeded values")
    func readHoldingRegisters() async throws {
        let store = InMemoryDataStore(unitIds: [1])
        await store.setHoldingRegisters(unitId: 1, address: 0, values: [0x1234, 0x5678, 0x9ABC])

        let result = try await store.readHoldingRegisters(unitId: 1, address: 0, count: 3)
        #expect(result == [0x1234, 0x5678, 0x9ABC])
    }

    @Test("Read holding registers returns zeros by default")
    func readHoldingRegistersDefault() async throws {
        let store = InMemoryDataStore(unitIds: [1])

        let result = try await store.readHoldingRegisters(unitId: 1, address: 100, count: 3)
        #expect(result == [0, 0, 0])
    }

    @Test("Write single register persists value")
    func writeSingleRegister() async throws {
        let store = InMemoryDataStore(unitIds: [1])

        try await store.writeSingleRegister(unitId: 1, address: 10, value: 0xABCD)
        let result = try await store.readHoldingRegisters(unitId: 1, address: 10, count: 1)
        #expect(result == [0xABCD])
    }

    @Test("Write multiple registers persists values")
    func writeMultipleRegisters() async throws {
        let store = InMemoryDataStore(unitIds: [1])

        try await store.writeMultipleRegisters(unitId: 1, address: 0, values: [0x0001, 0x0002, 0x0003])
        let result = try await store.readHoldingRegisters(unitId: 1, address: 0, count: 3)
        #expect(result == [0x0001, 0x0002, 0x0003])
    }

    @Test("Write single register overwrites previous value")
    func writeSingleRegisterOverwrite() async throws {
        let store = InMemoryDataStore(unitIds: [1])

        try await store.writeSingleRegister(unitId: 1, address: 5, value: 0x1111)
        try await store.writeSingleRegister(unitId: 1, address: 5, value: 0x2222)
        let result = try await store.readHoldingRegisters(unitId: 1, address: 5, count: 1)
        #expect(result == [0x2222])
    }

    // MARK: - Input Registers

    @Test("Read input registers returns seeded values")
    func readInputRegisters() async throws {
        let store = InMemoryDataStore(unitIds: [1])
        await store.setInputRegisters(unitId: 1, address: 0, values: [0xAAAA, 0xBBBB])

        let result = try await store.readInputRegisters(unitId: 1, address: 0, count: 2)
        #expect(result == [0xAAAA, 0xBBBB])
    }

    // MARK: - Coils

    @Test("Read coils returns seeded values")
    func readCoils() async throws {
        let store = InMemoryDataStore(unitIds: [1])
        await store.setCoils(unitId: 1, address: 0, values: [true, false, true, true])

        let result = try await store.readCoils(unitId: 1, address: 0, count: 4)
        #expect(result == [true, false, true, true])
    }

    @Test("Read coils returns false by default")
    func readCoilsDefault() async throws {
        let store = InMemoryDataStore(unitIds: [1])

        let result = try await store.readCoils(unitId: 1, address: 0, count: 3)
        #expect(result == [false, false, false])
    }

    @Test("Write single coil persists value")
    func writeSingleCoil() async throws {
        let store = InMemoryDataStore(unitIds: [1])

        try await store.writeSingleCoil(unitId: 1, address: 5, value: true)
        let result = try await store.readCoils(unitId: 1, address: 5, count: 1)
        #expect(result == [true])
    }

    @Test("Write multiple coils persists values")
    func writeMultipleCoils() async throws {
        let store = InMemoryDataStore(unitIds: [1])

        try await store.writeMultipleCoils(unitId: 1, address: 0, values: [true, false, true])
        let result = try await store.readCoils(unitId: 1, address: 0, count: 3)
        #expect(result == [true, false, true])
    }

    // MARK: - Discrete Inputs

    @Test("Read discrete inputs returns seeded values")
    func readDiscreteInputs() async throws {
        let store = InMemoryDataStore(unitIds: [1])
        await store.setDiscreteInputs(unitId: 1, address: 0, values: [false, true, true])

        let result = try await store.readDiscreteInputs(unitId: 1, address: 0, count: 3)
        #expect(result == [false, true, true])
    }

    // MARK: - Mask Write Register (FC 0x16)

    @Test("Mask write applies AND then OR mask")
    func maskWriteRegister() async throws {
        let store = InMemoryDataStore(unitIds: [1])
        await store.setHoldingRegisters(unitId: 1, address: 4, values: [0x0012])

        // Result = (0x0012 & 0x00F2) | 0x0025 = 0x0012 | 0x0025 = 0x0037
        try await store.maskWriteRegister(unitId: 1, address: 4, andMask: 0x00F2, orMask: 0x0025)
        let result = try await store.readHoldingRegisters(unitId: 1, address: 4, count: 1)
        #expect(result == [0x0037])
    }

    @Test("Mask write with all-ones AND preserves value then applies OR")
    func maskWriteRegisterIdentityAnd() async throws {
        let store = InMemoryDataStore(unitIds: [1])
        await store.setHoldingRegisters(unitId: 1, address: 0, values: [0xFF00])

        // (0xFF00 & 0xFFFF) | 0x00FF = 0xFFFF
        try await store.maskWriteRegister(unitId: 1, address: 0, andMask: 0xFFFF, orMask: 0x00FF)
        let result = try await store.readHoldingRegisters(unitId: 1, address: 0, count: 1)
        #expect(result == [0xFFFF])
    }

    // MARK: - Read/Write Multiple Registers (FC 0x17)

    @Test("Read/Write writes first then reads")
    func readWriteMultipleRegisters() async throws {
        let store = InMemoryDataStore(unitIds: [1])

        let result = try await store.readWriteMultipleRegisters(
            unitId: 1,
            readAddress: 0,
            readCount: 2,
            writeAddress: 0,
            writeValues: [0x00AA, 0x00BB]
        )
        #expect(result == [0x00AA, 0x00BB])
    }

    @Test("Read/Write reads updated values after write")
    func readWriteReadsUpdated() async throws {
        let store = InMemoryDataStore(unitIds: [1])
        await store.setHoldingRegisters(unitId: 1, address: 10, values: [0x1111, 0x2222])

        let result = try await store.readWriteMultipleRegisters(
            unitId: 1,
            readAddress: 10,
            readCount: 2,
            writeAddress: 10,
            writeValues: [0x3333, 0x4444]
        )
        #expect(result == [0x3333, 0x4444])
    }

    @Test("Read/Write with non-overlapping addresses")
    func readWriteNonOverlapping() async throws {
        let store = InMemoryDataStore(unitIds: [1])
        await store.setHoldingRegisters(unitId: 1, address: 0, values: [0xAAAA])

        let result = try await store.readWriteMultipleRegisters(
            unitId: 1,
            readAddress: 0,
            readCount: 1,
            writeAddress: 10,
            writeValues: [0xBBBB]
        )
        #expect(result == [0xAAAA])

        let written = try await store.readHoldingRegisters(unitId: 1, address: 10, count: 1)
        #expect(written == [0xBBBB])
    }

    // MARK: - Error Cases

    @Test("Invalid unit ID throws slaveDeviceFailure")
    func invalidUnitId() async {
        let store = InMemoryDataStore(unitIds: [1])

        await #expect(throws: ModbusServerError.slaveDeviceFailure) {
            try await store.readHoldingRegisters(unitId: 99, address: 0, count: 1)
        }
    }

    @Test("Read past register bounds throws illegalDataAddress")
    func readPastBounds() async {
        let store = InMemoryDataStore(unitIds: [1], registerCount: 100)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.readHoldingRegisters(unitId: 1, address: 99, count: 2)
        }
    }

    @Test("Write past register bounds throws illegalDataAddress")
    func writePastBounds() async {
        let store = InMemoryDataStore(unitIds: [1], registerCount: 100)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.writeSingleRegister(unitId: 1, address: 100, value: 1)
        }
    }

    @Test("Write multiple registers past bounds throws illegalDataAddress")
    func writeMultiplePastBounds() async {
        let store = InMemoryDataStore(unitIds: [1], registerCount: 100)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.writeMultipleRegisters(unitId: 1, address: 99, values: [1, 2])
        }
    }

    @Test("Write single coil past bounds throws illegalDataAddress")
    func writeCoilPastBounds() async {
        let store = InMemoryDataStore(unitIds: [1], coilCount: 100)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.writeSingleCoil(unitId: 1, address: 100, value: true)
        }
    }

    @Test("Write multiple coils past bounds throws illegalDataAddress")
    func writeMultipleCoilsPastBounds() async {
        let store = InMemoryDataStore(unitIds: [1], coilCount: 100)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.writeMultipleCoils(unitId: 1, address: 99, values: [true, true])
        }
    }

    @Test("Read coils past bounds throws illegalDataAddress")
    func readCoilsPastBounds() async {
        let store = InMemoryDataStore(unitIds: [1], coilCount: 100)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.readCoils(unitId: 1, address: 99, count: 2)
        }
    }

    @Test("Mask write past bounds throws illegalDataAddress")
    func maskWritePastBounds() async {
        let store = InMemoryDataStore(unitIds: [1], registerCount: 100)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.maskWriteRegister(unitId: 1, address: 100, andMask: 0xFFFF, orMask: 0)
        }
    }

    @Test("Read/Write registers - write past bounds throws illegalDataAddress")
    func readWritePastWriteBounds() async {
        let store = InMemoryDataStore(unitIds: [1], registerCount: 100)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.readWriteMultipleRegisters(
                unitId: 1,
                readAddress: 0, readCount: 1,
                writeAddress: 99, writeValues: [1, 2]
            )
        }
    }

    // MARK: - Multi-Unit Support

    @Test("Multiple unit IDs are independent")
    func multipleUnits() async throws {
        let store = InMemoryDataStore(unitIds: [1, 2])

        try await store.writeSingleRegister(unitId: 1, address: 0, value: 0x1111)
        try await store.writeSingleRegister(unitId: 2, address: 0, value: 0x2222)

        let unit1 = try await store.readHoldingRegisters(unitId: 1, address: 0, count: 1)
        let unit2 = try await store.readHoldingRegisters(unitId: 2, address: 0, count: 1)

        #expect(unit1 == [0x1111])
        #expect(unit2 == [0x2222])
    }

    @Test("Custom address space sizes")
    func customSizes() async throws {
        let store = InMemoryDataStore(unitIds: [1], registerCount: 10, coilCount: 8)

        try await store.writeSingleRegister(unitId: 1, address: 9, value: 0xFFFF)
        try await store.writeSingleCoil(unitId: 1, address: 7, value: true)

        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.writeSingleRegister(unitId: 1, address: 10, value: 1)
        }
        await #expect(throws: ModbusServerError.illegalDataAddress) {
            try await store.writeSingleCoil(unitId: 1, address: 8, value: true)
        }
    }
}
