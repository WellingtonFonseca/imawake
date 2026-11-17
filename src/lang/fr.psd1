# Textes en français. Mêmes clés que en.psd1 (un test le vérifie).
# Le nom de l'app n'apparaît jamais ici : {app} et {cmd} sont remplis par Format-Text.
# {0}, {1} sont des arguments par position, dans le même ordre que dans en.psd1.
# Guillemets simples ; une apostrophe s'écrit deux fois. Lettres accentuées en forme composée (NFC).
# Pas d'apostrophe typographique ni de ligature oe : la page de codes 850 de la console ne les a pas.
@{
    # Écran principal.
    StatusPaused       = '{0} En pause - votre PC peut se mettre en veille'
    StatusAwake        = 'Éveillé depuis {0}'

    # Ligne d'aide : les lettres des touches restent dans le code, seuls les libellés changent.
    HelpPause          = 'pause'
    HelpResume         = 'reprendre'
    HelpScreen         = 'écran'
    HelpF15            = 'F15'
    HelpQuit           = 'quitter'
    HelpLanguage       = 'langue'
    HelpUninstall      = 'désinstaller'

    # Question de désinstallation. Les touches restent y et n.
    ConfirmQuestion    = 'Désinstaller {app} ?'
    ConfirmYes         = 'oui'
    ConfirmNo          = 'non'
    ConfirmNote        = 'Supprime l''app, le raccourci et l''entrée du PATH'

    # Les trois options de l'écran principal.
    OptionSleep        = 'Empêcher la mise en veille du PC'
    OptionScreen       = 'Garder l''écran allumé'
    OptionKeyPress     = 'Appuyer sur F15 chaque minute (garde les applis de chat actives)'

    # Titre de la fenêtre. Le symbole devant reste dans le code.
    TitleAwake         = 'Je suis réveillé !'
    TitlePaused        = '{app} (en pause)'

    # Une ligne s'affiche à la fois, selon le temps actif.
    HumorLines         = @(
        'Je suis réveillé ! Je suis réveillé !',
        'Je repose juste mes yeux...',
        'J''écoutais, je le jure.',
        'Oui, je suis d''accord avec le dernier point.'
    )

    # Écran de désinstallation. UninstallRemoving : {0} = l'étape. UninstallFailedOne/Many : {0} = le nombre.
    UninstallHeader    = 'Désinstallation de {app}'
    UninstallRemoving  = 'Suppression : {0}'
    UninstallDone      = 'Terminé. {app} est supprimé.'
    UninstallFailedOne = 'Échec : {0} élément'
    UninstallFailedMany = 'Échec : {0} éléments'
    UninstallKept      = 'Conservé : %LOCALAPPDATA%\{app} (journal, copie du PATH, langue)'
    PressAnyKeyRow     = 'Appuyez sur une touche pour fermer'
    PressAnyKeyMsg     = 'Appuyez sur une touche pour fermer.'

    # Étapes de la désinstallation. ItemFile : {0} = le nom du fichier.
    ItemPath           = 'Retirer bin du PATH de l''utilisateur'
    ItemShortcut       = 'Supprimer le raccourci du bureau'
    ItemFile           = 'Supprimer {0}'
    ItemMarker         = 'Supprimer le marqueur d''installation'
    ItemBinFolder      = 'Supprimer le dossier bin'
    ItemAppFolder      = 'Supprimer le dossier de l''app'
    ItemLangFolder     = 'Supprimer le dossier lang'

    # Messages de uninstall.ps1.
    UninstallNotInstalled = 'Ce n''est pas une copie installée de {app}. Rien n''a été supprimé.'
    UninstallStillRuns = '{app} est encore en cours d''exécution. Fermez-le et réessayez.'

    # La fenêtre de l'app. AppStopped : {0} = l'erreur. AppLogPath : {0} = le chemin du journal.
    AppAlreadyRunning  = '{app} s''exécute déjà ailleurs. Fermeture dans 5 secondes.'
    AppStopped         = '{app} s''est arrêté : {0}'
    AppLogPath         = 'Journal : {0}'

    # La commande {cmd}. CliUsage* sont les colonnes des lignes d'usage.
    # CliAlreadyRunning, CliRunning : {0} = l'heure de début. CliUnknownArgs, CliFailed : {0} = le détail.
    # CliNoTerminal : {0} = le chemin de wt.exe.
    CliUsage           = 'Usage :'
    CliUsageRun        = 'exécute {app} dans ce terminal'
    CliUsageWindow     = 'ouvre {app} dans une nouvelle fenêtre'
    CliUsageStatus     = 'indique si {app} s''exécute'
    CliAlreadyRunning  = '{app} s''exécute déjà depuis {0}.'
    CliStarted         = '{app} a démarré dans une nouvelle fenêtre.'
    CliRunning         = '{app} s''exécute depuis {0}.'
    CliNotRunning      = '{app} ne s''exécute pas.'
    CliUnknownArgs     = '{cmd} : arguments inconnus : {0}'
    CliFailed          = '{cmd} a échoué : {0}'
    CliNoTerminal      = 'Windows Terminal introuvable à {0}'
}
