// SPDX-License-Identifier: Apache-2.0

// MARK: - ModbusDataStore

/// Protocol for Modbus server data storage.
///
/// Async to support backing stores beyond in-memory: databases, hardware I/O,
/// forwarding proxies. The default `InMemoryDataStore` actor handles the common
/// simulation and testing case.
public protocol ModbusDataStore: Sendable {
    func readHoldingRegisters(unitId: UInt8, address: UInt16, count: UInt16)
        async throws(ModbusServerError) -> [UInt16]

    func readInputRegisters(unitId: UInt8, address: UInt16, count: UInt16)
        async throws(ModbusServerError) -> [UInt16]

    func writeSingleRegister(unitId: UInt8, address: UInt16, value: UInt16)
        async throws(ModbusServerError)

    func writeMultipleRegisters(unitId: UInt8, address: UInt16, values: [UInt16])
        async throws(ModbusServerError)

    func readCoils(unitId: UInt8, address: UInt16, count: UInt16)
        async throws(ModbusServerError) -> [Bool]

    func readDiscreteInputs(unitId: UInt8, address: UInt16, count: UInt16)
        async throws(ModbusServerError) -> [Bool]

    func writeSingleCoil(unitId: UInt8, address: UInt16, value: Bool)
        async throws(ModbusServerError)

    func writeMultipleCoils(unitId: UInt8, address: UInt16, values: [Bool])
        async throws(ModbusServerError)

    func maskWriteRegister(unitId: UInt8, address: UInt16, andMask: UInt16, orMask: UInt16)
        async throws(ModbusServerError)

    func readWriteMultipleRegisters(
        unitId: UInt8,
        readAddress: UInt16, readCount: UInt16,
        writeAddress: UInt16, writeValues: [UInt16]
    ) async throws(ModbusServerError) -> [UInt16]
}

// MARK: - UnitData

/// Per-unit address space storage.
public struct UnitData: Sendable {
    public var holdingRegisters: [UInt16]
    public var inputRegisters: [UInt16]
    public var coils: [Bool]
    public var discreteInputs: [Bool]

    public init(registerCount: Int, coilCount: Int) {
        holdingRegisters = [UInt16](repeating: 0, count: registerCount)
        inputRegisters = [UInt16](repeating: 0, count: registerCount)
        coils = [Bool](repeating: false, count: coilCount)
        discreteInputs = [Bool](repeating: false, count: coilCount)
    }
}

// MARK: - InMemoryDataStore

