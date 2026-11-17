# English texts of the app. The base language: every other file has the same keys.
# The app name is never written here: {app} and {cmd} are filled by Format-Text.
# {0}, {1} are positional arguments; each key says its arguments in a comment when it has any.
# Single quotes only; an apostrophe is written twice. No variables and no [char] (restricted language).
@{
    # Run screen. StatusPaused: {0} = the sleeping glyph. StatusAwake: {0} = the elapsed time.
    StatusPaused       = '{0} Paused - your PC can sleep'
    StatusAwake        = 'Awake for {0}'

    # Help row: the key letters stay in code, only these labels change.
    HelpPause          = 'pause'
    HelpResume         = 'resume'
    HelpScreen         = 'screen'
    HelpF15            = 'F15'
    HelpQuit           = 'quit'
    HelpLanguage       = 'language'
    HelpUninstall      = 'uninstall'

    # Uninstall question.
    ConfirmQuestion    = 'Uninstall {app}?'
    ConfirmYes         = 'yes'
    ConfirmNo          = 'no'
    ConfirmNote        = 'Removes the app, the shortcut and the PATH entry'

    # The three options of the run screen.
    OptionSleep        = 'Keep the PC from sleeping'
    OptionScreen       = 'Keep the screen on'
    OptionKeyPress     = 'Press F15 every minute (keeps chat apps active)'

    # Window title. The glyph in front stays in code.
    TitleAwake         = 'I''m awake!'
    TitlePaused        = '{app} (paused)'

    # One line shows at a time, by active time.
    HumorLines         = @(
        'I''m awake! I''m awake!',
        'Just resting my eyes...',
        'I was listening, I swear.',
        'Yes, I agree with the last point.'
    )

    # Uninstall screen. UninstallRemoving: {0} = the step. UninstallFailedOne/Many: {0} = the count.
    UninstallHeader    = '{app} uninstall'
    UninstallRemoving  = 'Removing: {0}'
    UninstallDone      = 'Done. {app} is removed.'
    UninstallFailedOne = 'Failed: {0} item'
    UninstallFailedMany = 'Failed: {0} items'
    UninstallKept      = 'Kept: %LOCALAPPDATA%\{app} (log, PATH backup, language)'
    PressAnyKeyRow     = 'Press any key to close'
    PressAnyKeyMsg     = 'Press any key to close.'

    # Uninstall steps. ItemFile: {0} = the file name.
    ItemPath           = 'Remove bin from the user PATH'
    ItemShortcut       = 'Remove the desktop shortcut'
    ItemFile           = 'Remove {0}'
    ItemMarker         = 'Remove the install marker'
    ItemBinFolder      = 'Remove the bin folder'
    ItemAppFolder      = 'Remove the app folder'
    ItemLangFolder     = 'Remove the lang folder'

    # uninstall.ps1 messages.
    UninstallNotInstalled = 'Not an installed copy of {app}. Nothing removed.'
    UninstallStillRuns = '{app} still runs. Close it and try again.'

    # The app window. AppStopped: {0} = the error. AppLogPath: {0} = the log path.
    AppAlreadyRunning  = '{app} is already running elsewhere. Closing in 5 seconds.'
    AppStopped         = '{app} stopped: {0}'
    AppLogPath         = 'Log: {0}'

    # The {cmd} command. CliUsage* are the columns of the usage lines.
    # CliAlreadyRunning, CliRunning: {0} = the start time. CliUnknownArgs, CliFailed: {0} = the detail.
    # CliNoTerminal: {0} = the wt.exe path.
    CliUsage           = 'Usage:'
    CliUsageRun        = 'run {app} in this terminal'
    CliUsageWindow     = 'open {app} in a new window'
    CliUsageStatus     = 'say whether {app} runs'
    CliAlreadyRunning  = '{app} is already running since {0}.'
    CliStarted         = '{app} started in a new window.'
    CliRunning         = '{app} is running since {0}.'
    CliNotRunning      = '{app} is not running.'
    CliUnknownArgs     = '{cmd}: unknown arguments: {0}'
    CliFailed          = '{cmd} failed: {0}'
    CliNoTerminal      = 'Windows Terminal not found at {0}'
}
