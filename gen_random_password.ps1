Function Generate-ObfuscatedPassword {
    [CmdletBinding(DefaultParameterSetName = 'Length')]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ParameterSetName = 'Length')]
        [ValidateNotNullOrEmpty()]
        [int]$Length = 12,
        
        [Switch]$IncludeSpecialCharacters,
        [Switch]$ObfuscateUppercase,
        [Switch]$ObfuscateNumbers,
        [Switch]$Quiet
    )

    # Define character sets
    $lowercase = "abcdefghijklmnopqrstuvwxyz"
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $numbers = "0123456789"
    $special = "!@#$%^&*()-_=+[]{}|;:',.<>?/"

    # Combine character sets based on parameters
    $characterSet = $lowercase
    if ($IncludeSpecialCharacters) {
        $characterSet += $special
    }
    $characterSet += $numbers

    # Generate random password
    $password = -join ((1..$Length) | ForEach-Object { $characterSet | Get-Random })

    # Obfuscate the password based on selected options
    if ($ObfuscateUppercase) {
        $password = $password -replace "[A-Z]", { $lowercase[$lowercase.IndexOf($_.Value.ToLower())] }
    }
    if ($ObfuscateNumbers) {
        $password = $password -replace "\d", { ($numbers.IndexOf($_.Value) + 1) % 10 }
    }

    # Output the password
    if (-not $Quiet) {
        Write-Host "Generated Password: $password" -ForegroundColor Green
    }

    return $password
}

# Define the interactive menu
Function Show-PasswordMenu {
    Param (
        [String]$MenuName
    )

    $MenuOptions = @(
        @{Option = '1'; Description = 'Generate password with default settings'; Command = { Generate-ObfuscatedPassword } },
        @{Option = '2'; Description = 'Generate password with special characters'; Command = { Generate-ObfuscatedPassword -IncludeSpecialCharacters } },
        @{Option = '3'; Description = 'Generate password with obfuscated uppercase letters'; Command = { Generate-ObfuscatedPassword -ObfuscateUppercase } },
        @{Option = '4'; Description = 'Generate password with obfuscated numbers'; Command = { Generate-ObfuscatedPassword -ObfuscateNumbers } },
        @{Option = '5'; Description = 'Generate password with all options'; Command = { Generate-ObfuscatedPassword -IncludeSpecialCharacters -ObfuscateUppercase -ObfuscateNumbers } },
        @{Option = '6'; Description = 'Exit'; Command = { return } }
    )

    Write-Host "`n$MenuName"
    $MenuOptions | ForEach-Object { Write-Host "$($_.Option). $($_.Description)" }

    $selection = Read-Host "Choose an option"
    $selectedOption = $MenuOptions | Where-Object { $_.Option -eq $selection }

    if ($selectedOption) {
        & $selectedOption.Command
        if ($selection -ne '6') {
            Show-PasswordMenu -MenuName $MenuName
        }
    } else {
        Write-Host "Invalid selection, please try again." -ForegroundColor Red
        Show-PasswordMenu -MenuName $MenuName
    }
}

# Start the interactive menu
Show-PasswordMenu -MenuName "Password Generator Menu"
