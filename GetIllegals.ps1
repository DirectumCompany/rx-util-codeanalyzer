param([string]$path, [string]$all, [string]$mod)
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
    $illegal = @($contentstring | Select-String -Pattern ' Refresh\(.*?(Remote|public)' -AllMatches -CaseSensitive).Matches
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

$result = 0;


if ($all -eq "all")
{
    if($mod -ne "git")
    {
        $allFiles = Get-ChildItem -Include *.cs -Exclude *.xaml.cs, *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -notmatch '\w*.(Debug|AssemblyInfo)' }
        $withoutServerFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -notmatch '\w*.Server' }
    }
    Write-Host "������������� new, as is ��� ����������� ��������� NET" -ForegroundColor Yellow
    foreach($file in $allFiles)
    {
        Get-FilesAnonymousIllegal ($file)
        Get-FilesIsAsIllegal($file)
        Get-FilesNetClassIllegal ($file)
    }

    Write-Host "��������, �������� ��������� ��� ������������� Get, GetAll �� � ��������� ����" -ForegroundColor Yellow
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

Write-Host "����� ��������� ������� � ����������� ���������� ��������." -ForegroundColor Red
foreach($file in $canExecuteFiles)
{
    $result = Get-FilesCanExecuteIllegal($file)
}

Write-Host "����� ��������� ������� � ���������� �����." -ForegroundColor Red
foreach($file in $refreshFiles)
{
    $result = Get-FilesRefreshIllegal($file)
}

if ($result -ne 0)
{
    exit (1)
}