// SPDX-License-Identifier: Apache-2.0

// MARK: - Write Single Coil Response Builder

/// Builds a Write Single Coil response PDU (FC 0x05, server-side).
///
/// Response is an echo of the request.
///
/// Response PDU format (5 bytes, Big Endian):
/// ```
/// [0]   Function Code (0x05)
/// [1-2] Output Address
/// [3-4] Output Value (0xFF00=ON, 0x0000=OFF)
/// ```
@inlinable
public func buildWriteSingleCoilResponsePDU(
    address: UInt16,
    value: Bool,
) -> [UInt8] {
    let coilValue: UInt16 = value ? CoilOn : CoilOff

    var pdu = [UInt8]()
    pdu.reserveCapacity(PDUSize.writeSingleRegister)

    pdu.append(ModbusFunctionCode.writeSingleCoil)

    pdu.append(UInt8(truncatingIfNeeded: address >> 8))
    pdu.append(UInt8(truncatingIfNeeded: address))

    pdu.append(UInt8(truncatingIfNeeded: coilValue >> 8))
    pdu.append(UInt8(truncatingIfNeeded: coilValue))

    return pdu
}

// MARK: - Write Multiple Coils Response Builder

/// Builds a Write Multiple Coils response PDU (FC 0x0F, server-side).
///
/// Response PDU format (5 bytes, Big Endian):
/// ```
/// [0]   Function Code (0x0F)
/// [1-2] Starting Address
/// [3-4] Quantity of Outputs
/// ```
@inlinable
public func buildWriteMultipleCoilsResponsePDU(
    address: UInt16,
    quantity: UInt16,
) -> [UInt8] {
    var pdu = [UInt8]()
    pdu.reserveCapacity(PDUSize.writeMultipleRegistersResponse)

    pdu.append(ModbusFunctionCode.writeMultipleCoils)

    pdu.append(UInt8(truncatingIfNeeded: address >> 8))
    pdu.append(UInt8(truncatingIfNeeded: address))

    pdu.append(UInt8(truncatingIfNeeded: quantity >> 8))
    pdu.append(UInt8(truncatingIfNeeded: quantity))

    return pdu
}
