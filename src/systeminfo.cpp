#include "systeminfo.h"

#include <QGuiApplication>
#include <QHostAddress>
#include <QInputDevice>
#include <QNetworkInterface>
#include <QPointingDevice>
#include <QSysInfo>

#include <algorithm>
#include <chrono>
#include <expected>
#include <format>
#include <fstream>
#include <optional>
#include <ranges>
#include <sstream>
#include <string>
#include <system_error>
#include <vector>
#include <functional>

#if defined(Q_OS_MACOS)
#  include <mach/mach.h>
#  include <sys/sysctl.h>
#  include <sys/time.h>
#endif

namespace {

constexpr std::size_t kHistoryLength = 60; // one minute at 1 Hz

using namespace std::chrono_literals;

// --- small C++23 helpers -----------------------------------------------------

std::expected<std::string, std::errc> readText(const char *path)
{
    std::ifstream f(path);
    if (!f)
        return std::unexpected(std::errc::no_such_file_or_directory);
    std::ostringstream ss;
    ss << f.rdbuf();
    return ss.str();
}

[[maybe_unused]] std::expected<double, std::errc> readNumber(const char *path)
{
    return readText(path).and_then([](const std::string &s) -> std::expected<double, std::errc> {
        try {
            return std::stod(s);
        } catch (...) {
            return std::unexpected(std::errc::invalid_argument);
        }
    });
}

std::string formatUptime(std::chrono::seconds up)
{
    const auto d = std::chrono::duration_cast<std::chrono::days>(up);
    const auto h = std::chrono::duration_cast<std::chrono::hours>(up - d);
    const auto m = std::chrono::duration_cast<std::chrono::minutes>(up - d - h);
    const auto s = up - d - h - m;
    if (d.count() > 0)
        return std::format("{}d {}h {:02}m", d.count(), h.count(), m.count());
    if (h.count() > 0)
        return std::format("{}h {:02}m", h.count(), m.count());
    return std::format("{}m {:02}s", m.count(), s.count());
}

QString deviceTypeName(QInputDevice::DeviceType t)
{
    switch (t) {
    case QInputDevice::DeviceType::Mouse: return QStringLiteral("Mouse");
    case QInputDevice::DeviceType::TouchScreen: return QStringLiteral("Touchscreen");
    case QInputDevice::DeviceType::TouchPad: return QStringLiteral("Touchpad");
    case QInputDevice::DeviceType::Keyboard: return QStringLiteral("Keyboard");
    case QInputDevice::DeviceType::Stylus:
    case QInputDevice::DeviceType::Airbrush:
    case QInputDevice::DeviceType::Puck: return QStringLiteral("Tablet");
    default: return QStringLiteral("Other");
    }
}

// --- platform probes ---------------------------------------------------------

struct CpuSample {
    std::uint64_t busy = 0;
    std::uint64_t total = 0;
};

std::optional<CpuSample> sampleCpu()
{
#if defined(Q_OS_LINUX)
    auto text = readText("/proc/stat");
    if (!text)
        return std::nullopt;
    std::istringstream line(text->substr(0, text->find('\n')));
    std::string label;
    line >> label; // "cpu"
    const auto fields = std::views::istream<std::uint64_t>(line) | std::ranges::to<std::vector>();
    if (fields.size() < 4)
        return std::nullopt;
    const std::uint64_t total = std::ranges::fold_left(fields, std::uint64_t{0}, std::plus{});
    const std::uint64_t idle = fields[3] + (fields.size() > 4 ? fields[4] : 0); // idle + iowait
    return CpuSample{total - idle, total};
#elif defined(Q_OS_MACOS)
    host_cpu_load_info_data_t info{};
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO,
                        reinterpret_cast<host_info_t>(&info), &count) != KERN_SUCCESS)
        return std::nullopt;
    const auto &t = info.cpu_ticks;
    const std::uint64_t busy = std::uint64_t{t[CPU_STATE_USER]} + t[CPU_STATE_SYSTEM] + t[CPU_STATE_NICE];
    return CpuSample{busy, busy + t[CPU_STATE_IDLE]};
#else
    return std::nullopt;
#endif
}

std::optional<double> sampleTemperature()
{
#if defined(Q_OS_LINUX)
    if (auto milli = readNumber("/sys/class/thermal/thermal_zone0/temp"))
        return *milli / 1000.0;
#endif
    return std::nullopt;
}

struct Memory {
    double usedMiB = -1;
    double totalMiB = -1;
};

Memory sampleMemory()
{
#if defined(Q_OS_LINUX)
    auto text = readText("/proc/meminfo");
    if (!text)
        return {};
    std::istringstream in(*text);
    std::string key;
    double kib = 0, total = -1, avail = -1;
    std::string unit;
    while (in >> key >> kib >> unit) {
        if (key == "MemTotal:") total = kib;
        else if (key == "MemAvailable:") avail = kib;
    }
    if (total < 0 || avail < 0)
        return {};
    return {(total - avail) / 1024.0, total / 1024.0};
#elif defined(Q_OS_MACOS)
    std::uint64_t memsize = 0;
    std::size_t len = sizeof memsize;
    if (sysctlbyname("hw.memsize", &memsize, &len, nullptr, 0) != 0)
        return {};
    vm_statistics64_data_t vm{};
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64,
                          reinterpret_cast<host_info64_t>(&vm), &count) != KERN_SUCCESS)
        return {};
    vm_size_t page = 0;
    host_page_size(mach_host_self(), &page);
    const double used = double(vm.active_count + vm.wire_count + vm.compressor_page_count) * double(page);
    return {used / (1024.0 * 1024.0), double(memsize) / (1024.0 * 1024.0)};
