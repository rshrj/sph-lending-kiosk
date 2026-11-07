#pragma once
// Platform-independent ISO/IEC 14443-A helpers (shared by the MFRC522 driver
// and the simulator, so they also build and are checked on the Mac).

#include <cstdint>
#include <span>
#include <string>
#include <format>

namespace rfid {

// CRC_A (ISO/IEC 14443-3, annex B): init 0x6363, reflected poly 0x8408.
// Transmitted low byte first.
constexpr std::uint16_t crcA(std::span<const std::uint8_t> data)
{
    std::uint16_t crc = 0x6363;
    for (std::uint8_t b : data) {
        b = static_cast<std::uint8_t>(b ^ (crc & 0xFF));
        b = static_cast<std::uint8_t>(b ^ (b << 4));
        crc = static_cast<std::uint16_t>((crc >> 8) ^ (std::uint16_t(b) << 8) ^ (std::uint16_t(b) << 3)
                                         ^ (std::uint16_t(b) >> 4));
    }
    return crc;
}

namespace detail {
constexpr std::uint8_t kHlta[] = {0x50, 0x00};
constexpr std::uint8_t kZeros[] = {0x00, 0x00};
} // namespace detail
// Known vectors: HLTA "50 00" is sent as "50 00 57 CD"; CRC_A(00 00) = 0x1EA0.
static_assert(crcA(detail::kHlta) == 0xCD57);
static_assert(crcA(detail::kZeros) == 0x1EA0);

// Card family from the SELECT acknowledge (SAK) byte.
constexpr const char *cardTypeFromSak(std::uint8_t sak)
{
    switch (sak & 0x7F) {
    case 0x00: return "MIFARE Ultralight / NTAG";
    case 0x08: return "MIFARE Classic 1K";
    case 0x09: return "MIFARE Mini";
    case 0x10:
    case 0x11: return "MIFARE Plus";
    case 0x18: return "MIFARE Classic 4K";
    case 0x20: return "ISO 14443-4 (DESFire / EMV)";
    default:   return "Unknown ISO 14443-A";
    }
}

inline std::string formatUid(std::span<const std::uint8_t> uid)
{
    std::string out;
    for (std::size_t i = 0; i < uid.size(); ++i)
        out += std::format("{}{:02X}", i ? ":" : "", uid[i]);
    return out;
}

} // namespace rfid
