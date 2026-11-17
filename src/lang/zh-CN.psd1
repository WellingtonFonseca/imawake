# 简体中文文本。键与 en.psd1 相同（有测试检查）。
# 应用名称不写在这里：{app} 和 {cmd} 由 Format-Text 填入。
# {0}、{1} 是按位置的参数，顺序与 en.psd1 相同。
# 单引号；撇号写两次。
# 汉字在终端中占两格宽，所以每行文字要短：帮助行必须比选项行窄。
@{
    # 主界面。
    StatusPaused       = '{0} 已暂停 - 电脑可以休眠'
    StatusAwake        = '已保持清醒 {0}'

    # 帮助行：按键字母留在代码里，只有标签会变。
    HelpPause          = '暂停'
    HelpResume         = '继续'
    HelpScreen         = '屏幕'
    HelpF15            = 'F15'
    HelpQuit           = '退出'
    HelpLanguage       = '语言'
    HelpUninstall      = '卸载'

    # 卸载提问。按键仍然是 y 和 n。
    ConfirmQuestion    = '卸载 {app}？'
    ConfirmYes         = '是'
    ConfirmNo          = '否'
    ConfirmNote        = '删除应用、快捷方式和 PATH 条目'

    # 主界面的三个选项。
    OptionSleep        = '防止电脑休眠'
    OptionScreen       = '保持屏幕常亮'
    OptionKeyPress     = '每分钟按一次 F15（让聊天应用一直保持在线）'

    # 窗口标题。前面的图标留在代码里。
    TitleAwake         = '我醒着！'
    TitlePaused        = '{app}（已暂停）'

    # 每次显示一行，按活动时间切换。
    HumorLines         = @(
        '我醒着！我醒着！',
        '只是闭目养神...',
        '我在听，真的。',
        '是的，我同意最后一点。'
    )

    # 卸载界面。UninstallRemoving：{0} = 步骤。UninstallFailedOne/Many：{0} = 数量。
    UninstallHeader    = '卸载 {app}'
    UninstallRemoving  = '正在删除：{0}'
    UninstallDone      = '完成。{app} 已删除。'
    UninstallFailedOne = '失败：{0} 项'
    UninstallFailedMany = '失败：{0} 项'
    UninstallKept      = '已保留：%LOCALAPPDATA%\{app}（日志、PATH 备份、语言）'
    PressAnyKeyRow     = '按任意键关闭'
    PressAnyKeyMsg     = '按任意键关闭。'

    # 卸载步骤。ItemFile：{0} = 文件名。
    ItemPath           = '从用户 PATH 中移除 bin'
    ItemShortcut       = '删除桌面快捷方式'
    ItemFile           = '删除 {0}'
    ItemMarker         = '删除安装标记'
    ItemBinFolder      = '删除 bin 文件夹'
    ItemAppFolder      = '删除应用文件夹'
    ItemLangFolder     = '删除 lang 文件夹'

    # uninstall.ps1 的消息。
    UninstallNotInstalled = '这不是 {app} 的已安装副本。未删除任何内容。'
    UninstallStillRuns = '{app} 仍在运行。请先关闭它，然后重试。'

    # 应用窗口。AppStopped：{0} = 错误。AppLogPath：{0} = 日志路径。
    AppAlreadyRunning  = '{app} 已在别处运行。5 秒后关闭。'
    AppStopped         = '{app} 已停止：{0}'
    AppLogPath         = '日志：{0}'

    # 命令 {cmd}。CliUsage* 是用法行的各列。
    # CliAlreadyRunning、CliRunning：{0} = 启动时间。CliUnknownArgs、CliFailed：{0} = 详情。
    # CliNoTerminal：{0} = wt.exe 的路径。
    CliUsage           = '用法：'
    CliUsageRun        = '在此终端中运行 {app}'
    CliUsageWindow     = '在新窗口中打开 {app}'
    CliUsageStatus     = '显示 {app} 是否在运行'
    CliAlreadyRunning  = '{app} 自 {0} 起已在运行。'
    CliStarted         = '{app} 已在新窗口中启动。'
    CliRunning         = '{app} 自 {0} 起在运行。'
    CliNotRunning      = '{app} 未在运行。'
    CliUnknownArgs     = '{cmd}：未知参数：{0}'
    CliFailed          = '{cmd} 失败：{0}'
    CliNoTerminal      = '在 {0} 未找到 Windows Terminal'
}
