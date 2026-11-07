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
    bool kiosk = false;   // full screen, frameless, no cursor
    int idleTimeout = -1; // seconds before the attract screen (0 = off, -1 = saved setting)
    QString screenshotDir; // non-empty: tour every screen, save PNGs, quit
};

Options parseOptions(const QGuiApplication &app)
{
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Kiosk Lab – touch & UI test bench"));
    parser.addHelpOption();
    parser.addVersionOption();

    const QCommandLineOption kioskOpt(QStringLiteral("kiosk"),
        QStringLiteral("Run full screen, frameless, with the mouse cursor hidden."));
    const QCommandLineOption idleOpt(QStringLiteral("idle"),
        QStringLiteral("Seconds of inactivity before the attract screen (0 disables)."),
        QStringLiteral("seconds"));
    const QCommandLineOption shotOpt(QStringLiteral("screenshot"),
        QStringLiteral("Visit every screen, save a PNG of each into <dir>, then quit."),
        QStringLiteral("dir"));
    parser.addOptions({kioskOpt, idleOpt, shotOpt});
    parser.process(app);

    Options o;
    // EGLFS has no window manager, so it is always "kiosk".
    o.kiosk = parser.isSet(kioskOpt) || qEnvironmentVariableIntValue("KIOSK_LAB_KIOSK") == 1
              || QGuiApplication::platformName() == u"eglfs";
    bool ok = false;
    if (const int v = parser.value(idleOpt).toInt(&ok); parser.isSet(idleOpt) && ok && v >= 0)
        o.idleTimeout = v;
    o.screenshotDir = parser.value(shotOpt);
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
    // On-screen keyboard for text fields (must be chosen before the app object exists).
    if (!qEnvironmentVariableIsSet("QT_IM_MODULE"))
        qputenv("QT_IM_MODULE", "qtvirtualkeyboard");

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Kiosk Lab"));
    QGuiApplication::setApplicationVersion(QStringLiteral(PROJECT_VERSION_STRING));
    QGuiApplication::setOrganizationName(QStringLiteral("KioskLab"));

    const Options opts = parseOptions(app);

    // "Basic" is the lightest built-in style and the only one that is fully
    // customisable everywhere (the native macOS style is not).
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    loadBundledFonts();
    QGuiApplication::setFont(QFont(QStringLiteral("Inter"), 15));

    if (opts.kiosk)
        QGuiApplication::setOverrideCursor(Qt::BlankCursor);

    QQmlApplicationEngine engine;
    engine.setInitialProperties({
        {QStringLiteral("kioskMode"), opts.kiosk},
        {QStringLiteral("idleTimeout"), opts.idleTimeout},
        {QStringLiteral("screenshotDir"), opts.screenshotDir},
    });
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(EXIT_FAILURE); }, Qt::QueuedConnection);
    engine.loadFromModule("Kiosk", "Main");

    return QGuiApplication::exec();
}