#else
    return {};
#endif
}

std::optional<std::chrono::seconds> sampleUptime()
{
#if defined(Q_OS_LINUX)
    if (auto secs = readNumber("/proc/uptime"))
        return std::chrono::seconds(static_cast<long long>(*secs));
#elif defined(Q_OS_MACOS)
    timeval boot{};
    std::size_t len = sizeof boot;
    if (sysctlbyname("kern.boottime", &boot, &len, nullptr, 0) == 0) {
        const auto now = std::chrono::system_clock::now();
        const auto booted = std::chrono::system_clock::from_time_t(boot.tv_sec);
        return std::chrono::duration_cast<std::chrono::seconds>(now - booted);
    }
#endif
    return std::nullopt;
}

QStringList localIpv4Addresses()
{
    QStringList out;
    const auto ifaces = QNetworkInterface::allInterfaces();
    for (const QNetworkInterface &iface : ifaces) {
        const auto flags = iface.flags();
        if (!flags.testFlag(QNetworkInterface::IsUp) || flags.testFlag(QNetworkInterface::IsLoopBack))
            continue;
        for (const QNetworkAddressEntry &e : iface.addressEntries()) {
            if (e.ip().protocol() == QAbstractSocket::IPv4Protocol)
                out << QStringLiteral("%1 (%2)").arg(e.ip().toString(), iface.humanReadableName());
        }
    }
    return out;
}

} // namespace

// -----------------------------------------------------------------------------

SystemInfo::SystemInfo(QObject *parent)
    : QObject(parent)
{
    if (auto model = readText("/proc/device-tree/model")) {
        std::erase(*model, '\0');
        m_model = QString::fromStdString(*model).trimmed();
        m_isPi = m_model.contains(u"Raspberry Pi");
    }
    if (m_model.isEmpty())
        m_model = QStringLiteral("%1 (%2)").arg(QSysInfo::machineHostName(), QSysInfo::productType());

    if (auto c = sampleCpu())
        m_prevCpu = {c->busy, c->total};

    m_timer.setInterval(1s);
    connect(&m_timer, &QTimer::timeout, this, &SystemInfo::poll);
    m_timer.start();
    poll();
}

QString SystemInfo::hostName() const { return QSysInfo::machineHostName(); }
QString SystemInfo::osName() const { return QSysInfo::prettyProductName(); }
QString SystemInfo::kernel() const { return QSysInfo::kernelType() + QLatin1Char(' ') + QSysInfo::kernelVersion(); }
QString SystemInfo::cpuArch() const { return QSysInfo::currentCpuArchitecture(); }
QString SystemInfo::platformName() const { return QGuiApplication::platformName(); }

QString SystemInfo::qtVersion() const
{
    return QStringLiteral("%1 (built against %2)").arg(QString::fromLatin1(qVersion()),
                                                       QStringLiteral(QT_VERSION_STR));
}

QString SystemInfo::buildInfo() const
{
#if defined(__clang__)
    const std::string compiler = std::format("Clang {}.{}", __clang_major__, __clang_minor__);
#elif defined(__GNUC__)
    const std::string compiler = std::format("GCC {}.{}", __GNUC__, __GNUC_MINOR__);
#else
    const std::string compiler = "unknown compiler";
#endif
    return QString::fromStdString(std::format("{} · C++ {}", compiler, __cplusplus));
}

QVariantList SystemInfo::inputDevices() const
{
    QVariantList list;
    for (const QInputDevice *dev : QInputDevice::devices()) {
        int points = 0;
        if (auto *pd = qobject_cast<const QPointingDevice *>(dev))
            points = pd->maximumPoints();
        list.append(QVariantMap{
            {QStringLiteral("name"), dev->name().isEmpty() ? QStringLiteral("(unnamed)") : dev->name()},
            {QStringLiteral("type"), deviceTypeName(dev->type())},
            {QStringLiteral("points"), points},
            {QStringLiteral("seat"), dev->seatName()},
        });
    }
    return list;
}

void SystemInfo::poll()
{
    if (auto c = sampleCpu()) {
        const auto dTotal = c->total - m_prevCpu.total;
        const auto dBusy = c->busy - m_prevCpu.busy;
        if (dTotal > 0)
            m_load = std::clamp(100.0 * double(dBusy) / double(dTotal), 0.0, 100.0);
        m_prevCpu = {c->busy, c->total};
        push(m_loadHist, m_load);
    }

    if (auto t = sampleTemperature()) {
        m_temp = *t;
        push(m_tempHist, m_temp);
    }

    const Memory mem = sampleMemory();
    m_memUsed = mem.usedMiB;
    m_memTotal = mem.totalMiB;

    if (auto up = sampleUptime())
        m_uptime = QString::fromStdString(formatUptime(*up));

    m_ips = localIpv4Addresses();

    if (const int n = int(QInputDevice::devices().size()); n != m_deviceCount) {
        m_deviceCount = n;
        emit inputDevicesChanged();
    }
    emit updated();
}

QVariantList SystemInfo::toList(const std::deque<double> &d)
{
    QVariantList l;
    l.reserve(qsizetype(d.size()));
    for (double v : d)
        l.append(v);
    return l;
}

void SystemInfo::push(std::deque<double> &d, double v)
{
    d.push_back(v);
    while (d.size() > kHistoryLength)
        d.pop_front();
}
