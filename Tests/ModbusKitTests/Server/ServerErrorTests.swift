// SPDX-License-Identifier: Apache-2.0

import ModbusCore
@testable import ModbusKit
import Testing

@Suite("ModbusServerError")
struct ServerErrorTests {

    @Test("Error maps to correct Modbus exception codes")
    func exceptionMapping() {
        #expect(ModbusServerError.illegalFunction.modbusException == .illegalFunction)
        #expect(ModbusServerError.illegalDataAddress.modbusException == .illegalDataAddress)
        #expect(ModbusServerError.illegalDataValue.modbusException == .illegalDataValue)
        #expect(ModbusServerError.slaveDeviceFailure.modbusException == .slaveDeviceFailure)
    }

    @Test("Error is Equatable")
    func equatable() {
        #expect(ModbusServerError.illegalFunction == ModbusServerError.illegalFunction)
        #expect(ModbusServerError.illegalFunction != ModbusServerError.illegalDataAddress)
    }
}
