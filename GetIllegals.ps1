param([string]$path, [string]$all, [string]$mod)
function Get-FilesCreateDeleteGetIllegal ($file)
{
    $illegal = $file | Select-String -Pattern '\w*.(Create|Delete|Get|GetAll)\(' -AllMatches -CaseSensitive
    if ($illegal.Count -gt 0 -or $illegal.Matches.Count -gt 0)
    {
        Write-Host $file.FullName
        
    }
}

function Get-FilesCanExecuteIllegal ($file)
{
    $result = 0
    $content = Get-Content $file.FullName | % { $contentstring += $_ }
    $illegal = $contentstring | Select-String -Pattern 'CanExecute.*?(Remote|public)' -AllMatches -CaseSensitive
    if ($illegal.Count -ne 0)
    {
        foreach ($match in $illegal.Matches)
        {
            if($match.Value -ne $null -and $match.Value.Contains("Remote"))
            {
                Write-Host $file.FullName
                $result = 1
            }
        }
    }
    return $result
}

function Get-FilesRefreshIllegal ($file)
{
    $result = 0
    $content = Get-Content $file.FullName | % { $contentstring += $_ }
    $illegal = $contentstring | Select-String -Pattern ' Refresh\(.*?(Remote|public)' -AllMatches -CaseSensitive
    if ($illegal.Count -ne 0)
    {
        foreach ($match in $illegal.Matches)
        {
            if($match.Value -ne $null -and $match.Value.Contains("Remote"))
            {
                Write-Host $file.FullName
                $result = 1
            }
        }
    }
    return $result
}

function Get-FilesAnonymousIllegal ($file)
{
    $illegal = $file | Select-String -Pattern '\s*new\s+(?!.*List)' -AllMatches -CaseSensitive
    if ($illegal.Count -gt 0 -or $illegal.Matches.Count -gt 0)
    {
        Write-Host $file.FullName
    }
}

function Get-FilesIsAsIllegal ($file)
{
    $illegal = $file | Select-String -Pattern '\s(is|as)\s' -AllMatches -CaseSensitive
    if ($illegal.Count -gt 0 -or $illegal.Matches.Count -gt 0)
    {
        Write-Host $file.FullName
    }
}

function Get-FilesNetClassIllegal ($file)
{
    $illegal = $file | Select-String -Pattern '.*(Tuple|CultureInfo|Convert.To|System.(Windows|Reflection|Xml|Threading|Data))' -AllMatches -CaseSensitive
    if ($illegal.Count -gt 0 -or $illegal.Matches.Count -gt 0)
    {
        Write-Host $file.FullName
    }
}

if ($path -ne $null)
{
    cd $path
}

if ($mod -eq "git")
{
    $modifiedFilesPath = git diff --cached --name-only --diff-filter=ACM --line-prefix="${PWD}\"
    $modifiedFiles = [System.Collections.ArrayList]::new()
    foreach($filePath in $modifiedFilesPath)
    {
        $file = Get-Item $filePath
        $modifiedFiles.Add($file)
    }
    $allFiles = $modifiedFiles;
    $withoutServerFiles = $modifiedFiles;
    $refreshFiles = $modifiedFiles;
    $canExecuteFiles = $modifiedFiles;
}

$exitcode = 0;

if ($all -eq "all")
{
    if($mod -ne "git")
    {
        $allFiles = Get-ChildItem -Include *.cs -Exclude *.xaml.cs, *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -notmatch '\w*.(Debug|AssemblyInfo)' }
        $withoutServerFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -notmatch '\w*.Server' }
    }
    Write-Host "Использование new, as is или запрещенных библиотек NET" -ForegroundColor Yellow
    foreach($file in $allFiles)
    {
        Get-FilesAnonymousIllegal ($file)
        Get-FilesIsAsIllegal($file)
        Get-FilesNetClassIllegal ($file)
    }

    Write-Host "Создание, удаление сущностей или использование Get, GetAll не в серверном коде" -ForegroundColor Yellow
    foreach($file in $withoutServerFiles)
    {
        Get-FilesCreateDeleteGetIllegal($file)
    }

}
if($mod -ne "git")
{
    $refreshFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -match '\w*.ClientBase.*(Handlers)' }
    $canExecuteFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -match '\w*.ClientBase.*Actions' }
}

Write-Host "Вызов серверных функций в Возможность выполнения действий." -ForegroundColor Red
foreach($file in $canExecuteFiles)
{
    $result = Get-FilesCanExecuteIllegal($file)
    if ($result -eq 1)
    {
        $exitcode = 1;
    }
}

Write-Host "Вызов серверных функций в Обновлении формы." -ForegroundColor Red
foreach($file in $refreshFiles)
{
    $result = Get-FilesRefreshIllegal($file)
    if ($result -eq 1)
    {
        $exitcode = 1;
    }
}
exit($exitcode)