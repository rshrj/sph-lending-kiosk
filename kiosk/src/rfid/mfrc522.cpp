#include "mfrc522.h"
#include "iso14443.h"

#include <array>
#include <cerrno>
#include <chrono>
#include <cstring>
#include <format>
#include <thread>

#include <fcntl.h>
#include <linux/gpio.h>
#include <linux/spi/spidev.h>
#include <sys/ioctl.h>
#include <unistd.h>

namespace rfid {

using namespace std::chrono_literals;
using Clock = std::chrono::steady_clock;

namespace {

// Registers (datasheet §9)
enum Reg : std::uint8_t {
    CommandReg = 0x01, ComIrqReg = 0x04, DivIrqReg = 0x05, ErrorReg = 0x06,
    FIFODataReg = 0x09, FIFOLevelReg = 0x0A, ControlReg = 0x0C, BitFramingReg = 0x0D,
    CollReg = 0x0E, ModeReg = 0x11, TxModeReg = 0x12, RxModeReg = 0x13,
    TxControlReg = 0x14, TxASKReg = 0x15, ModWidthReg = 0x24, RFCfgReg = 0x26,
    TModeReg = 0x2A, TPrescalerReg = 0x2B, TReloadRegH = 0x2C, TReloadRegL = 0x2D,
    VersionReg = 0x37,
};
// PCD commands
constexpr std::uint8_t CmdIdle = 0x00, CmdTransceive = 0x0C, CmdSoftReset = 0x0F;
// PICC commands
constexpr std::uint8_t PiccReqA = 0x26, PiccWupA = 0x52, PiccHltA = 0x50;
constexpr std::array<std::uint8_t, 3> kSelect = {0x93, 0x95, 0x97}; // cascade levels 1..3

std::string errnoText(const char *what) { return std::format("{}: {}", what, std::strerror(errno)); }

// Find the GPIO chip that drives the 40-pin header.
int openHeaderGpioChip(const std::string &forced, std::string &label)
{
    for (int i = 0; i < 16; ++i) {
        const std::string path = forced.empty() ? std::format("/dev/gpiochip{}", i) : forced;
        const int fd = ::open(path.c_str(), O_RDWR | O_CLOEXEC);
        if (fd >= 0) {
            gpiochip_info info{};
            if (ioctl(fd, GPIO_GET_CHIPINFO_IOCTL, &info) == 0) {
                const std::string l = info.label;
                // Pi 5: pinctrl-rp1 · Pi 4: pinctrl-bcm2711 · older: pinctrl-bcm2835
                if (!forced.empty() || l == "pinctrl-rp1" || l == "pinctrl-bcm2711" || l == "pinctrl-bcm2835") {
                    label = path + " (" + l + ")";
                    return fd;
                }
            }
            ::close(fd);
        }
        if (!forced.empty())
            break;
    }
    return -1;
}

} // namespace

Mfrc522::Mfrc522(Config cfg) : m_cfg(std::move(cfg)) {}
Mfrc522::~Mfrc522() { close(); }

void Mfrc522::close()
{
    if (m_spi >= 0) ::close(m_spi);
    if (m_resetLine >= 0) ::close(m_resetLine); // releases the line
    m_spi = m_resetLine = -1;
}

bool Mfrc522::openResetLine()
{
    if (m_cfg.resetGpio < 0)
        return false;
    std::string chipLabel;
    const int chip = openHeaderGpioChip(m_cfg.gpioChip, chipLabel);
    if (chip < 0) {
        m_notes += "no header GPIO chip found; ";
        return false;
    }
    gpio_v2_line_request req{};
    req.offsets[0] = static_cast<std::uint32_t>(m_cfg.resetGpio);
    req.num_lines = 1;
    std::strncpy(req.consumer, "kiosk-lab-rfid", sizeof req.consumer - 1);
    req.config.flags = GPIO_V2_LINE_FLAG_OUTPUT;
    req.config.num_attrs = 1;
    req.config.attrs[0].attr.id = GPIO_V2_LINE_ATTR_ID_OUTPUT_VALUES;
    req.config.attrs[0].attr.values = 1; // start high = chip running
    req.config.attrs[0].mask = 1;
    const int rc = ioctl(chip, GPIO_V2_GET_LINE_IOCTL, &req);
    ::close(chip);
    if (rc < 0) {
        m_notes += errnoText(std::format("GPIO{} request", m_cfg.resetGpio).c_str()) + "; ";
        return false;
    }
    m_resetLine = req.fd;
    m_notes += std::format("RST=GPIO{} via {}; ", m_cfg.resetGpio, chipLabel);
    return true;
}

void Mfrc522::setReset(bool high)
{
    if (m_resetLine < 0) return;
    gpio_v2_line_values v{};
    v.bits = high ? 1 : 0;
    v.mask = 1;
    ioctl(m_resetLine, GPIO_V2_LINE_SET_VALUES_IOCTL, &v);
}

std::expected<std::uint8_t, std::string> Mfrc522::open()
{
    close();
    m_notes.clear();
    m_spiFailed = false;

    m_spi = ::open(m_cfg.spiDevice.c_str(), O_RDWR | O_CLOEXEC);
    if (m_spi < 0) {
        const std::string why = errnoText(m_cfg.spiDevice.c_str());
        return std::unexpected(errno == ENOENT ? why + " — SPI is disabled (run: deploy/deploy.sh spi, then reboot)" : why);
    }
    std::uint8_t mode = SPI_MODE_0, bits = 8;
    std::uint32_t speed = m_cfg.spiHz;
    if (ioctl(m_spi, SPI_IOC_WR_MODE, &mode) < 0 || ioctl(m_spi, SPI_IOC_WR_BITS_PER_WORD, &bits) < 0
        || ioctl(m_spi, SPI_IOC_WR_MAX_SPEED_HZ, &speed) < 0) {
        const std::string why = errnoText("SPI configure");
        close();
        return std::unexpected(why);
    }

    // Hard reset (RST is active-low; the Pi's default pull-down would otherwise
    // keep the chip powered down).
    if (openResetLine()) {
        setReset(false);
        std::this_thread::sleep_for(5ms);
        setReset(true);
        std::this_thread::sleep_for(50ms);
    }

    write(CommandReg, CmdSoftReset);
    std::this_thread::sleep_for(50ms);
    for (int i = 0; i < 10 && (read(CommandReg) & 0x10); ++i) // PowerDown bit
        std::this_thread::sleep_for(10ms);

    const std::uint8_t version = read(VersionReg);
    if (version == 0x00 || version == 0xFF || m_spiFailed) {
        close();
        return std::unexpected(std::format(
            "no MFRC522 answering on {} (VersionReg=0x{:02X}) — check wiring and 3.3 V; {}",
            m_cfg.spiDevice, version, m_notes));
    }
    initRegisters();
    return version;
}

void Mfrc522::initRegisters()
{
    write(TxModeReg, 0x00);   // 106 kBd, no CRC in hardware (we append CRC_A ourselves)
    write(RxModeReg, 0x00);
    write(ModWidthReg, 0x26);
    // Timer: TAuto, f = 13.56 MHz / (2*0xA9+1) ≈ 40 kHz → 1000 ticks = 25 ms receive timeout
    write(TModeReg, 0x80);
    write(TPrescalerReg, 0xA9);
    write(TReloadRegH, 0x03);
    write(TReloadRegL, 0xE8);
    write(TxASKReg, 0x40);    // force 100 % ASK
    write(ModeReg, 0x3D);     // CRC preset 0x6363
    write(RFCfgReg, 0x70);    // max receiver gain (48 dB): better read range
    if ((read(TxControlReg) & 0x03) != 0x03)
        setBits(TxControlReg, 0x03); // antenna drivers on
}

std::uint8_t Mfrc522::read(std::uint8_t reg)
{
    std::array<std::uint8_t, 2> tx{static_cast<std::uint8_t>(0x80 | ((reg << 1) & 0x7E)), 0x00};
    std::array<std::uint8_t, 2> rx{};
    spi_ioc_transfer t{};
    t.tx_buf = reinterpret_cast<std::uintptr_t>(tx.data());
    t.rx_buf = reinterpret_cast<std::uintptr_t>(rx.data());
    t.len = 2;
    t.speed_hz = m_cfg.spiHz;
    t.bits_per_word = 8;
    if (ioctl(m_spi, SPI_IOC_MESSAGE(1), &t) < 0) {
        m_spiFailed = true;
        return 0;
    }
    return rx[1];
}

void Mfrc522::write(std::uint8_t reg, std::uint8_t value)
{
    std::array<std::uint8_t, 2> tx{static_cast<std::uint8_t>((reg << 1) & 0x7E), value};
    spi_ioc_transfer t{};
    t.tx_buf = reinterpret_cast<std::uintptr_t>(tx.data());
    t.len = 2;
    t.speed_hz = m_cfg.spiHz;
    t.bits_per_word = 8;
    if (ioctl(m_spi, SPI_IOC_MESSAGE(1), &t) < 0)
        m_spiFailed = true;
}

bool Mfrc522::alive()
{
    if (m_spi < 0) return false;
    const std::uint8_t v = read(VersionReg);
    return !m_spiFailed && v != 0x00 && v != 0xFF;
}

Mfrc522::Status Mfrc522::transceive(std::span<const std::uint8_t> send, std::vector<std::uint8_t> &back,
                                    std::uint8_t txLastBits, std::uint8_t *rxValidBits)
{
    write(CommandReg, CmdIdle);
    write(ComIrqReg, 0x7F);          // clear all IRQ flags
    write(FIFOLevelReg, 0x80);       // flush FIFO
    for (std::uint8_t b : send)
        write(FIFODataReg, b);
    write(BitFramingReg, txLastBits & 0x07);
    write(CommandReg, CmdTransceive);
    setBits(BitFramingReg, 0x80);    // StartSend

    const auto deadline = Clock::now() + 40ms;
    for (;;) {
        const std::uint8_t irq = read(ComIrqReg);
        if (irq & 0x30) break;                 // RxIRq | IdleIRq
        if (irq & 0x01) return Status::Timeout; // TimerIRq: nothing answered within 25 ms
        if (m_spiFailed || Clock::now() > deadline) return Status::NoChip;
    }

    const std::uint8_t err = read(ErrorReg);
    if (err & 0x13) return Status::Error;      // BufferOvfl | ParityErr | ProtocolErr

    const std::uint8_t n = read(FIFOLevelReg);
    back.resize(n);
    for (auto &b : back)
        b = read(FIFODataReg);
    if (rxValidBits)
        *rxValidBits = read(ControlReg) & 0x07;
    if (err & 0x08) return Status::Collision;
    return Status::Ok;
}

Mfrc522::Status Mfrc522::requestA(bool wakeup, std::uint16_t &atqa)
{
    clearBits(CollReg, 0x80);
    const std::uint8_t cmd = wakeup ? PiccWupA : PiccReqA;
    std::vector<std::uint8_t> back;
    std::uint8_t valid = 0;
    const Status st = transceive(std::span(&cmd, 1), back, 7, &valid); // short frame: 7 bits
    if (st != Status::Ok) return st;
    if (back.size() != 2 || valid != 0) return Status::Error;
    atqa = static_cast<std::uint16_t>(back[0] | (back[1] << 8));
    return Status::Ok;
}

// Anticollision + SELECT per cascade level. Multiple cards in the field are
// reported as a collision (the caller just retries) rather than resolved.
Mfrc522::Status Mfrc522::select(Card &card)
{
    card.uid.clear();
    for (std::uint8_t sel : kSelect) {
        clearBits(CollReg, 0x80);
        const std::array<std::uint8_t, 2> anticoll{sel, 0x20};
        std::vector<std::uint8_t> uidPart;
        std::uint8_t valid = 0;
        Status st = transceive(anticoll, uidPart, 0, &valid);
        if (st != Status::Ok) return st;
        if (uidPart.size() != 5) return Status::Error;
        if ((uidPart[0] ^ uidPart[1] ^ uidPart[2] ^ uidPart[3]) != uidPart[4]) return Status::CrcError; // BCC

        std::array<std::uint8_t, 9> frame{sel, 0x70, uidPart[0], uidPart[1], uidPart[2], uidPart[3], uidPart[4], 0, 0};
        const std::uint16_t crc = crcA(std::span(frame.data(), 7));
        frame[7] = crc & 0xFF;
        frame[8] = crc >> 8;
        std::vector<std::uint8_t> sak;
        st = transceive(frame, sak, 0, &valid);
        if (st != Status::Ok) return st;
        if (sak.size() != 3 || crcA(std::span(sak.data(), 1)) != (sak[1] | (sak[2] << 8))) return Status::CrcError;

        const bool cascadeTag = uidPart[0] == 0x88; // more UID bytes follow at the next level
        card.uid.insert(card.uid.end(), uidPart.begin() + (cascadeTag ? 1 : 0), uidPart.begin() + 4);
        card.sak = sak[0];
        if (!(sak[0] & 0x04)) return Status::Ok;     // UID complete
    }
    return Status::Error;
}

void Mfrc522::haltA()
{
    std::array<std::uint8_t, 4> frame{PiccHltA, 0x00, 0, 0};
    const std::uint16_t crc = crcA(std::span(frame.data(), 2));
    frame[2] = crc & 0xFF;
    frame[3] = crc >> 8;
    std::vector<std::uint8_t> back;
    transceive(frame, back, 0, nullptr); // success = no answer (timeout)
}

std::expected<std::optional<Card>, std::string> Mfrc522::poll()
{
    if (m_spi < 0)
        return std::unexpected(std::string("reader not open"));

    Card card;
    // WUPA (not REQA) also wakes cards we HALTed last round → steady presence detection.
    Status st = requestA(true, card.atqa);
    if (st == Status::NoChip)
        return std::unexpected(std::string("MFRC522 stopped responding"));
    if (st != Status::Ok)
        return std::optional<Card>{};

    st = select(card);
    if (st == Status::NoChip)
        return std::unexpected(std::string("MFRC522 stopped responding"));
    if (st != Status::Ok)
        return std::optional<Card>{};

    haltA();
    return std::optional<Card>{std::move(card)};
}

} // namespace rfid
