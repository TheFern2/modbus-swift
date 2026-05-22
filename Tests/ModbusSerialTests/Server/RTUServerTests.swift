// SPDX-License-Identifier: Apache-2.0

import ModbusCore
@testable import ModbusSerial
import Testing

// MARK: - ServerMockSerialPort

/// Mock serial port for RTU server testing.
///
/// Unlike the client-side MockSerialPort (which simulates a slave device),
/// this mock simulates a master device sending requests to the server.
/// Requests are queued and responses are captured for verification.
private actor ServerMockSerialPort: SerialPort {
    var isOpen: Bool { _isOpen }

    private var _isOpen = false
    private var requestQueue: [[UInt8]] = []
    private var capturedResponses: [[UInt8]] = []
    private var failOnRead = false

    func open(configuration: SerialConfiguration) async throws(SerialPortError) {
        _isOpen = true
    }

    func close() async {
        _isOpen = false
    }

    func read(maxBytes: Int, timeout: Duration) async throws(SerialPortError) -> [UInt8] {
        guard _isOpen else { throw .notOpen }
        if failOnRead { throw .readFailed(errno: 5) }

        if let request = requestQueue.first {
            requestQueue.removeFirst()
            return request
        }
        throw .readTimeout
    }

    func write(_ bytes: [UInt8], timeout: Duration) async throws(SerialPortError) {
        guard _isOpen else { throw .notOpen }
        capturedResponses.append(bytes)
    }

    func flush() async throws(SerialPortError) {
        guard _isOpen else { throw .notOpen }
    }

    // MARK: - Test Helpers

    func enqueueRequest(_ frame: [UInt8]) {
        requestQueue.append(frame)
    }

    func getResponses() -> [[UInt8]] {
        capturedResponses
    }

    func clearResponses() {
        capturedResponses.removeAll()
    }

    func setFailOnRead(_ fail: Bool) {
        failOnRead = fail
    }
}

// MARK: - Tests

@Suite("ModbusRTUServer")
struct RTUServerTests {

    // MARK: - Helpers

    private func makeServer(
        mockPort: ServerMockSerialPort,
        unitIds: Set<UInt8> = [1],
        dataStoreUnitIds: Set<UInt8>? = nil,
    ) -> (ModbusRTUServer, InMemoryDataStore) {
        let store = InMemoryDataStore(unitIds: dataStoreUnitIds ?? unitIds)
        let config = ModbusRTUServerConfiguration(
            serialConfiguration: SerialConfiguration(port: "/dev/mock", baudRate: .b9600),
            unitIds: unitIds,
        )
        let server = ModbusRTUServer(
            port: mockPort,
            configuration: config,
            dataStore: store,
        )
        return (server, store)
    }

    private func buildRTURequest(unitId: UInt8, pdu: [UInt8]) -> [UInt8] {
        appendModbusCRC([unitId] + pdu)
    }

    // MARK: - Read Holding Registers

    @Test("Server processes read holding registers request")
    func readHoldingRegisters() async throws {
        let mockPort = ServerMockSerialPort()
        let (server, store) = makeServer(mockPort: mockPort)
        await store.setHoldingRegisters(unitId: 1, address: 0, values: [0x1234, 0x5678])

        let requestPDU = buildReadHoldingRegistersPDU(address: 0, count: 2)
        let requestFrame = buildRTURequest(unitId: 1, pdu: requestPDU)
        await mockPort.enqueueRequest(requestFrame)

        async let serverRun: Void = server.run()
        try? await Task.sleep(for: .milliseconds(100))
        await mockPort.close()
        try? await serverRun

        let responses = await mockPort.getResponses()
        #expect(responses.count == 1)

        let response = responses[0]
        #expect(verifyModbusCRC(response))
        #expect(response[0] == 1)

        let responsePDU = Array(response[1 ..< response.count - 2])
        let parsed = try parseReadRegistersPDU(responsePDU)
        #expect(parsed.registers == [0x1234, 0x5678])
    }

    // MARK: - Write Single Register

    @Test("Server processes write single register and updates data store")
    func writeSingleRegister() async throws {
        let mockPort = ServerMockSerialPort()
        let (server, store) = makeServer(mockPort: mockPort)

        let requestPDU = buildWriteSingleRegisterPDU(address: 10, value: 0xBEEF)
        let requestFrame = buildRTURequest(unitId: 1, pdu: requestPDU)
        await mockPort.enqueueRequest(requestFrame)

        async let serverRun: Void = server.run()
        try? await Task.sleep(for: .milliseconds(100))
        await mockPort.close()
        try? await serverRun

        let responses = await mockPort.getResponses()
        #expect(responses.count == 1)

        let response = responses[0]
        #expect(verifyModbusCRC(response))

        let stored = try await store.readHoldingRegisters(unitId: 1, address: 10, count: 1)
        #expect(stored == [0xBEEF])
    }

    // MARK: - Unit ID Filtering

