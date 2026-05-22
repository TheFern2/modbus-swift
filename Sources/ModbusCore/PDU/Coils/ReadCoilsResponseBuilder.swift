// SPDX-License-Identifier: Apache-2.0

// MARK: - Read Bits Response Builder

/// Builds a Read Coils/Discrete Inputs response PDU (FC 0x01 or 0x02, server-side).
///
/// Response PDU format:
/// ```
/// [0]   Function Code (0x01 or 0x02)
/// [1]   Byte Count (N = ceil(quantity/8))
/// [2..] Coil/Input Data (N bytes, LSB first per byte)
/// ```
@inlinable
public func buildReadBitsResponsePDU(
    functionCode: UInt8,
    bits: [Bool],
) -> [UInt8] {
    let byteCount = UInt8((bits.count + 7) / 8)

    var pdu = [UInt8]()
    pdu.reserveCapacity(2 + Int(byteCount))

    pdu.append(functionCode)
    pdu.append(byteCount)

    var currentByte: UInt8 = 0
    for (i, value) in bits.enumerated() {
        let bitIndex = i % 8
        if value {
            currentByte |= (1 << bitIndex)
        }
        if bitIndex == 7 || i == bits.count - 1 {
            pdu.append(currentByte)
            currentByte = 0
        }
    }

    return pdu
}
