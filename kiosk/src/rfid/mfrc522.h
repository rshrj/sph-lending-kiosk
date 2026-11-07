#pragma once
// Minimal user-space driver for the NXP MFRC522 (RC522 boards) on Linux:
// SPI through /dev/spidevX.Y, reset line through the GPIO character device
// (uAPI v2) — no RPi.GPIO / pigpio, so it works on the Pi 5 (RP1).
// Scope: detect ISO 14443-A cards and read their UID. No sector crypto.

#include <cstdint>
#include <expected>
#include <optional>
#include <span>
#include <string>
#include <vector>

namespace rfid {

struct Card {
    std::vector<std::uint8_t> uid;
    std::uint8_t sak = 0;
    std::uint16_t atqa = 0;
};

class Mfrc522
{
public:
    struct Config {
        std::string spiDevice = "/dev/spidev0.0"; // CE0 = header pin 24
        int resetGpio = 25;                       // header pin 22
        std::string gpioChip;                     // empty = auto-detect the header's chip
        std::uint32_t spiHz = 1'000'000;
    };

    explicit Mfrc522(Config cfg);
    ~Mfrc522();
    Mfrc522(const Mfrc522 &) = delete;
    Mfrc522 &operator=(const Mfrc522 &) = delete;

    // Opens SPI + reset line, resets and configures the chip. Returns VersionReg.
    std::expected<std::uint8_t, std::string> open();
    void close();
    [[nodiscard]] bool isOpen() const { return m_spi >= 0; }

    // One presence check: wake any card in the field, select it, read its UID,
    // halt it again. nullopt = no card (or an unreadable one this round).
    // An error means the chip itself stopped answering.
    std::expected<std::optional<Card>, std::string> poll();

    // Cheap liveness check (reads VersionReg).
    [[nodiscard]] bool alive();

    [[nodiscard]] const std::string &notes() const { return m_notes; }

private:
    enum class Status { Ok, Timeout, Error, Collision, CrcError, NoChip };

    std::uint8_t read(std::uint8_t reg);
    void write(std::uint8_t reg, std::uint8_t value);
    void setBits(std::uint8_t reg, std::uint8_t mask) { write(reg, read(reg) | mask); }
    void clearBits(std::uint8_t reg, std::uint8_t mask) { write(reg, read(reg) & ~mask); }

    Status transceive(std::span<const std::uint8_t> send, std::vector<std::uint8_t> &back,
                      std::uint8_t txLastBits, std::uint8_t *rxValidBits);
    Status requestA(bool wakeup, std::uint16_t &atqa);
    Status select(Card &card);
    void haltA();
    void initRegisters();
    bool openResetLine();
    void setReset(bool high);

    Config m_cfg;
    int m_spi = -1;
    int m_resetLine = -1;
    bool m_spiFailed = false;
    std::string m_notes;
};

} // namespace rfid
