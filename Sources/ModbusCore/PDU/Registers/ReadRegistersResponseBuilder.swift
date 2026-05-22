// SPDX-License-Identifier: Apache-2.0

// MARK: - Read Registers Response Builder

/// Builds a Read Registers response PDU (FC 0x03 or 0x04, server-side).
///
/// Response PDU format:
/// ```
/// [0]   Function Code (0x03 or 0x04)
/// [1]   Byte Count (N = count x 2)
/// [2..] Register Data (N bytes, Big Endian per register)
/// ```
@inlinable
public func buildReadRegistersResponsePDU(
    functionCode: UInt8,
    registers: [UInt16],
) -> [UInt8] {
    let byteCount = UInt8(registers.count * 2)

    var pdu = [UInt8]()
    pdu.reserveCapacity(2 + Int(byteCount))

    pdu.append(functionCode)
    pdu.append(byteCount)

    for value in registers {
        pdu.append(UInt8(truncatingIfNeeded: value >> 8))
        pdu.append(UInt8(truncatingIfNeeded: value))
    }

    return pdu
}
