# Textos em português do Brasil. Mesmas chaves do en.psd1 (um teste confere).
# O nome do app nunca aparece aqui: {app} e {cmd} são preenchidos por Format-Text.
# {0}, {1} são argumentos por posição, na mesma ordem do en.psd1.
# Aspas simples; apóstrofo se escreve duas vezes. Letras com acento em forma composta (NFC).
@{
    # Tela principal.
    StatusPaused       = '{0} Em pausa - seu PC pode dormir'
    StatusAwake        = 'Acordado há {0}'

    # Linha de ajuda: as letras das teclas ficam no código, só os rótulos mudam.
    HelpPause          = 'pausar'
    HelpResume         = 'retomar'
    HelpScreen         = 'tela'
    HelpF15            = 'F15'
    HelpQuit           = 'sair'
    HelpLanguage       = 'idioma'
    HelpUninstall      = 'desinstalar'

    # Pergunta de desinstalação. As teclas continuam y e n.
    ConfirmQuestion    = 'Desinstalar {app}?'
    ConfirmYes         = 'sim'
    ConfirmNo          = 'não'
    ConfirmNote        = 'Remove o app, o atalho e a entrada no PATH'

    # As três opções da tela principal.
    OptionSleep        = 'Impedir que o PC durma'
    OptionScreen       = 'Manter a tela ligada'
    OptionKeyPress     = 'Pressionar F15 a cada minuto (mantém apps de chat ativos)'

    # Título da janela. O símbolo na frente fica no código.
    TitleAwake         = 'Estou acordado!'
    TitlePaused        = '{app} (em pausa)'

    # Uma frase por vez, conforme o tempo ativo.
    HumorLines         = @(
        'Estou acordado! Estou acordado!',
        'Só descansando os olhos...',
        'Eu estava ouvindo, juro.',
        'Sim, concordo com o último ponto.'
    )

    # Tela de desinstalação.
    UninstallHeader    = '{app} - desinstalação'
    UninstallRemoving  = 'Removendo: {0}'
    UninstallDone      = 'Pronto. {app} foi removido.'
    UninstallFailedOne = 'Falhou: {0} item'
    UninstallFailedMany = 'Falhou: {0} itens'
    UninstallKept      = 'Mantido: %LOCALAPPDATA%\{app} (log, backup do PATH, idioma)'
    PressAnyKeyRow     = 'Pressione qualquer tecla para fechar'
    PressAnyKeyMsg     = 'Pressione qualquer tecla para fechar.'

    # Passos da desinstalação. ItemFile: {0} = nome do arquivo.
    ItemPath           = 'Remover bin do PATH do usuário'
    ItemShortcut       = 'Remover o atalho da área de trabalho'
    ItemFile           = 'Remover {0}'
    ItemMarker         = 'Remover a marca de instalação'
    ItemBinFolder      = 'Remover a pasta bin'
    ItemAppFolder      = 'Remover a pasta do app'
    ItemLangFolder     = 'Remover a pasta lang'

    # Mensagens do uninstall.ps1.
    UninstallNotInstalled = 'Esta não é uma cópia instalada do {app}. Nada foi removido.'
    UninstallStillRuns = '{app} ainda está em execução. Feche e tente de novo.'

    # A janela do app.
    AppAlreadyRunning  = '{app} já está em execução em outro lugar. Fechando em 5 segundos.'
    AppStopped         = '{app} parou: {0}'
    AppLogPath         = 'Log: {0}'

    # O comando {cmd}.
    CliUsage           = 'Uso:'
    CliUsageRun        = 'executa o {app} neste terminal'
    CliUsageWindow     = 'abre o {app} em uma nova janela'
    CliUsageStatus     = 'diz se o {app} está em execução'
    CliAlreadyRunning  = '{app} já está em execução desde {0}.'
    CliStarted         = '{app} iniciado em uma nova janela.'
    CliRunning         = '{app} está em execução desde {0}.'
    CliNotRunning      = '{app} não está em execução.'
    CliUnknownArgs     = '{cmd}: argumentos desconhecidos: {0}'
    CliFailed          = '{cmd} falhou: {0}'
    CliNoTerminal      = 'Windows Terminal não encontrado em {0}'
}
