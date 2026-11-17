# Textos en español. Mismas claves que en.psd1 (un test lo comprueba).
# El nombre de la app nunca aparece aquí: {app} y {cmd} los rellena Format-Text.
# {0}, {1} son argumentos por posición, en el mismo orden que en en.psd1.
# Comillas simples; un apóstrofo se escribe dos veces. Letras con acento en forma compuesta (NFC).
# Sin comillas ni apóstrofos tipográficos: la página de códigos 850 de la consola no los tiene.
@{
    # Pantalla principal.
    StatusPaused       = '{0} En pausa - tu PC puede dormir'
    StatusAwake        = 'Despierto desde hace {0}'

    # Fila de ayuda: las letras de las teclas quedan en el código, solo cambian las etiquetas.
    HelpPause          = 'pausar'
    HelpResume         = 'reanudar'
    HelpScreen         = 'pantalla'
    HelpF15            = 'F15'
    HelpQuit           = 'salir'
    HelpLanguage       = 'idioma'
    HelpUninstall      = 'desinstalar'

    # Pregunta de desinstalación. Las teclas siguen siendo y y n.
    ConfirmQuestion    = '¿Desinstalar {app}?'
    ConfirmYes         = 'sí'
    ConfirmNo          = 'no'
    ConfirmNote        = 'Quita la app, el acceso directo y la entrada del PATH'

    # Las tres opciones de la pantalla principal.
    OptionSleep        = 'Evitar que el PC se suspenda'
    OptionScreen       = 'Mantener la pantalla encendida'
    OptionKeyPress     = 'Pulsar F15 cada minuto (mantiene activas las apps de chat)'

    # Título de la ventana. El símbolo delante queda en el código.
    TitleAwake         = '¡Estoy despierto!'
    TitlePaused        = '{app} (en pausa)'

    # Se muestra una línea a la vez, según el tiempo activo.
    HumorLines         = @(
        '¡Estoy despierto! ¡Estoy despierto!',
        'Solo descanso la vista...',
        'Te estaba escuchando, lo juro.',
        'Sí, estoy de acuerdo con el último punto.'
    )

    # Pantalla de desinstalación. UninstallRemoving: {0} = el paso. UninstallFailedOne/Many: {0} = la cantidad.
    UninstallHeader    = 'Desinstalación de {app}'
    UninstallRemoving  = 'Quitando: {0}'
    UninstallDone      = 'Listo. {app} se quitó.'
    UninstallFailedOne = 'Falló: {0} elemento'
    UninstallFailedMany = 'Fallaron: {0} elementos'
    UninstallKept      = 'Se conserva: %LOCALAPPDATA%\{app} (registro, copia del PATH, idioma)'
    PressAnyKeyRow     = 'Pulsa una tecla para cerrar'
    PressAnyKeyMsg     = 'Pulsa una tecla para cerrar.'

    # Pasos de la desinstalación. ItemFile: {0} = el nombre del archivo.
    ItemPath           = 'Quitar bin del PATH del usuario'
    ItemShortcut       = 'Quitar el acceso directo del escritorio'
    ItemFile           = 'Quitar {0}'
    ItemMarker         = 'Quitar la marca de instalación'
    ItemBinFolder      = 'Quitar la carpeta bin'
    ItemAppFolder      = 'Quitar la carpeta de la app'
    ItemLangFolder     = 'Quitar la carpeta lang'

    # Mensajes de uninstall.ps1.
    UninstallNotInstalled = 'No es una copia instalada de {app}. No se quitó nada.'
    UninstallStillRuns = '{app} sigue en ejecución. Ciérrala e inténtalo de nuevo.'

    # La ventana de la app. AppStopped: {0} = el error. AppLogPath: {0} = la ruta del registro.
    AppAlreadyRunning  = '{app} ya se está ejecutando en otro lugar. Se cierra en 5 segundos.'
    AppStopped         = '{app} se detuvo: {0}'
    AppLogPath         = 'Registro: {0}'

    # El comando {cmd}. CliUsage* son las columnas de las líneas de uso.
    # CliAlreadyRunning, CliRunning: {0} = la hora de inicio. CliUnknownArgs, CliFailed: {0} = el detalle.
    # CliNoTerminal: {0} = la ruta de wt.exe.
    CliUsage           = 'Uso:'
    CliUsageRun        = 'ejecuta {app} en este terminal'
    CliUsageWindow     = 'abre {app} en una ventana nueva'
    CliUsageStatus     = 'indica si {app} se está ejecutando'
    CliAlreadyRunning  = '{app} ya se está ejecutando desde {0}.'
    CliStarted         = '{app} se inició en una ventana nueva.'
    CliRunning         = '{app} se está ejecutando desde {0}.'
    CliNotRunning      = '{app} no se está ejecutando.'
    CliUnknownArgs     = '{cmd}: argumentos desconocidos: {0}'
    CliFailed          = '{cmd} falló: {0}'
    CliNoTerminal      = 'No se encontró Windows Terminal en {0}'
}
