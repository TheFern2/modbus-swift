// SPDX-License-Identifier: Apache-2.0

@testable import ModbusCore
import Testing

/// Tests for server-side response PDU builders.
///
/// Each test builds a response PDU using the new server-side builder,
/// then parses it with the existing client-side parser to verify round-trip.
@Suite("Response PDU Builders")
struct ResponseBuilderTests {

    // MARK: - Read Registers Response (FC 0x03, 0x04)

    @Test("Build Read Holding Registers response")
    func buildReadHoldingRegistersResponse() throws {
        let registers: [UInt16] = [0x0001, 0x0002, 0x0003]
        let pdu = buildReadRegistersResponsePDU(
            functionCode: ModbusFunctionCode.readHoldingRegisters,
            registers: registers
        )

        let response = try parseReadRegistersPDU(pdu)
        #expect(response.functionCode == 0x03)
        #expect(response.registers == registers)
    }

    @Test("Build Read Input Registers response")
    func buildReadInputRegistersResponse() throws {
        let registers: [UInt16] = [0xABCD, 0x1234]
        let pdu = buildReadRegistersResponsePDU(
            functionCode: ModbusFunctionCode.readInputRegisters,
            registers: registers
        )

        let response = try parseReadRegistersPDU(pdu, expectedFunction: 0x04)
        #expect(response.functionCode == 0x04)
        #expect(response.registers == registers)
    }

    @Test("Build Read Registers response - single register")
    func buildReadRegistersResponseSingle() throws {
        let pdu = buildReadRegistersResponsePDU(
            functionCode: 0x03,
            registers: [0xFFFF]
        )

        #expect(pdu == [0x03, 0x02, 0xFF, 0xFF])
    }

    @Test("Build Read Registers response - raw bytes")
    func buildReadRegistersResponseRawBytes() {
        let pdu = buildReadRegistersResponsePDU(
            functionCode: 0x03,
            registers: [0x0001, 0x0002]
        )

        let expected: [UInt8] = [
            0x03,       // FC
            0x04,       // byte count = 2 * 2
            0x00, 0x01, // register 0
            0x00, 0x02, // register 1
        ]
        #expect(pdu == expected)
    }

    // MARK: - Read Bits Response (FC 0x01, 0x02)

    @Test("Build Read Coils response")
    func buildReadCoilsResponse() throws {
        let bits: [Bool] = [true, false, true, true, false, false, true, true, true, false]
        let pdu = buildReadBitsResponsePDU(
            functionCode: ModbusFunctionCode.readCoils,
            bits: bits
        )

        let response = try parseReadBitsPDU(pdu, expectedFunction: 0x01, requestedCount: 10)
        #expect(response.functionCode == 0x01)
        #expect(response.bits == bits)
    }

    @Test("Build Read Discrete Inputs response")
    func buildReadDiscreteInputsResponse() throws {
        let bits: [Bool] = [false, true, false, true]
        let pdu = buildReadBitsResponsePDU(
            functionCode: ModbusFunctionCode.readDiscreteInputs,
            bits: bits
        )

        let response = try parseReadBitsPDU(pdu, expectedFunction: 0x02, requestedCount: 4)
        #expect(response.functionCode == 0x02)
        #expect(response.bits == bits)
    }

    @Test("Build Read Coils response - raw bytes LSB-first packing")
    func buildReadCoilsResponseRawBytes() {
        let bits: [Bool] = [true, false, true, true, false, false, true, true, true, false]
        let pdu = buildReadBitsResponsePDU(functionCode: 0x01, bits: bits)

        let expected: [UInt8] = [
            0x01, // FC
            0x02, // byte count = ceil(10/8)
            0xCD, // 1100_1101
            0x01, // 0000_0001
        ]
        #expect(pdu == expected)
    }

    @Test("Build Read Coils response - single coil")
    func buildReadCoilsResponseSingle() throws {
        let pdu = buildReadBitsResponsePDU(functionCode: 0x01, bits: [true])

        let response = try parseReadBitsPDU(pdu, expectedFunction: 0x01, requestedCount: 1)
        #expect(response.bits == [true])
    }

    // MARK: - Write Single Register Response (FC 0x06)

    @Test("Build Write Single Register response")
    func buildWriteSingleRegisterResponse() throws {
        let pdu = buildWriteSingleRegisterResponsePDU(address: 0x0001, value: 0x0003)

        let response = try parseWriteSingleRegisterPDU(pdu)
        #expect(response.address == 0x0001)
        #expect(response.value == 0x0003)
    }

    @Test("Build Write Single Register response - raw bytes")
    func buildWriteSingleRegisterResponseRaw() {
        let pdu = buildWriteSingleRegisterResponsePDU(address: 0x0001, value: 0x0003)

        let expected: [UInt8] = [0x06, 0x00, 0x01, 0x00, 0x03]
        #expect(pdu == expected)
    }

    // MARK: - Write Multiple Registers Response (FC 0x10)

    @Test("Build Write Multiple Registers response")
    func buildWriteMultipleRegistersResponse() throws {
        let pdu = buildWriteMultipleRegistersResponsePDU(address: 0x0001, quantity: 2)

        let response = try parseWriteMultipleRegistersPDU(pdu)
        #expect(response.address == 0x0001)
        #expect(response.quantity == 2)
    }

    @Test("Build Write Multiple Registers response - raw bytes")
    func buildWriteMultipleRegistersResponseRaw() {
        let pdu = buildWriteMultipleRegistersResponsePDU(address: 0x0001, quantity: 10)

        let expected: [UInt8] = [0x10, 0x00, 0x01, 0x00, 0x0A]
        #expect(pdu == expected)
    }