    @Test("Server ignores requests for non-matching unit IDs")
    func nonMatchingUnitId() async throws {
        let mockPort = ServerMockSerialPort()
        let (server, _) = makeServer(mockPort: mockPort, unitIds: [1])

        let requestPDU = buildReadHoldingRegistersPDU(address: 0, count: 1)
        let requestFrame = buildRTURequest(unitId: 5, pdu: requestPDU)
        await mockPort.enqueueRequest(requestFrame)

        async let serverRun: Void = server.run()
        try? await Task.sleep(for: .milliseconds(100))
        await mockPort.close()
        try? await serverRun

        let responses = await mockPort.getResponses()
        #expect(responses.isEmpty)
    }

    // MARK: - Exception Responses

    @Test("Server returns exception for unsupported function codes")
    func unsupportedFunctionCode() async throws {
        let mockPort = ServerMockSerialPort()
        let (server, _) = makeServer(mockPort: mockPort)

        let pdu: [UInt8] = [0x2B, 0x0E, 0x01, 0x00, 0x00]
        let requestFrame = buildRTURequest(unitId: 1, pdu: pdu)
        await mockPort.enqueueRequest(requestFrame)

        async let serverRun: Void = server.run()
        try? await Task.sleep(for: .milliseconds(100))
        await mockPort.close()
        try? await serverRun

        let responses = await mockPort.getResponses()
        #expect(responses.count == 1)

        let response = responses[0]
        #expect(verifyModbusCRC(response))
        #expect(response[0] == 1)
        #expect(response[1] == 0x2B | 0x80)
        #expect(response[2] == ModbusException.illegalFunction.rawValue)
    }

    @Test("Server returns exception for invalid addresses")
    func invalidAddress() async throws {
        let mockPort = ServerMockSerialPort()
        let store = InMemoryDataStore(unitIds: [1], registerCount: 100)
        let config = ModbusRTUServerConfiguration(
            serialConfiguration: SerialConfiguration(port: "/dev/mock", baudRate: .b9600),
            unitIds: [1],
        )
        let server = ModbusRTUServer(port: mockPort, configuration: config, dataStore: store)

        let requestPDU = buildReadHoldingRegistersPDU(address: 99, count: 2)
        let requestFrame = buildRTURequest(unitId: 1, pdu: requestPDU)
        await mockPort.enqueueRequest(requestFrame)

        async let serverRun: Void = server.run()
        try? await Task.sleep(for: .milliseconds(100))
        await mockPort.close()
        try? await serverRun

        let responses = await mockPort.getResponses()
        #expect(responses.count == 1)

        let response = responses[0]
        #expect(response[1] == 0x03 | 0x80)
        #expect(response[2] == ModbusException.illegalDataAddress.rawValue)
    }

    // MARK: - Broadcast

    @Test("Server handles broadcast (unit 0) -- processes but no response")
    func broadcastNoResponse() async throws {
        let mockPort = ServerMockSerialPort()
        let (server, store) = makeServer(mockPort: mockPort, unitIds: [1], dataStoreUnitIds: [0, 1])

        let requestPDU = buildWriteSingleRegisterPDU(address: 0, value: 0x1234)
        let requestFrame = buildRTURequest(unitId: 0, pdu: requestPDU)
        await mockPort.enqueueRequest(requestFrame)

        async let serverRun: Void = server.run()
        try? await Task.sleep(for: .milliseconds(100))
        await mockPort.close()
        try? await serverRun

        let responses = await mockPort.getResponses()
        #expect(responses.isEmpty)

        let stored = try await store.readHoldingRegisters(unitId: 0, address: 0, count: 1)
        #expect(stored == [0x1234])
    }

    // MARK: - CRC Validation

    @Test("Server discards frames with bad CRC")
    func badCRC() async throws {
        let mockPort = ServerMockSerialPort()
        let (server, _) = makeServer(mockPort: mockPort)

        var requestFrame = buildRTURequest(
            unitId: 1,
            pdu: buildReadHoldingRegistersPDU(address: 0, count: 1),
        )
        requestFrame[requestFrame.count - 1] ^= 0xFF

        await mockPort.enqueueRequest(requestFrame)

        async let serverRun: Void = server.run()
        try? await Task.sleep(for: .milliseconds(100))
        await mockPort.close()
        try? await serverRun

        let responses = await mockPort.getResponses()
        #expect(responses.isEmpty)
    }

    // MARK: - Response CRC

    @Test("Server response has valid CRC")
    func responseCRC() async throws {
        let mockPort = ServerMockSerialPort()
        let (server, _) = makeServer(mockPort: mockPort)

        let requestPDU = buildReadHoldingRegistersPDU(address: 0, count: 1)
        let requestFrame = buildRTURequest(unitId: 1, pdu: requestPDU)
        await mockPort.enqueueRequest(requestFrame)

        async let serverRun: Void = server.run()
        try? await Task.sleep(for: .milliseconds(100))
        await mockPort.close()
        try? await serverRun

        let responses = await mockPort.getResponses()
        #expect(responses.count == 1)
        #expect(verifyModbusCRC(responses[0]))
    }
}
