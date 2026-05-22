// SPDX-License-Identifier: Apache-2.0

@testable import ModbusCore
import Testing

/// Tests for server-side request PDU parsers.
///
/// Each test builds a request PDU using the existing client-side builder,
/// then parses it with the new server-side parser to verify round-trip.
@Suite("Request PDU Parsers")
struct RequestParserTests {

    // MARK: - Read Request Parser (FC 0x01-0x04)

    @Test("Parse Read Holding Registers request")
    func parseReadHoldingRegisters() throws {
        let pdu = buildReadHoldingRegistersPDU(address: 0x006B, count: 3)
        let req = try parseReadRequestPDU(pdu)

        #expect(req.functionCode == 0x03)
        #expect(req.address == 0x006B)
        #expect(req.count == 3)
    }

    @Test("Parse Read Input Registers request")
    func parseReadInputRegisters() throws {
        let pdu = buildReadInputRegistersPDU(address: 0, count: 10)
        let req = try parseReadRequestPDU(pdu)

        #expect(req.functionCode == 0x04)
        #expect(req.address == 0)
        #expect(req.count == 10)
    }

    @Test("Parse Read Coils request")
    func parseReadCoils() throws {
        let pdu = buildReadCoilsPDU(address: 0x0013, count: 25)
        let req = try parseReadRequestPDU(pdu)

        #expect(req.functionCode == 0x01)
        #expect(req.address == 0x0013)
        #expect(req.count == 25)
    }

    @Test("Parse Read Discrete Inputs request")
    func parseReadDiscreteInputs() throws {
        let pdu = buildReadDiscreteInputsPDU(address: 0x00C4, count: 22)
        let req = try parseReadRequestPDU(pdu)

        #expect(req.functionCode == 0x02)
        #expect(req.address == 0x00C4)
        #expect(req.count == 22)
    }

    @Test("Parse Read request - max address and count")
    func parseReadRequestMax() throws {
        let pdu = buildReadHoldingRegistersPDU(address: 0xFFFF, count: 125)
        let req = try parseReadRequestPDU(pdu)

        #expect(req.address == 0xFFFF)
        #expect(req.count == 125)
    }