    // MARK: - Write Single Coil Response (FC 0x05)

    @Test("Build Write Single Coil response - ON")
    func buildWriteSingleCoilResponseOn() throws {
        let pdu = buildWriteSingleCoilResponsePDU(address: 0x00AC, value: true)

        let response = try parseWriteSingleCoilPDU(pdu)
        #expect(response.address == 0x00AC)
        #expect(response.value == true)
    }

    @Test("Build Write Single Coil response - OFF")
    func buildWriteSingleCoilResponseOff() throws {
        let pdu = buildWriteSingleCoilResponsePDU(address: 0x00AC, value: false)

        let response = try parseWriteSingleCoilPDU(pdu)
        #expect(response.address == 0x00AC)
        #expect(response.value == false)
    }

    // MARK: - Write Multiple Coils Response (FC 0x0F)

    @Test("Build Write Multiple Coils response")
    func buildWriteMultipleCoilsResponse() throws {
        let pdu = buildWriteMultipleCoilsResponsePDU(address: 0x0013, quantity: 10)

        let response = try parseWriteMultipleCoilsPDU(pdu)
        #expect(response.address == 0x0013)
        #expect(response.quantity == 10)
    }

    // MARK: - Mask Write Register Response (FC 0x16)

    @Test("Build Mask Write Register response")
    func buildMaskWriteRegisterResponse() throws {
        let pdu = buildMaskWriteRegisterResponsePDU(
            address: 0x0004,
            andMask: 0x00F2,
            orMask: 0x0025
        )

        let response = try parseMaskWriteRegisterPDU(pdu)
        #expect(response.address == 0x0004)
        #expect(response.andMask == 0x00F2)
        #expect(response.orMask == 0x0025)
    }

    // MARK: - Read/Write Multiple Registers Response (FC 0x17)

    @Test("Build Read/Write Multiple Registers response")
    func buildReadWriteMultipleRegistersResponse() throws {
        let registers: [UInt16] = [0x00FE, 0x0ACD, 0x0001]
        let pdu = buildReadWriteMultipleRegistersResponsePDU(registers: registers)

        let response = try parseReadWriteMultipleRegistersPDU(pdu)
        #expect(response.registers == registers)
    }

    // MARK: - Exception Response

    @Test("Build exception response - Illegal Function")
    func buildExceptionIllegalFunction() {
        let pdu = buildExceptionResponsePDU(
            functionCode: 0x03,
            exception: .illegalFunction
        )

        #expect(pdu == [0x83, 0x01])
    }

    @Test("Build exception response - Illegal Data Address")
    func buildExceptionIllegalDataAddress() {
        let pdu = buildExceptionResponsePDU(
            functionCode: 0x10,
            exception: .illegalDataAddress
        )

        #expect(pdu == [0x90, 0x02])
    }

    @Test("Build exception response - Slave Device Failure")
    func buildExceptionSlaveDeviceFailure() {
        let pdu = buildExceptionResponsePDU(
            functionCode: 0x01,
            exception: .slaveDeviceFailure
        )

        #expect(pdu == [0x81, 0x04])
    }

    @Test("Exception response is parseable by client")
    func exceptionResponseParsedByClient() {
        let pdu = buildExceptionResponsePDU(
            functionCode: ModbusFunctionCode.readHoldingRegisters,
            exception: .illegalDataAddress
        )

        #expect(throws: PDUError.exceptionResponse(.illegalDataAddress)) {
            try parseReadRegistersPDU(pdu)
        }
    }

    // MARK: - Full Round-Trip Tests

    @Test("Request parse -> data store -> response build -> client parse (registers)")
    func fullRoundTripRegisters() throws {
        // Client builds request
        let requestPDU = buildReadHoldingRegistersPDU(address: 100, count: 3)

        // Server parses request
        let req = try parseReadRequestPDU(requestPDU)
        #expect(req.address == 100)
        #expect(req.count == 3)

        // Server builds response with simulated data
        let responsePDU = buildReadRegistersResponsePDU(
            functionCode: req.functionCode,
            registers: [0x0001, 0x0002, 0x0003]
        )

        // Client parses response
        let response = try parseReadRegistersPDU(responsePDU)
        #expect(response.registers == [1, 2, 3])
    }

    @Test("Request parse -> data store -> response build -> client parse (coils)")
    func fullRoundTripCoils() throws {
        let requestPDU = buildReadCoilsPDU(address: 0, count: 4)

        let req = try parseReadRequestPDU(requestPDU)
        #expect(req.address == 0)
        #expect(req.count == 4)

        let responsePDU = buildReadBitsResponsePDU(
            functionCode: req.functionCode,
            bits: [true, false, true, false]
        )

        let response = try parseReadBitsPDU(
            responsePDU,
            expectedFunction: 0x01,
            requestedCount: 4
        )
        #expect(response.bits == [true, false, true, false])
    }

    @Test("Write request parse -> response build -> client parse (multiple registers)")
    func fullRoundTripWriteMultipleRegisters() throws {
        let requestPDU = buildWriteMultipleRegistersPDU(
            address: 0x0010,
            values: [0xAAAA, 0xBBBB]
        )

        let req = try parseWriteMultipleRegistersRequestPDU(requestPDU)
        #expect(req.address == 0x0010)
        #expect(req.values == [0xAAAA, 0xBBBB])

        let responsePDU = buildWriteMultipleRegistersResponsePDU(
            address: req.address,
            quantity: UInt16(req.values.count)
        )

        let response = try parseWriteMultipleRegistersPDU(responsePDU)
        #expect(response.address == 0x0010)
        #expect(response.quantity == 2)
    }
}
