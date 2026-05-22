// SPDX-License-Identifier: Apache-2.0

// MARK: - Write Single Register Response Builder

/// Builds a Write Single Register response PDU (FC 0x06, server-side).
///
/// Response is an echo of the request.
///
/// Response PDU format (5 bytes, Big Endian):
/// ```
/// [0]   Function Code (0x06)
/// [1-2] Register Address
/// [3-4] Register Value
/// ```
@inlinable
public func buildWriteSingleRegisterResponsePDU(
    address: UInt16,
    value: UInt16,
) -> [UInt8] {
    var pdu = [UInt8]()
    pdu.reserveCapacity(PDUSize.writeSingleRegister)

    pdu.append(ModbusFunctionCode.writeSingleRegister)

    pdu.append(UInt8(truncatingIfNeeded: address >> 8))
    pdu.append(UInt8(truncatingIfNeeded: address))

    pdu.append(UInt8(truncatingIfNeeded: value >> 8))
    pdu.append(UInt8(truncatingIfNeeded: value))

    return pdu
}

// MARK: - Write Multiple Registers Response Builder

/// Builds a Write Multiple Registers response PDU (FC 0x10, server-side).
///
/// Response PDU format (5 bytes, Big Endian):
/// ```
/// [0]   Function Code (0x10)
/// [1-2] Starting Address
/// [3-4] Quantity of Registers
/// ```
@inlinable
public func buildWriteMultipleRegistersResponsePDU(
    address: UInt16,
    quantity: UInt16,
) -> [UInt8] {
    var pdu = [UInt8]()
    pdu.reserveCapacity(PDUSize.writeMultipleRegistersResponse)

    pdu.append(ModbusFunctionCode.writeMultipleRegisters)

    pdu.append(UInt8(truncatingIfNeeded: address >> 8))
    pdu.append(UInt8(truncatingIfNeeded: address))

    pdu.append(UInt8(truncatingIfNeeded: quantity >> 8))
    pdu.append(UInt8(truncatingIfNeeded: quantity))

    return pdu
}