/// In-memory Modbus data store backed by an actor.
///
/// Provides configurable address spaces per unit ID. Suitable for
/// simulation, testing, and simple server applications.
public actor InMemoryDataStore: ModbusDataStore {

    private var units: [UInt8: UnitData]
    private let registerCount: Int
    private let coilCount: Int

    /// Creates an in-memory data store.
    ///
    /// - Parameters:
    ///   - unitIds: Set of unit IDs to pre-allocate (default: [1])
    ///   - registerCount: Number of registers per address space (default: 65536)
    ///   - coilCount: Number of coils per address space (default: 65536)
    public init(
        unitIds: Set<UInt8> = [1],
        registerCount: Int = 65536,
        coilCount: Int = 65536
    ) {
        self.registerCount = registerCount
        self.coilCount = coilCount
        var units = [UInt8: UnitData]()
        for id in unitIds {
            units[id] = UnitData(registerCount: registerCount, coilCount: coilCount)
        }
        self.units = units
    }

    // MARK: - Direct Access (for test setup / programmatic seeding)

    /// Sets holding register values starting at an address.
    public func setHoldingRegisters(unitId: UInt8, address: UInt16, values: [UInt16]) {
        guard var unit = units[unitId] else { return }
        let start = Int(address)
        for (i, v) in values.enumerated() where start + i < unit.holdingRegisters.count {
            unit.holdingRegisters[start + i] = v
        }
        units[unitId] = unit
    }

    /// Sets input register values starting at an address.
    public func setInputRegisters(unitId: UInt8, address: UInt16, values: [UInt16]) {
        guard var unit = units[unitId] else { return }
        let start = Int(address)
        for (i, v) in values.enumerated() where start + i < unit.inputRegisters.count {
            unit.inputRegisters[start + i] = v
        }
        units[unitId] = unit
    }

    /// Sets coil values starting at an address.
    public func setCoils(unitId: UInt8, address: UInt16, values: [Bool]) {
        guard var unit = units[unitId] else { return }
        let start = Int(address)
        for (i, v) in values.enumerated() where start + i < unit.coils.count {
            unit.coils[start + i] = v
        }
        units[unitId] = unit
    }

    /// Sets discrete input values starting at an address.
    public func setDiscreteInputs(unitId: UInt8, address: UInt16, values: [Bool]) {
        guard var unit = units[unitId] else { return }
        let start = Int(address)
        for (i, v) in values.enumerated() where start + i < unit.discreteInputs.count {
            unit.discreteInputs[start + i] = v
        }
        units[unitId] = unit
    }

    // MARK: - ModbusDataStore

    public func readHoldingRegisters(
        unitId: UInt8, address: UInt16, count: UInt16
    ) throws(ModbusServerError) -> [UInt16] {
        let unit = try resolveUnit(unitId)
        return try readSlice(from: unit.holdingRegisters, address: address, count: count)
    }

    public func readInputRegisters(
        unitId: UInt8, address: UInt16, count: UInt16
    ) throws(ModbusServerError) -> [UInt16] {
        let unit = try resolveUnit(unitId)
        return try readSlice(from: unit.inputRegisters, address: address, count: count)
    }

    public func writeSingleRegister(
        unitId: UInt8, address: UInt16, value: UInt16
    ) throws(ModbusServerError) {
        var unit = try resolveUnit(unitId)
        let idx = Int(address)
        guard idx < unit.holdingRegisters.count else {
            throw .illegalDataAddress
        }
        unit.holdingRegisters[idx] = value
        units[unitId] = unit
    }

    public func writeMultipleRegisters(
        unitId: UInt8, address: UInt16, values: [UInt16]
    ) throws(ModbusServerError) {
        var unit = try resolveUnit(unitId)
        let start = Int(address)
        guard start + values.count <= unit.holdingRegisters.count else {
            throw .illegalDataAddress
        }
        for (i, v) in values.enumerated() {
            unit.holdingRegisters[start + i] = v
        }
        units[unitId] = unit
    }

    public func readCoils(
        unitId: UInt8, address: UInt16, count: UInt16
    ) throws(ModbusServerError) -> [Bool] {
        let unit = try resolveUnit(unitId)
        return try readSlice(from: unit.coils, address: address, count: count)
    }

    public func readDiscreteInputs(
        unitId: UInt8, address: UInt16, count: UInt16
    ) throws(ModbusServerError) -> [Bool] {
        let unit = try resolveUnit(unitId)
        return try readSlice(from: unit.discreteInputs, address: address, count: count)
    }

    public func writeSingleCoil(
        unitId: UInt8, address: UInt16, value: Bool
    ) throws(ModbusServerError) {
        var unit = try resolveUnit(unitId)
        let idx = Int(address)
        guard idx < unit.coils.count else {
            throw .illegalDataAddress
        }
        unit.coils[idx] = value
        units[unitId] = unit
    }

    public func writeMultipleCoils(
        unitId: UInt8, address: UInt16, values: [Bool]
    ) throws(ModbusServerError) {
        var unit = try resolveUnit(unitId)
        let start = Int(address)
        guard start + values.count <= unit.coils.count else {
            throw .illegalDataAddress
        }
        for (i, v) in values.enumerated() {
            unit.coils[start + i] = v
        }
        units[unitId] = unit
    }

    public func maskWriteRegister(
        unitId: UInt8, address: UInt16, andMask: UInt16, orMask: UInt16
    ) throws(ModbusServerError) {
        var unit = try resolveUnit(unitId)
        let idx = Int(address)
        guard idx < unit.holdingRegisters.count else {
            throw .illegalDataAddress
        }
        let current = unit.holdingRegisters[idx]
        unit.holdingRegisters[idx] = (current & andMask) | orMask
        units[unitId] = unit
    }

    public func readWriteMultipleRegisters(
        unitId: UInt8,
        readAddress: UInt16, readCount: UInt16,
        writeAddress: UInt16, writeValues: [UInt16]
    ) throws(ModbusServerError) -> [UInt16] {
        var unit = try resolveUnit(unitId)

        // Write first (per Modbus spec)
        let writeStart = Int(writeAddress)
        guard writeStart + writeValues.count <= unit.holdingRegisters.count else {
            throw .illegalDataAddress
        }
        for (i, v) in writeValues.enumerated() {
            unit.holdingRegisters[writeStart + i] = v
        }
        units[unitId] = unit

        // Then read
        return try readSlice(from: unit.holdingRegisters, address: readAddress, count: readCount)
    }

    // MARK: - Private

    private func resolveUnit(_ unitId: UInt8) throws(ModbusServerError) -> UnitData {
        guard let unit = units[unitId] else {
            throw .slaveDeviceFailure
        }
        return unit
    }

    private func readSlice<T>(
        from array: [T], address: UInt16, count: UInt16
    ) throws(ModbusServerError) -> [T] {
        let start = Int(address)
        let end = start + Int(count)
        guard end <= array.count else {
            throw .illegalDataAddress
        }
        return Array(array[start ..< end])
    }
}
