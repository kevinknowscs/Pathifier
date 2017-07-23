###############################################################################
# FUNCTIONS
###############################################################################

function ChangeTo-PathForFile {
  param (
    [parameter(mandatory=$true, ValueFromRemainingArguments=$true)][string] $file
  )

  Get-Path | Search-Path $file | ChangeTo-Path 0
}

function ChangeTo-Path {
  [CmdletBinding()]
  param (
    [parameter(ValueFromPipeline=$true)] $piped,
    [parameter(mandatory=$false, position=2, ValueFromRemainingArguments=$true)][string] $index
  )

  begin {
    $current = 0
  }

  process {
    if ($current++ -eq $index) {
      if (Test-Path -Path $piped.Path) {
        Push-Location $piped.Path
      }
      break;
    }
  }
}

function Get-Env {
  Get-ChildItem Env:
}

function Get-MachineEnv {
  [System.Environment]::GetEnvironmentVariables("Machine")
}

function Get-MachinePath {
  [CmdletBinding()]
  param (
    [switch] $raw
  )

  if ($raw) {
    $hive = [Microsoft.Win32.Registry]::LocalMachine
    $key = $hive.OpenSubKey("System\CurrentControlSet\Control\Session Manager\Environment")
    $text = $key.GetValue("Path", $False, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $paths = $text.split(";")
    $index = 0

    foreach ($path in $paths) {
      $hash_obj = @{ Source = "Machine"; SourceIndex = $index++; Expanded = $false; Path = $path }
      $ps_obj = New-Object -TypeName PSObject -Property $hash_obj | select SourceIndex, Source, Expanded, Path
      Write-Output $ps_obj
    }
  }
  else {
    Get-PathFromEnvironment "Machine"
  }
}

function Get-PathFromEnvironment($target) {
  $text = [System.Environment]::GetEnvironmentVariable("Path", $target)
  if ($text -eq $null) {
    return
  }

  Get-PathFromSemicolonText $text
}

function Get-PathFromSemicolonText($text) {
  $paths = $text.split(";")

  $index = 0

  function MakePathHashFromEnvSource($source) {
    $path_hash = @{}
    $path_text = [System.Environment]::GetEnvironmentVariable("Path", $source)
    if ($path_text -ne $null) {
      $path_index = 0
      foreach ($path in $path_text.split(";")) {
        $path_hash[$path] = $path_index++
      }
    }

    return $path_hash
  }

  $machine_path_hash = MakePathHashFromEnvSource "Machine"
  $user_path_hash = MakePathHashFromEnvSource "user"

  foreach ($path in $paths) {
    if ($machine_path_hash[$path] -ne $null -and $user_path_hash[$path] -ne $null) {
      $hash_obj = @{ SessionIndex = $index++; Source = "Multiple"; SourceIndex = $null; Expanded = $true; Path = $path }
    }
    elseif ($machine_path_hash[$path] -ne $null) {
      $hash_obj = @{ SessionIndex = $index++; Source = "Machine"; SourceIndex = $machine_path_hash[$path]; Expanded = $true; Path = $path }
    }
    elseif ($user_path_hash[$path] -ne $null) {
      $hash_obj = @{ SessionIndex = $index++; Source = "User"; SourceIndex = $user_path_hash[$path]; Expanded = $true; Path = $path }
    }
    else {
      $hash_obj = @{ SessionIndex = $index++; Source = "Session"; SourceIndex = $null; Expanded = $true; Path = $path }
    }
    $ps_obj = New-Object -TypeName PSObject -Property $hash_obj | select SessionIndex, Source, SourceIndex, Expanded, Path
    Write-Output $ps_obj
  }
}


function Get-Path {
  if ($env:Path -eq $null) {
    return
  }

  Get-PathFromSemicolonText $env:Path
}

function Get-RunningService {
  Get-Service | Where-Object -property status -eq running
}

function Get-StoppedService {
  Get-Service | Where-Object -property status -eq stopped
}

function Get-UserEnv {
  [System.Environment]::GetEnvironmentVariables("User")
}

function Get-UserPath {
  [CmdletBinding()]
  param (
    [switch] $raw
  )

  if ($raw) {
    $hive = [Microsoft.Win32.Registry]::CurrentUser
    $key = $hive.OpenSubKey("Environment")
    $text = $key.GetValue("Path", $False, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $paths = $text.split(";")
    $index = 0

    foreach ($path in $paths) {
      $hash_obj = @{ Source = "User"; SourceIndex = $index++; Expanded = $false; Path = $path }
      $ps_obj = New-Object -TypeName PSObject -Property $hash_obj | select SourceIndex, Source, Expanded, Path
      Write-Output $ps_obj
    }
  }
  else {
    Get-PathFromEnvironment "User"
  }
}

function Insert-Path {
  param(
    [parameter(mandatory=$false)][string] $source,
    [parameter(mandatory=$false)][int] $index,
    [parameter(mandatory=$false)][switch] $save,
    [parameter(mandatory=$false)][switch] $append,
    [parameter(mandatory=$false, ValueFromRemainingArguments=$true)][string] $remaining
  )

  echo "`$source = $source"
  echo "`$index = $index"
  echo "`$save = $save"
  echo "`$remaining = $remaining"

  # If save, then the value should be specified as the unexpanded version
  # But how do I expand the path to put it into the current session?
  # One option is I could just reload everything


}

function Reload-Path {
  [CmdletBinding()]
  param (
    [switch] $clear
  )

  if ($clear) {
    $user_path = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $machine_path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $env:Path = "$user_path;$machine_path" 
  }
  else {
    foreach ($level in "Machine", "User") {
      [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
        # For Path variables, append the new values, if they're not already in there
        if($_.Name -match 'Path$') { 
           $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
        }
        $_
      } | Set-Content -Path { "Env:$($_.Name)" }
    }
  }
}

function Remove-MachineEnv {
  [CmdletBinding()]
  param (
    [parameter(mandatory=$true)][string] $name
  )

  [System.Environment]::SetEnvironmentVariable($name, $null, "Machine")
}

function Remove-UserEnv {
  [CmdletBinding()]
  param (
    [parameter(mandatory=$true)][string] $name
  )

  [System.Environment]::SetEnvironmentVariable($name, $null, "User")
}

function Search-Path {
  [CmdletBinding()]
  param (
    [parameter(ValueFromPipeline=$true)] $piped,
    [parameter(mandatory=$false, position=2, ValueFromRemainingArguments=$true)][string] $remaining
  )

  begin {
    $index = 0

    function Process-Object($record) {
      if (-not [string]::IsNullOrWhiteSpace($record.Path) -and (Test-Path $record.Path)) {
        Get-ChildItem -Path $record.Path -Filter $remaining | ForEach-Object {
          $curr_index = Get-Variable -Name index -ValueOnly -Scope 1
          $hash_obj = @{ Index = $curr_index++; Path = $record.Path; Name = $_.Name }
          Set-Variable -Name index -Value $curr_index -Scope 1
          $ps_obj = New-Object -TypeName PSObject -Property $hash_obj | Select-Object Index, Path, Name
          Write-Output $ps_obj
        }
      }
    }

    if (-not $PSCmdlet.MyInvocation.ExpectingInput) {
      $default_input = Get-Path

      foreach ($item in $default_input) {
        Process-Object $item
      }
    }
  }

  process {
    Process-Object $piped
  }
}

function Set-MachineEnv {
  [CmdletBinding()]
  param (
    [parameter(mandatory=$true)][string] $name,
    [parameter(mandatory=$true)][string] $value
  )

  [System.Environment]::SetEnvironmentVariable($name, $value, "Machine")
}

function Set-UserEnv {
  [CmdletBinding()]
  param (
    [parameter(mandatory=$true)][string] $name,
    [parameter(mandatory=$true)][string] $value
  )

  [System.Environment]::SetEnvironmentVariable($name, $value, "User")
}

function Where-Any {
  [CmdletBinding()]
  param (
    [parameter(ValueFromPipeline=$true)] $piped,
    [parameter(mandatory=$true, position=2, ValueFromRemainingArguments=$true)][string] $remaining
  )

  process {
    foreach ($p in $piped.psobject.properties) {
      if (($p.MemberType -eq "Property" -or $p.MemberType -eq "NoteProperty") -and $p.Value -match $remaining) { 
        write-output $piped 
        return
      }
    }
  }
}

function Where-Name {
  [CmdletBinding()]
  param (
    [parameter(ValueFromPipeline=$true)] $piped,
    [parameter(mandatory=$true, position=2, ValueFromRemainingArguments=$true)][string] $remaining
  )

  process {
    foreach ($p in $piped.psobject.properties) {
      if (($p.MemberType -eq "Property" -or $p.MemberType -eq "NoteProperty") -and $p.Name -match "Name" -and $p.Value -match $remaining) { 
        write-output $piped 
        return
      }
    }
  }
}

###############################################################################
# HELP
###############################################################################

function Help-Extra {
  echo ""
  echo "Extra Commands"
  echo "--------------"
  echo "Get-MachineEnv      : ..."
  echo "Get-MachinePath     : ..."
  echo "Get-Path            : ..."
  echo "Get-RunningService  : Lists running services"
  echo "Get-StoppedService  : Lists stopped services"
  echo "Get-UserEnv         : ..."
  echo "Get-UserPath        : ..."
  echo "Help-Extra          : Prints this list"
  echo "Reload-Path         : Reloads the session path from the environment"
  echo ""
  echo "Getting Help"
  echo "------------"
  echo "Help-Extra          : Prints this list"
  echo "myhelp              : Alias for Help-Extra"
  echo ""
  echo "Extra Pipeline Functions"
  echo "------------------------"
  echo "where-any           : Searches for term in any property of input object"
  echo ""
  echo "Aliases"
  echo "-------"
  echo "env         -> write-env"
  echo "lookfor     -> where-any"
  echo "machinepath -> write-machinepath"
  echo "myhelp      -> help-extra"
  echo "path        -> get-path"
  echo "running     -> get-runningservice"
  echo "stopped     -> get-stoppedservice"
  echo "userpath    -> write-userpath"
  echo ""
  echo "Profile Management"
  echo "------------------"
  echo "`$profile = $profile"
  echo "To reload profile, issue: . `$profile"
  echo ""
}

###############################################################################
# POWERSHELL ABBREVIATION ALIASES
###############################################################################

Set-Alias -Name ctpff -Value ChangeTo-PathForFile
Set-Alias -Name ctp   -Value ChangeTo-Path
Set-Alias -Name gme   -Value Get-MachineEnv
Set-Alias -Name gmp   -Value Get-MachinePath
Set-Alias -Name grs   -Value Get-RunningService
Set-Alias -Name gss   -Value Get-StoppedService
Set-Alias -Name gue   -Value Get-UserEnv
Set-Alias -Name gup   -Value Get-UserPath

###############################################################################
# NATURAL LANGUAGE ALIASES
###############################################################################

Set-Alias -Name cdfile      -Value ChangeTo-PathForFile
Set-Alias -Name cdpath      -Value ChangeTo-Path
Set-Alias -Name env         -Value Get-Env
Set-Alias -Name list        -Value Format-List
Set-Alias -Name lookfor     -Value Where-Any
Set-Alias -Name machinepath -Value Get-MachinePath
Set-Alias -Name myhelp      -Value Help-Extra
Set-Alias -Name path        -Value Get-Path
Set-Alias -Name running     -Value get-RunningService
Set-Alias -Name stopped     -Value Get-StoppedService
Set-Alias -Name table       -Value Format-Table
Set-Alias -Name userpath    -Value Get-UserPath
