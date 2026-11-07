#include "backend.h"

#include <QCommandLineParser>
#include <QCursor>
#include <QDirIterator>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

#include <print>

namespace {

struct Options {
    bool kiosk = false;    // full screen, frameless, no cursor
    int idleTimeout = 60;  // seconds before the attract screen + reset (0 = off)
    QString screenshotDir; // non-empty: tour every screen, save PNGs, quit
    QString tour = QStringLiteral("full"); // full | camera
};

Options parseOptions(const QGuiApplication &app)
{
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("SPH lending kiosk – borrow & return"));
    parser.addHelpOption();
    parser.addVersionOption();

    const QCommandLineOption kioskOpt(QStringLiteral("kiosk"),
        QStringLiteral("Run full screen, frameless, with the mouse cursor hidden."));
    const QCommandLineOption idleOpt(QStringLiteral("idle"),
        QStringLiteral("Seconds of inactivity before the kiosk resets to the attract screen (0 disables, default 60)."),
        QStringLiteral("seconds"));
    const QCommandLineOption backendOpt(QStringLiteral("backend"),
        QStringLiteral("Inventory server URL (default http://127.0.0.1:8000, or $KIOSK_BACKEND_URL)."),
        QStringLiteral("url"));
    const QCommandLineOption shotOpt(QStringLiteral("screenshot"),
        QStringLiteral("Visit every screen, save a PNG of each into <dir>, then quit."),
        QStringLiteral("dir"));
    const QCommandLineOption tourOpt(QStringLiteral("tour"),
        QStringLiteral("Screenshot tour: 'full' (drives real loans; RESETS the inventory) or 'camera' (read-only live tray view)."),
        QStringLiteral("name"), QStringLiteral("full"));
    parser.addOptions({kioskOpt, idleOpt, backendOpt, shotOpt, tourOpt});
    parser.process(app);

    Options o;
    // EGLFS has no window manager, so it is always "kiosk".
    o.kiosk = parser.isSet(kioskOpt) || qEnvironmentVariableIntValue("SPH_KIOSK_FULLSCREEN") == 1
              || QGuiApplication::platformName() == u"eglfs";
    bool ok = false;
    if (const int v = parser.value(idleOpt).toInt(&ok); parser.isSet(idleOpt) && ok && v >= 0)
        o.idleTimeout = v;
    o.screenshotDir = parser.value(shotOpt);
    o.tour = parser.value(tourOpt);

    QString backend = parser.value(backendOpt);
    if (backend.isEmpty()) backend = qEnvironmentVariable("KIOSK_BACKEND_URL");
    if (!backend.isEmpty()) Backend::setDefaultBaseUrl(QUrl::fromUserInput(backend));
    return o;
}

void loadBundledFonts()
{
    QDirIterator it(QStringLiteral(":/qt/qml/Kiosk/fonts"), {QStringLiteral("*.ttf")});
    while (it.hasNext()) {
        if (QFontDatabase::addApplicationFont(it.next()) < 0)
            std::println(stderr, "warning: could not load font {}", it.filePath().toStdString());
    }
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("SPH Kiosk"));
    QGuiApplication::setApplicationVersion(QStringLiteral(PROJECT_VERSION_STRING));
    QGuiApplication::setOrganizationName(QStringLiteral("SPH"));

    const Options opts = parseOptions(app);

    // "Basic" is the lightest built-in style and fully customisable everywhere.
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    loadBundledFonts();
    QGuiApplication::setFont(QFont(QStringLiteral("Proxima Nova"), 16));

    if (opts.kiosk)
        QGuiApplication::setOverrideCursor(Qt::BlankCursor);

    QQmlApplicationEngine engine;
    engine.setInitialProperties({
        {QStringLiteral("kioskMode"), opts.kiosk},
        {QStringLiteral("idleTimeout"), opts.idleTimeout},
        {QStringLiteral("screenshotDir"), opts.screenshotDir},
        {QStringLiteral("tour"), opts.tour},
        // Only the screenshot tour may unlock the staff panel by itself.
        {QStringLiteral("tourStaffPin"),
         opts.screenshotDir.isEmpty() ? QString() : qEnvironmentVariable("KIOSK_STAFF_PIN")},
    });
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(EXIT_FAILURE); }, Qt::QueuedConnection);
    engine.loadFromModule("Kiosk", "Main");

    return QGuiApplication::exec();
}
