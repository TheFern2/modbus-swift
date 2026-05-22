// SPDX-License-Identifier: Apache-2.0

// MARK: - Read Coils/Discrete Inputs Request Parser

// ReadRequestPDU (defined in ReadRegistersRequest.swift) is reused for
// coil/discrete input read requests since the format is identical:
// FC + address(2) + count(2) = 5 bytes.
//
// Use parseReadRequestPDU() to parse FC 0x01 and FC 0x02 requests.
