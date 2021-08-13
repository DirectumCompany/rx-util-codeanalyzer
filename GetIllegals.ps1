param([string]$path, [string]$all)
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
            $file.FullName
        }
    }
}

function Get-FilesRefreshIllegal ($file)
{
    $content = Get-Content $file.FullName | % { $contentstring += $_ }
    $illegal = @($contentstring | Select-String -Pattern ' Refresh\(.*?(Remote|public)' -AllMatches -CaseSensitive).Matches
    foreach ($match in $illegal)
    {
        if($match.Value.Contains("Remote"))
        {
            $file.FullName
        }
    }
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

if ($path -ne $null)
{
    cd $path
}
if ($all -eq "all")
{
    $allFiles = Get-ChildItem -Include *.cs -Exclude *.xaml.cs, *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -notmatch '\w*.(Debug|AssemblyInfo)' }
    $withoutServerFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -notmatch '\w*.Server' }

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

$refreshFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -match '\w*.ClientBase.*(Handlers)' }
$canExecuteFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -match '\w*.ClientBase.*Actions' }

Write-Host "Вызов серверных функций в Возможность выполнения действий." -ForegroundColor Red
foreach($file in $canExecuteFiles)
{
    Get-FilesCanExecuteIllegal($file)
}

Write-Host "Вызов серверных функций в Обновлении формы." -ForegroundColor Red
foreach($file in $refreshFiles)
{
    Get-FilesRefreshIllegal($file)
}


powershell -noexit