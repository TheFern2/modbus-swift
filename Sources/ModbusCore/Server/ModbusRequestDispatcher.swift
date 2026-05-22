// SPDX-License-Identifier: Apache-2.0

// MARK: - Request Dispatcher

/// Dispatches a Modbus request PDU to the appropriate handler and returns the response PDU.
///
/// Shared by both TCP and RTU server implementations. Handles all supported
/// function codes and returns exception responses for errors.
///
/// - Parameters:
///   - functionCode: Modbus function code from the request
///   - pdu: Full request PDU (including function code byte)
///   - unitId: Unit identifier from the request frame
///   - dataStore: Data store for register/coil values
///   - logHandler: Optional closure for debug/warning messages
/// - Returns: Response PDU bytes
public func dispatchModbusRequest(
    functionCode: UInt8,
    pdu: [UInt8],
    unitId: UInt8,
    dataStore: any ModbusDataStore,
    logHandler: ((String) -> Void)? = nil,
) async -> [UInt8] {
    do {
        switch functionCode {
        case ModbusFunctionCode.readCoils:
            let req = try parseReadRequestPDU(pdu)
            let bits = try await dataStore.readCoils(unitId: unitId, address: req.address, count: req.count)
            return buildReadBitsResponsePDU(functionCode: ModbusFunctionCode.readCoils, bits: bits)

        case ModbusFunctionCode.readDiscreteInputs:
            let req = try parseReadRequestPDU(pdu)
            let bits = try await dataStore.readDiscreteInputs(unitId: unitId, address: req.address, count: req.count)
            return buildReadBitsResponsePDU(functionCode: ModbusFunctionCode.readDiscreteInputs, bits: bits)

        case ModbusFunctionCode.readHoldingRegisters:
            let req = try parseReadRequestPDU(pdu)
            let regs = try await dataStore.readHoldingRegisters(unitId: unitId, address: req.address, count: req.count)
            return buildReadRegistersResponsePDU(
                functionCode: ModbusFunctionCode.readHoldingRegisters,
                registers: regs,
            )

        case ModbusFunctionCode.readInputRegisters:
            let req = try parseReadRequestPDU(pdu)
            let regs = try await dataStore.readInputRegisters(unitId: unitId, address: req.address, count: req.count)
            return buildReadRegistersResponsePDU(
                functionCode: ModbusFunctionCode.readInputRegisters,
                registers: regs,
            )

        case ModbusFunctionCode.writeSingleCoil:
            let req = try parseWriteSingleCoilRequestPDU(pdu)
            try await dataStore.writeSingleCoil(unitId: unitId, address: req.address, value: req.value)
            return buildWriteSingleCoilResponsePDU(address: req.address, value: req.value)

        case ModbusFunctionCode.writeSingleRegister:
            let req = try parseWriteSingleRegisterRequestPDU(pdu)
            try await dataStore.writeSingleRegister(unitId: unitId, address: req.address, value: req.value)
            return buildWriteSingleRegisterResponsePDU(address: req.address, value: req.value)

        case ModbusFunctionCode.writeMultipleCoils:
            let req = try parseWriteMultipleCoilsRequestPDU(pdu)
            try await dataStore.writeMultipleCoils(unitId: unitId, address: req.address, values: req.values)
            return buildWriteMultipleCoilsResponsePDU(address: req.address, quantity: UInt16(req.values.count))

        case ModbusFunctionCode.writeMultipleRegisters:
            let req = try parseWriteMultipleRegistersRequestPDU(pdu)
            try await dataStore.writeMultipleRegisters(unitId: unitId, address: req.address, values: req.values)
            return buildWriteMultipleRegistersResponsePDU(address: req.address, quantity: UInt16(req.values.count))

        case ModbusFunctionCode.maskWriteRegister:
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

        case ModbusFunctionCode.readWriteMultipleRegisters:
            let req = try parseReadWriteMultipleRegistersRequestPDU(pdu)
            let regs = try await dataStore.readWriteMultipleRegisters(
                unitId: unitId,
                readAddress: req.readAddress,
                readCount: req.readCount,
                writeAddress: req.writeAddress,
                writeValues: req.writeValues,
            )
            return buildReadWriteMultipleRegistersResponsePDU(registers: regs)

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
        logHandler?("PDU parse error for FC 0x\(String(functionCode, radix: 16)): \(error)")
        return buildExceptionResponsePDU(
            functionCode: functionCode,
            exception: .illegalDataValue,
        )
    } catch {
        logHandler?("Unexpected error for FC 0x\(String(functionCode, radix: 16)): \(error)")
        return buildExceptionResponsePDU(
            functionCode: functionCode,
            exception: .slaveDeviceFailure,
        )
    }
}
