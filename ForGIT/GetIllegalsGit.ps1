function Get-FilesCreateDeleteGetIllegal ($file)
{
    $illegal = $file | Select-String -Pattern '\w*.(Create|Delete|Get|GetAll)\(' -AllMatches -CaseSensitive
    if ($illegal.Matches.Count -ne 0)
    {
        $file.FullName
    }
}

function Get-FilesCanExecuteIllegal ($file)
{
    $content = Get-Content $file.FullName | % { $contentstring += $_ }
    $illegal = @($contentstring | Select-String -Pattern 'CanExecute.*?(Remote|public)' -AllMatches -CaseSensitive).Matches
    foreach ($match in $illegal)
    {
        if($match.Value.Contains("Remote"))
        {
            Write-Host $file.FullName
            $result = 1
        }
    }
    return $result
}

function Get-FilesRefreshIllegal ($file)
{
    $content = Get-Content $file.FullName | % { $contentstring += $_ }
    $illegal = @($contentstring | Select-String -Pattern 'Refresh.*?(Remote|public)' -AllMatches -CaseSensitive).Matches
    foreach ($match in $illegal)
    {
        if($match.Value.Contains("Remote"))
        {
            Write-Host $file.FullName
            $result = 1
        }
    }
    return $result
}

function Get-FilesAnonymousIllegal ($file)
{
    $illegal = $file | Select-String -Pattern '\s*new\s+(?!.*List)' -AllMatches -CaseSensitive
    if ($illegal.Matches.Count -ne 0)
    {
        $file.FullName
    }
}

function Get-FilesIsAsIllegal ($file)
{
    $illegal = $file | Select-String -Pattern '\s(is|as)\s' -AllMatches -CaseSensitive
    if ($illegal.Matches.Count -ne 0)
    {
        $file.FullName
    }
}

function Get-FilesNetClassIllegal ($file)
{
    $illegal = $file | Select-String -Pattern '.*(Tuple|CultureInfo|Convert.To|System.(Windows|Reflection|Xml|Threading|Data))' -AllMatches -CaseSensitive
    if ($illegal.Matches.Count -ne 0)
    {
        $file.FullName
    }
}
$modifiedFilesPath = git diff --cached --name-only --diff-filter=ACM --line-prefix="${PWD}\"
$modifiedFiles = [System.Collections.ArrayList]::new()
$result = 0;
foreach($filePath in $modifiedFilesPath)
{
    $file = Get-Item $filePath
    $modifiedFiles.Add($file)
}


if ($all -eq "all")
{
    Write-Host "Использование new, as is или запрещенных библиотек NET" -ForegroundColor Yellow
    foreach($file in $modifiedFiles)
    {
        Get-FilesAnonymousIllegal ($file)
        Get-FilesIsAsIllegal($file)
        Get-FilesNetClassIllegal ($file)
    }

    Write-Host "Создание, удаление сущностей или использование Get, GetAll не в серверном коде" -ForegroundColor Yellow
    foreach($file in $modifiedFiles)
    {
        Get-FilesCreateDeleteGetIllegal($file)
    }

}

Write-Host "Вызов серверных функций в Возможность выполнения действий." -ForegroundColor Red
foreach($file in $modifiedFiles)
{
    $result = Get-FilesCanExecuteIllegal($file)
}

Write-Host "Вызов серверных функций в Обновлении формы." -ForegroundColor Red
foreach($file in $modifiedFiles)
{
    $result = Get-FilesRefreshIllegal($file)
}

if ($result -ne 0)
{
    exit (1)
}