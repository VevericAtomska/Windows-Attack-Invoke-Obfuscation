Function Invoke-Obfuscation
{
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')] Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ParameterSetName = 'ScriptBlock')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]
        $ScriptBlock,

        [Parameter(Position = 0, ParameterSetName = 'ScriptPath')]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptPath,
        
        [String]
        $Command,
        
        [Switch]
        $NoExit,
        
        [Switch]
        $Quiet
    )

    # Define variables for CLI functionality.
    $Script:CliCommands       = @()
    $Script:CompoundCommand   = @()
    $Script:QuietWasSpecified = $FALSE
    $CliWasSpecified          = $FALSE
    $NoExitWasSpecified       = $FALSE

    # Either convert ScriptBlock to a String or convert script at $Path to a String.
    If($PSBoundParameters['ScriptBlock'])
    {
        $Script:CliCommands += ('set scriptblock ' + [String]$ScriptBlock)
    }
    If($PSBoundParameters['ScriptPath'])
    {
        If (!(Test-Path -Path $ScriptPath -PathType Leaf))
        {
            Write-Error "Script path '$ScriptPath' is invalid."
            return
        }
        $Script:CliCommands += ('set scriptpath ' + $ScriptPath)
    }

    # Append Command to CliCommands if specified by user input.
    If($PSBoundParameters['Command'])
    {
        $Script:CliCommands += $Command.Split(',')
        $CliWasSpecified = $TRUE

        If($PSBoundParameters['NoExit'])
        {
            $NoExitWasSpecified = $TRUE
        }

        If($PSBoundParameters['Quiet'])
        {
            # Create empty Write-Host and Start-Sleep proxy functions to cause any Write-Host or Start-Sleep invocations to not do anything until non-interactive -Command values are finished being processed.
            Function Write-Host {}
            Function Start-Sleep {}
            $Script:QuietWasSpecified = $TRUE
        }
    }

    # Script-wide variable instantiation.
    $Script:ScriptPath   = ''
    $Script:ScriptBlock  = ''
    $Script:CliSyntax         = @()
    $Script:ExecutionCommands = @()
    $Script:ObfuscatedCommand = ''
    $Script:ObfuscatedCommandHistory = @()
    $Script:ObfuscationLength = ''
    $Script:OptionsMenu = @(
        @('ScriptPath', $Script:ScriptPath, $TRUE),
        @('ScriptBlock', $Script:ScriptBlock, $TRUE),
        @('CommandLineSyntax', $Script:CliSyntax, $FALSE),
        @('ExecutionCommands', $Script:ExecutionCommands, $FALSE),
        @('ObfuscatedCommand', $Script:ObfuscatedCommand, $FALSE),
        @('ObfuscationLength', $Script:ObfuscatedCommand, $FALSE)
    )
    # Build out $SetInputOptions from above items set as $TRUE (as settable).
    $SettableInputOptions = @()
    ForEach($Option in $Script:OptionsMenu)
    {
        If($Option[2]) {$SettableInputOptions += ([String]$Option[0]).ToLower().Trim()}
    }

    # Script-level variable for whether LAUNCHER has been applied to current ObfuscatedToken.
    $Script:LauncherApplied = $FALSE

    # Ensure Invoke-Obfuscation module was properly imported before continuing.
    If(!(Get-Module Invoke-Obfuscation | Where-Object {$_.ModuleType -eq 'Manifest'}))
    {
        $PathTopsd1 = "$ScriptDir\Invoke-Obfuscation.psd1"
        If($PathTopsd1.Contains(' ')) {$PathTopsd1 = '"' + $PathTopsd1 + '"'}
        Write-Host "`n`nERROR: Invoke-Obfuscation module is not loaded. You must run:" -ForegroundColor Red
        Write-Host "       Import-Module $PathTopsd1`n`n" -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        Exit
    }

    # Maximum size for cmd.exe and clipboard.
    $CmdMaxLength = 8190
    
    # Build interactive menus.
    $LineSpacing = '[*] '
    
    # Main Menu.
    $MenuLevel = @(
        @($LineSpacing, 'TOKEN', 'Obfuscate PowerShell command <Tokens>'),
        @($LineSpacing, 'AST', "`tObfuscate PowerShell <Ast> nodes <(PS3.0+)>"),
        @($LineSpacing, 'STRING', 'Obfuscate entire command as a <String>'),
        @($LineSpacing, 'ENCODING', 'Obfuscate entire command via <Encoding>'),
        @($LineSpacing, 'COMPRESS', 'Convert entire command to one-liner and <Compress>'),
        @($LineSpacing, 'LAUNCHER', 'Obfuscate command args w/<Launcher> techniques (run once at end)')
    )
    
    # Main\Token Menu.
    $MenuLevel_Token = @(
        @($LineSpacing, 'STRING', 'Obfuscate <String> tokens (suggested to run first)'),
        @($LineSpacing, 'COMMAND', 'Obfuscate <Command> tokens'),
        @($LineSpacing, 'ARGUMENT', 'Obfuscate <Argument> tokens'),
        @($LineSpacing, 'MEMBER', 'Obfuscate <Member> tokens'),
        @($LineSpacing, 'VARIABLE', 'Obfuscate <Variable> tokens'),
        @($LineSpacing, 'TYPE', 'Obfuscate <Type> tokens'),
        @($LineSpacing, 'COMMENT', 'Remove all <Comment> tokens'),
        @($LineSpacing, 'WHITESPACE', 'Insert random <Whitespace> (suggested to run last)'),
        @($LineSpacing, 'ALL', 'Select <All> choices from above (random order)')
    )

    # Additional sub-menus omitted for brevity...

    # Input options to display non-interactive menus or perform actions.
    $TutorialInputOptions         = @(@('tutorial'), "<Tutorial> of how to use this tool")
    $MenuInputOptionsShowHelp     = @(@('help','get-help','?','-?','/?','menu'), "Show this <Help> Menu")
    $MenuInputOptionsShowOptions  = @(@('show options','show','options'), "<Show options> for payload to obfuscate")
    $ClearScreenInputOptions      = @(@('clear','clear-host','cls'), "<Clear> screen")
    $CopyToClipboardInputOptions  = @(@('copy','clip','clipboard'), "<Copy> ObfuscatedCommand to clipboard")
    $OutputToDiskInputOptions     = @(@('out'), "Write ObfuscatedCommand <Out> to disk")
    $ExecutionInputOptions        = @(@('exec','execute','test','run'), "<Execute> ObfuscatedCommand locally")
    $ResetObfuscationInputOptions = @(@('reset'), "<Reset> ALL obfuscation for ObfuscatedCommand")
    $UndoObfuscationInputOptions  = @(@('undo'), "<Undo> LAST obfuscation for ObfuscatedCommand")
    $BackCommandInputOptions      = @(@('back','cd ..'), "Go <Back> to previous obfuscation menu")
    $ExitCommandInputOptions      = @(@('quit','exit'), "<Quit> Invoke-Obfuscation")
    $HomeMenuInputOptions         = @(@('home','main'), "Return to <Home> Menu")
    
    $AllAvailableInputOptionsLists = @(
        $TutorialInputOptions,
        $MenuInputOptionsShowHelp,
        $MenuInputOptionsShowOptions,
        $ClearScreenInputOptions,
        $ExecutionInputOptions,
        $CopyToClipboardInputOptions,
        $OutputToDiskInputOptions,
        $ResetObfuscationInputOptions,
        $UndoObfuscationInputOptions,
        $BackCommandInputOptions,
        $ExitCommandInputOptions,
        $HomeMenuInputOptions
    )

    # Input options to change interactive menus.
    $ExitInputOptions = $ExitCommandInputOptions[0]
    $MenuInputOptions = $BackCommandInputOptions[0]
    
    # Obligatory ASCII Art.
    Show-AsciiArt
    Start-Sleep -Seconds 2
    
    # Show Help Menu once at beginning of script.
    Show-HelpMenu

    Do
    {
        $InputOptionValid = $FALSE
        # Start read-eval loop for user input.
        Do
        {
            $UserInput = (Read-Host -Prompt " Invoke-Obfuscation ")
            # Sanitize input by removing leading/trailing whitespaces and forcing to lowercase.
            $UserInput = $UserInput.Trim().ToLower()

            # If user enters any matching command for non-interactive action, execute it.
            ForEach($OptionList in $AllAvailableInputOptionsLists)
            {
                ForEach($Option in $OptionList[0])
                {
                    If($UserInput -eq $Option)
                    {
                        $InputOptionValid = $TRUE
                        $ActionToPerform = $OptionList[1]
                        Break
                    }
                }
                If($InputOptionValid) {Break}
            }
        }
        Until ($InputOptionValid)

        # Execute chosen action.
        Switch ($ActionToPerform)
        {
            "<Tutorial> of how to use this tool" {Show-Tutorial}
            "Show this <Help> Menu" {Show-HelpMenu}
            "Show options for payload to obfuscate" {Show-Options}
            "<Clear> screen" {Clear-Host}
            "<Copy> ObfuscatedCommand to clipboard" {Copy-ToClipboard}
            "Write ObfuscatedCommand <Out> to disk" {Write-Out}
            "<Execute> ObfuscatedCommand locally" {Execute-Command}
            "<Reset> ALL obfuscation for ObfuscatedCommand" {Reset-Obfuscation}
            "<Undo> LAST obfuscation for ObfuscatedCommand" {Undo-Obfuscation}
            "Go <Back> to previous obfuscation menu" {Return-ToPreviousMenu}
            "<Quit> Invoke-Obfuscation" {Exit}
            "Return to <Home> Menu" {Return-ToHomeMenu}
        }
    }
    Until ($ActionToPerform -eq "<Quit> Invoke-Obfuscation")
}

Function Show-AsciiArt
{
    Write-Host "Invoke-Obfuscation ASCII Art"
}

Function Show-HelpMenu
{
    Write-Host "Help Menu: Available Commands"
}

Function Show-Tutorial
{
    Write-Host "Tutorial: How to Use Invoke-Obfuscation"
}

Function Show-Options
{
    Write-Host "Options: Current Payload Settings"
}

Function Copy-ToClipboard
{
    # Clipboard copy logic
}

Function Write-Out
{
    # Write out logic
}

Function Execute-Command
{
    # Execute command logic
}

Function Reset-Obfuscation
{
    # Reset obfuscation logic
}

Function Undo-Obfuscation
{
    # Undo last obfuscation logic
}

Function Return-ToPreviousMenu
{
    # Return to previous menu logic
}

Function Return-ToHomeMenu
{
    # Return to home menu logic
}
