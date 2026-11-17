# Тексты на русском языке. Те же ключи, что в en.psd1 (это проверяет тест).
# Название приложения здесь не пишется: {app} и {cmd} подставляет Format-Text.
# {0}, {1} - позиционные аргументы в том же порядке, что в en.psd1.
# Одинарные кавычки; апостроф пишется дважды.
# Во множественном числе русский язык имеет три формы, а приложение знает только две
# (One и Many): поэтому тексты с числом построены так, чтобы слово не менялось.
@{
    # Главный экран.
    StatusPaused       = '{0} Пауза - ваш ПК может уснуть'
    StatusAwake        = 'Не сплю уже {0}'

    # Строка подсказки: буквы клавиш остаются в коде, меняются только подписи.
    HelpPause          = 'пауза'
    HelpResume         = 'продолжить'
    HelpScreen         = 'экран'
    HelpF15            = 'F15'
    HelpQuit           = 'выход'
    HelpLanguage       = 'язык'
    HelpUninstall      = 'удалить'

    # Вопрос об удалении. Клавиши остаются y и n.
    ConfirmQuestion    = 'Удалить {app}?'
    ConfirmYes         = 'да'
    ConfirmNo          = 'нет'
    ConfirmNote        = 'Удаляет приложение, ярлык и запись в PATH'

    # Три параметра главного экрана.
    OptionSleep        = 'Не давать ПК уснуть'
    OptionScreen       = 'Не выключать экран'
    OptionKeyPress     = 'Нажимать F15 каждую минуту (чаты остаются активными)'

    # Заголовок окна. Значок перед ним остаётся в коде.
    TitleAwake         = 'Я не сплю!'
    TitlePaused        = '{app} (пауза)'

    # Одна строка за раз, в зависимости от времени работы.
    HumorLines         = @(
        'Я не сплю! Я не сплю!',
        'Просто отдыхаю глазами...',
        'Я слушал, честное слово.',
        'Да, я согласен с последним пунктом.'
    )

    # Экран удаления. UninstallRemoving: {0} = шаг. UninstallFailedOne/Many: {0} = число.
    UninstallHeader    = 'Удаление {app}'
    UninstallRemoving  = 'Удаляется: {0}'
    UninstallDone      = 'Готово. {app} удалён.'
    UninstallFailedOne = 'Ошибок: {0}'
    UninstallFailedMany = 'Ошибок: {0}'
    UninstallKept      = 'Сохранено: %LOCALAPPDATA%\{app} (журнал, копия PATH, язык)'
    PressAnyKeyRow     = 'Нажмите любую клавишу, чтобы закрыть'
    PressAnyKeyMsg     = 'Нажмите любую клавишу, чтобы закрыть.'

    # Шаги удаления. ItemFile: {0} = имя файла.
    ItemPath           = 'Убрать bin из PATH пользователя'
    ItemShortcut       = 'Удалить ярлык на рабочем столе'
    ItemFile           = 'Удалить {0}'
    ItemMarker         = 'Удалить метку установки'
    ItemBinFolder      = 'Удалить папку bin'
    ItemAppFolder      = 'Удалить папку приложения'
    ItemLangFolder     = 'Удалить папку lang'

    # Сообщения uninstall.ps1.
    UninstallNotInstalled = 'Это не установленная копия {app}. Ничего не удалено.'
    UninstallStillRuns = '{app} ещё работает. Закройте его и повторите.'

    # Окно приложения. AppStopped: {0} = ошибка. AppLogPath: {0} = путь к журналу.
    AppAlreadyRunning  = '{app} уже запущен в другом месте. Закрытие через 5 секунд.'
    AppStopped         = '{app} остановлен: {0}'
    AppLogPath         = 'Журнал: {0}'

    # Команда {cmd}. CliUsage* - колонки строк справки.
    # CliAlreadyRunning, CliRunning: {0} = время запуска. CliUnknownArgs, CliFailed: {0} = подробности.
    # CliNoTerminal: {0} = путь к wt.exe.
    CliUsage           = 'Запуск:'
    CliUsageRun        = 'запустить {app} в этом терминале'
    CliUsageWindow     = 'открыть {app} в новом окне'
    CliUsageStatus     = 'показать, работает ли {app}'
    CliAlreadyRunning  = '{app} уже работает с {0}.'
    CliStarted         = '{app} запущен в новом окне.'
    CliRunning         = '{app} работает с {0}.'
    CliNotRunning      = '{app} не запущен.'
    CliUnknownArgs     = '{cmd}: неизвестные аргументы: {0}'
    CliFailed          = '{cmd}: сбой: {0}'
    CliNoTerminal      = 'Windows Terminal не найден: {0}'
}
