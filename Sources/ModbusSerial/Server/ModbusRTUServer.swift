// SPDX-License-Identifier: Apache-2.0

import Logging
import ModbusCore
import ServiceLifecycle

// MARK: - ModbusRTUServer

/// Modbus RTU server for serial RS-485/RS-232 communication.
///
/// Listens on a serial port for incoming Modbus RTU requests, dispatches
/// them to a `ModbusDataStore`, and sends responses. Conforms to `Service`
/// for ServiceLifecycle integration with graceful shutdown.
///
/// ## Usage
///
/// ```swift
/// let store = InMemoryDataStore(unitIds: [1])
/// let server = ModbusRTUServer(
///     port: "/dev/ttyUSB0",
///     baudRate: .b9600,
///     dataStore: store
/// )
///
/// // With ServiceLifecycle
/// let group = ServiceGroup(
///     services: [server],
///     gracefulShutdownSignals: [.sigterm, .sigint],
///     logger: logger
/// )
/// try await group.run()
/// ```
public final class ModbusRTUServer: Sendable {
    // MARK: Lifecycle

    /// Creates a Modbus RTU server.
    ///
    /// - Parameters:
    ///   - port: Serial port path (e.g., "/dev/ttyUSB0")
    ///   - baudRate: Baud rate (default: 9600)
    ///   - parity: Parity mode (default: none)
    ///   - stopBits: Stop bits (default: one)
    ///   - dataBits: Data bits (default: eight)
    ///   - unitIds: Set of unit IDs this server responds to (default: [1])
    ///   - dataStore: Data store for register/coil values
    ///   - logger: Optional logger
    public init(
        port: String,
        baudRate: BaudRate = .b9600,
        parity: Parity = .none,
        stopBits: StopBits = .one,
        dataBits: DataBits = .eight,
        unitIds: Set<UInt8> = [1],
        dataStore: any ModbusDataStore,
        logger: Logger? = nil,
    ) {
        configuration = ModbusRTUServerConfiguration(
            serialConfiguration: SerialConfiguration(
                port: port,
                baudRate: baudRate,
                parity: parity,
                stopBits: stopBits,
                dataBits: dataBits,
            ),
            unitIds: unitIds,
        )
        self.dataStore = dataStore
        self.logger = logger
        timing = RTUTiming(baudRate: baudRate)
        serialPort = SerialPortActor(path: port)
    }

    /// Creates a Modbus RTU server with configuration.
    public init(
        configuration: ModbusRTUServerConfiguration,
        dataStore: any ModbusDataStore,
        logger: Logger? = nil,
    ) {
        self.configuration = configuration
        self.dataStore = dataStore
        self.logger = logger
        timing = RTUTiming(baudRate: configuration.serialConfiguration.baudRate)
        serialPort = SerialPortActor(path: configuration.serialConfiguration.port)
    }

    /// Creates a Modbus RTU server with a custom serial port.
    ///
    /// Primarily for testing with MockSerialPort.
    public init(
        port: any SerialPort,
        configuration: ModbusRTUServerConfiguration,
        dataStore: any ModbusDataStore,
        logger: Logger? = nil,
    ) {
        self.configuration = configuration
        self.dataStore = dataStore
        self.logger = logger
        timing = RTUTiming(baudRate: configuration.serialConfiguration.baudRate)
        serialPort = SerialPortActor(port: port)
    }

    // MARK: Public

    /// Server configuration.
    public let configuration: ModbusRTUServerConfiguration

    /// RTU timing (T1.5, T3.5).
    public let timing: RTUTiming

    // MARK: Private

    private let serialPort: SerialPortActor
    private let dataStore: any ModbusDataStore
    private let logger: Logger?
}

// MARK: - Service

extension ModbusRTUServer: Service {

    public func run() async throws {
        try await serialPort.open(configuration: configuration.serialConfiguration)

        logger?.info("Modbus RTU server listening on \(configuration.serialConfiguration.port)")

        await withGracefulShutdownHandler {
            await self.runLoop()
        } onGracefulShutdown: {
            self.logger?.info("Shutting down Modbus RTU server")
            Task { await self.serialPort.close() }
        }
    }

    private func runLoop() async {
        let timeout = configuration.serialConfiguration.timeout
        let interFrame = timing.interFrame

        while await serialPort.isOpen {
            let frame: [UInt8]
            do {
                frame = try await readFrame(timeout: timeout, interFrameDelay: interFrame)
            } catch let portError as SerialPortError {
                switch portError {
                case .readTimeout:
                    continue
                case .notOpen:
                    return
                default:
                    logger?.warning("Serial read error: \(portError)")
                    continue
                }
            } catch {
                if Task.isCancelled { return }
                logger?.warning("Unexpected error: \(error)")
                continue
            }

            guard frame.count >= RTUFrameLimits.minResponseSize else {
                logger?.debug("Frame too short (\(frame.count) bytes), discarding")
                continue
            }

            guard verifyModbusCRC(frame) else {
                logger?.debug("Bad CRC, discarding frame")
                continue
            }

            let unitId = frame[0]
            let pduEnd = frame.count - 2
            let pdu = Array(frame[1 ..< pduEnd])

            guard !pdu.isEmpty else { continue }

            let matchesUnit = configuration.unitIds.contains(unitId)
            let isBroadcast = unitId == 0

            guard matchesUnit || isBroadcast else {
                continue
            }

            let functionCode = pdu[0]
            let responsePDU = await dispatchModbusRequest(
                functionCode: functionCode,
                pdu: pdu,
                unitId: unitId,
                dataStore: dataStore,
                logHandler: logger.map { log in { (msg: String) in log.debug("\(msg)") } },
            )

            if isBroadcast { continue }

            let responseFrame = appendModbusCRC([unitId] + responsePDU)

            try? await Task.sleep(for: interFrame)

            do {
                try await serialPort.write(responseFrame, timeout: timeout)
            } catch {
                if case .notOpen = error { return }
                logger?.warning("Serial write error: \(error)")
            }
        }
    }

    private func readFrame(
        timeout: Duration,
        interFrameDelay: Duration,
    ) async throws -> [UInt8] {
        var frame: [UInt8] = []
        let maxSize = RTUFrameLimits.maxFrameSize

        let chunk = try await serialPort.read(maxBytes: maxSize, timeout: timeout)
        frame.append(contentsOf: chunk)

        while frame.count < maxSize {
            do {
                let more = try await serialPort.read(
                    maxBytes: maxSize - frame.count,
                    timeout: interFrameDelay,
                )
                frame.append(contentsOf: more)
            } catch let portError as SerialPortError {
                if portError == .readTimeout {
                    break
                }
                throw portError
            }
        }

        return frame
    }
}
