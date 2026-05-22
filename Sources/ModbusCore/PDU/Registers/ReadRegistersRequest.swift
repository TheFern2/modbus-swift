// SPDX-License-Identifier: Apache-2.0

// MARK: - ReadRequestPDU

/// Parsed read request for FC 0x01-0x04 (server-side parsing).
public struct ReadRequestPDU: Equatable, Sendable {
    @usableFromInline
    init(functionCode: UInt8, address: UInt16, count: UInt16) {
        self.functionCode = functionCode
        self.address = address
        self.count = count
    }

    /// Function code from request
    public let functionCode: UInt8
    /// Starting address
    public let address: UInt16
    /// Quantity to read
    public let count: UInt16
}

// MARK: - Read Request Parser

/// Parses a Read request PDU (FC 0x01, 0x02, 0x03, 0x04).
///
/// Request PDU format (5 bytes, Big Endian):
/// ```
/// [0]   Function Code
/// [1-2] Starting Address
/// [3-4] Quantity
/// ```
@inlinable
public func parseReadRequestPDU(
    _ pdu: Span<UInt8>,
) throws(PDUError) -> ReadRequestPDU {
    guard pdu.count >= PDUSize.readRequest else {
        throw .pduTooShort
    }

    let functionCode = pdu[0]

    guard
        let address = readUInt16BE(pdu, at: 1),
        let count = readUInt16BE(pdu, at: 3) else
    {
        throw .pduTooShort
    }

    return ReadRequestPDU(
        functionCode: functionCode,
        address: address,
        count: count,
    )
}

/// Convenience overload for Array input.
@inlinable
public func parseReadRequestPDU(
    _ pdu: [UInt8],
) throws(PDUError) -> ReadRequestPDU {
    try parseReadRequestPDU(pdu.span)
}
