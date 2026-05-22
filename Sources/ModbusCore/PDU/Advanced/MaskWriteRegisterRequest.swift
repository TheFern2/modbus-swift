// SPDX-License-Identifier: Apache-2.0

// MARK: - MaskWriteRegisterRequestPDU

/// Parsed Mask Write Register request (FC 0x16, server-side parsing).
public struct MaskWriteRegisterRequestPDU: Equatable, Sendable {
    @usableFromInline
    init(address: UInt16, andMask: UInt16, orMask: UInt16) {
        self.address = address
        self.andMask = andMask
        self.orMask = orMask
    }

    /// Register address
    public let address: UInt16
    /// AND mask
    public let andMask: UInt16
    /// OR mask
    public let orMask: UInt16
}

// MARK: - Mask Write Register Request Parser

/// Parses a Mask Write Register request PDU (FC 0x16).
///
/// Request PDU format (7 bytes, Big Endian):
/// ```
/// [0]   Function Code (0x16)
/// [1-2] Reference Address
/// [3-4] AND Mask
/// [5-6] OR Mask
/// ```
@inlinable
public func parseMaskWriteRegisterRequestPDU(
    _ pdu: Span<UInt8>,
) throws(PDUError) -> MaskWriteRegisterRequestPDU {
    guard pdu.count >= PDUSize.maskWriteRegister else {
        throw .pduTooShort
    }

    guard
        let address = readUInt16BE(pdu, at: 1),
        let andMask = readUInt16BE(pdu, at: 3),
        let orMask = readUInt16BE(pdu, at: 5) else
    {
        throw .pduTooShort
    }

    return MaskWriteRegisterRequestPDU(address: address, andMask: andMask, orMask: orMask)
}

/// Convenience overload for Array input.
@inlinable
public func parseMaskWriteRegisterRequestPDU(
    _ pdu: [UInt8],
) throws(PDUError) -> MaskWriteRegisterRequestPDU {
    try parseMaskWriteRegisterRequestPDU(pdu.span)
}

// MARK: - Mask Write Register Response Builder

/// Builds a Mask Write Register response PDU (FC 0x16, server-side).
///
/// Response is an echo of the request.
@inlinable
public func buildMaskWriteRegisterResponsePDU(
    address: UInt16,
    andMask: UInt16,
    orMask: UInt16,
) -> [UInt8] {
    buildMaskWriteRegisterPDU(address: address, andMask: andMask, orMask: orMask)
}