    @Test("Parse Read request - PDU too short")
    func parseReadRequestTooShort() {
        let pdu: [UInt8] = [0x03, 0x00, 0x6B] // Only 3 bytes

        #expect(throws: PDUError.pduTooShort) {
            try parseReadRequestPDU(pdu)
        }
    }

    @Test("Parse Read request - empty")
    func parseReadRequestEmpty() {
        #expect(throws: PDUError.pduTooShort) {
            try parseReadRequestPDU([UInt8]())
        }
    }

    @Test("Parse Read request from raw bytes")
    func parseReadRequestRaw() throws {
        let pdu: [UInt8] = [0x03, 0x00, 0x6B, 0x00, 0x03]
        let req = try parseReadRequestPDU(pdu)

        #expect(req.functionCode == 0x03)
        #expect(req.address == 0x006B)
        #expect(req.count == 3)
    }

    // MARK: - Write Single Register Request Parser (FC 0x06)

    @Test("Parse Write Single Register request")
    func parseWriteSingleRegister() throws {
        let pdu = buildWriteSingleRegisterPDU(address: 0x0001, value: 0x0003)
        let req = try parseWriteSingleRegisterRequestPDU(pdu)

        #expect(req.address == 0x0001)
        #expect(req.value == 0x0003)
    }

    @Test("Parse Write Single Register - max values")
    func parseWriteSingleRegisterMax() throws {
        let pdu = buildWriteSingleRegisterPDU(address: 0xFFFF, value: 0xFFFF)
        let req = try parseWriteSingleRegisterRequestPDU(pdu)

        #expect(req.address == 0xFFFF)
        #expect(req.value == 0xFFFF)
    }

    @Test("Parse Write Single Register - too short")
    func parseWriteSingleRegisterTooShort() {
        let pdu: [UInt8] = [0x06, 0x00, 0x01]

        #expect(throws: PDUError.pduTooShort) {
            try parseWriteSingleRegisterRequestPDU(pdu)
        }
    }

    // MARK: - Write Multiple Registers Request Parser (FC 0x10)

    @Test("Parse Write Multiple Registers request")
    func parseWriteMultipleRegisters() throws {
        let values: [UInt16] = [0x000A, 0x0102]
        let pdu = buildWriteMultipleRegistersPDU(address: 0x0001, values: values)
        let req = try parseWriteMultipleRegistersRequestPDU(pdu)

        #expect(req.address == 0x0001)
        #expect(req.values == [0x000A, 0x0102])
    }

    @Test("Parse Write Multiple Registers - single register")
    func parseWriteMultipleRegistersSingle() throws {
        let pdu = buildWriteMultipleRegistersPDU(address: 0x0000, values: [0x1234])
        let req = try parseWriteMultipleRegistersRequestPDU(pdu)

        #expect(req.address == 0)
        #expect(req.values == [0x1234])
    }

    @Test("Parse Write Multiple Registers - too short")
    func parseWriteMultipleRegistersTooShort() {
        let pdu: [UInt8] = [0x10, 0x00, 0x01, 0x00, 0x01] // Missing byte count + data

        #expect(throws: PDUError.pduTooShort) {
            try parseWriteMultipleRegistersRequestPDU(pdu)
        }
    }

    @Test("Parse Write Multiple Registers - byte count mismatch")
    func parseWriteMultipleRegistersByteCountMismatch() {
        let pdu: [UInt8] = [
            0x10,
            0x00, 0x01, // address
            0x00, 0x02, // quantity = 2
            0x02,       // byte count = 2 (should be 4)
            0x00, 0x0A,
        ]

        #expect(throws: PDUError.byteCountMismatch(expected: 4, got: 2)) {
            try parseWriteMultipleRegistersRequestPDU(pdu)
        }
    }

    // MARK: - Write Single Coil Request Parser (FC 0x05)

    @Test("Parse Write Single Coil - ON")
    func parseWriteSingleCoilOn() throws {
        let pdu = buildWriteSingleCoilPDU(address: 0x00AC, value: true)
        let req = try parseWriteSingleCoilRequestPDU(pdu)

        #expect(req.address == 0x00AC)
        #expect(req.value == true)
    }

    @Test("Parse Write Single Coil - OFF")
    func parseWriteSingleCoilOff() throws {
        let pdu = buildWriteSingleCoilPDU(address: 0x00AC, value: false)
        let req = try parseWriteSingleCoilRequestPDU(pdu)

        #expect(req.address == 0x00AC)
        #expect(req.value == false)
    }

    @Test("Parse Write Single Coil - invalid value rejected")
    func parseWriteSingleCoilInvalidValue() {
        let pdu: [UInt8] = [0x05, 0x00, 0xAC, 0x12, 0x34]

        #expect(throws: PDUError.illegalCoilValue(0x1234)) {
            try parseWriteSingleCoilRequestPDU(pdu)
        }
    }

    @Test("Parse Write Single Coil - too short")
    func parseWriteSingleCoilTooShort() {
        let pdu: [UInt8] = [0x05, 0x00]

        #expect(throws: PDUError.pduTooShort) {
            try parseWriteSingleCoilRequestPDU(pdu)
        }
    }

    // MARK: - Write Multiple Coils Request Parser (FC 0x0F)

    @Test("Parse Write Multiple Coils request")
    func parseWriteMultipleCoils() throws {
        let values: [Bool] = [true, false, true, true, false, false, true, true, true, false]
        let pdu = buildWriteMultipleCoilsPDU(address: 0x0013, values: values)
        let req = try parseWriteMultipleCoilsRequestPDU(pdu)

        #expect(req.address == 0x0013)
        #expect(req.values == values)
    }

    @Test("Parse Write Multiple Coils - single coil")
    func parseWriteMultipleCoilsSingle() throws {
        let pdu = buildWriteMultipleCoilsPDU(address: 0, values: [true])
        let req = try parseWriteMultipleCoilsRequestPDU(pdu)

        #expect(req.address == 0)
        #expect(req.values == [true])
    }

    @Test("Parse Write Multiple Coils - 8 coils boundary")
    func parseWriteMultipleCoils8() throws {
        let values: [Bool] = [true, false, true, false, true, false, true, false]
        let pdu = buildWriteMultipleCoilsPDU(address: 0, values: values)
        let req = try parseWriteMultipleCoilsRequestPDU(pdu)

        #expect(req.values == values)
    }

    @Test("Parse Write Multiple Coils - too short")
    func parseWriteMultipleCoilsTooShort() {
        let pdu: [UInt8] = [0x0F, 0x00, 0x13]

        #expect(throws: PDUError.pduTooShort) {
            try parseWriteMultipleCoilsRequestPDU(pdu)
        }
    }

    @Test("Parse Write Multiple Coils - byte count mismatch")
    func parseWriteMultipleCoilsByteCountMismatch() {
        let pdu: [UInt8] = [
            0x0F,
            0x00, 0x13, // address
            0x00, 0x0A, // quantity = 10
            0x01,       // byte count = 1 (should be 2)
            0xCD,
        ]

        #expect(throws: PDUError.byteCountMismatch(expected: 2, got: 1)) {
            try parseWriteMultipleCoilsRequestPDU(pdu)
        }
    }

    // MARK: - Mask Write Register Request Parser (FC 0x16)

    @Test("Parse Mask Write Register request")
    func parseMaskWriteRegister() throws {
        let pdu = buildMaskWriteRegisterPDU(address: 0x0004, andMask: 0x00F2, orMask: 0x0025)
        let req = try parseMaskWriteRegisterRequestPDU(pdu)

        #expect(req.address == 0x0004)
        #expect(req.andMask == 0x00F2)
        #expect(req.orMask == 0x0025)
    }

    @Test("Parse Mask Write Register - too short")
    func parseMaskWriteRegisterTooShort() {
        let pdu: [UInt8] = [0x16, 0x00, 0x04, 0x00]

        #expect(throws: PDUError.pduTooShort) {
            try parseMaskWriteRegisterRequestPDU(pdu)
        }
    }

    // MARK: - Read/Write Multiple Registers Request Parser (FC 0x17)

    @Test("Parse Read/Write Multiple Registers request")
    func parseReadWriteMultipleRegisters() throws {
        let writeValues: [UInt16] = [0x00FF, 0x00FF, 0x00FF]
        let pdu = buildReadWriteMultipleRegistersPDU(
            readAddress: 0x0003,
            readCount: 6,
            writeAddress: 0x000E,
            writeValues: writeValues
        )
        let req = try parseReadWriteMultipleRegistersRequestPDU(pdu)

        #expect(req.readAddress == 0x0003)
        #expect(req.readCount == 6)
        #expect(req.writeAddress == 0x000E)
        #expect(req.writeValues == writeValues)
    }

    @Test("Parse Read/Write Multiple Registers - too short")
    func parseReadWriteMultipleRegistersTooShort() {
        let pdu: [UInt8] = [0x17, 0x00, 0x03, 0x00, 0x06]

        #expect(throws: PDUError.pduTooShort) {
            try parseReadWriteMultipleRegistersRequestPDU(pdu)
        }
    }

    @Test("Parse Read/Write Multiple Registers - byte count mismatch")
    func parseReadWriteMultipleRegistersByteCountMismatch() {
        let pdu: [UInt8] = [
            0x17,
            0x00, 0x03, // read address
            0x00, 0x06, // read count
            0x00, 0x0E, // write address
            0x00, 0x02, // write quantity = 2
            0x02,       // byte count = 2 (should be 4)
            0x00, 0xFF,
        ]

        #expect(throws: PDUError.byteCountMismatch(expected: 4, got: 2)) {
            try parseReadWriteMultipleRegistersRequestPDU(pdu)
        }
    }
}
