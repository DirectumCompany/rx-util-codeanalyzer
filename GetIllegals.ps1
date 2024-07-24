param([string]$path, [string]$all, [string]$mod)

$ErrorMessagePrefix = "[Error]"
$WarningMessagePrefix = "[Warn]"
# Получить изменения добавленные в файл в текущей ветке Git.
function Get-AddedCode ($file)
{
	$firstcommit = git rev-list --min-parents=2 --max-count=1 HEAD
	$diff = git diff $firstcommit HEAD $file
	$addedcode = " "
	foreach ($line in $diff)
	{
		if ($line -like "+*")
		{
			$addedcode = $addedcode + "`n" + $line
		}
	}
	return $addedcode
}

# Поиск вызова Create|Delete|Get|GetAll вне серверных функций
function Get-FilesCreateDeleteGetIllegal ($file, $mod)
{
	$result = 0
	if ($mod -eq "Pipeline")
	{
		$diff = Get-AddedCode $file
		$illegal = $diff | Select-String -Pattern '.*(.(Create|Delete|Get|GetAll))\(.*' -AllMatches -CaseSensitive
	}
	else
	{
		$illegal = $file | Select-String -Pattern '^.*\b(.(Create|Delete|Get|GetAll))\b\(.*$' -AllMatches -CaseSensitive
	}
	if ($illegal.Count -gt 0 -or $illegal.Matches.Count -gt 0)
	{
		foreach ($match in $illegal.Matches)
		{
			Write-Host "$ErrorMessagePrefix" $file.FullName "`t" $match.Value.TrimStart(" ")
			$result = 1
		}
	}
	return $result
}

# Поиск вызова Remote-функций|Get|GetAll в событиях CanExecute
# Технически могут находиться дубли при работе в режиме Pipeline
function Get-FilesCanExecuteIllegal ($file, $mod)
{
	$result = 0
	Get-Content $file.FullName | ForEach-Object { $contentstring += $_ } #Собрать содержимое файла в строку
	# Регулярка будет находить первое значение, последующие в выборку попадать не будут. Последующие нелегалы будут найдены после пуша исправлений предыдущих.
	$illegal = $contentstring | Select-String -Pattern 'CanExecute.*?(Remote|Get\(|GetAll\(|public)' -AllMatches -CaseSensitive
	if ($illegal.Count -ne 0)
	{
		foreach ($match in $illegal.Matches)
		{
			if ($match.Value -ne $null -and ($match.Value.Contains("Remote") -or $match.Value.Contains("Get(") -or $match.Value.Contains("GetAll(")))
			{
				if ($mod -eq "Pipeline")
				{
					$diff = Get-AddedCode $file
					$str = $match.Value.Trim()
					# Написано методом подбора.
					if ($str -match '(\S+[.]|\s)\b(Remote|Get|GetAll|public)')
					{
						$str = $matches[0]
						if ("$diff" -like "*$str*")
						{
							Write-Host "$ErrorMessagePrefix" $file.FullName "`t`t" $match.Value.TrimStart(" ")
							$result = 1
						}
					}
				}
				else
				{
					Write-Host "$ErrorMessagePrefix" $file.FullName "`t`t" $match.Value.TrimStart(" ")
					$result = 1
				}
			}
		}
	}
	return $result
}

# Поиск вызова Remote-функций|Get|GetAll в событии Refresh
function Get-FilesRefreshIllegal ($file, $mod)
{
	$result = 0
	Get-Content $file.FullName | ForEach-Object { $contentstring += $_ } #Собрать содержимое файла в строку
	# Регулярка будет находить первое значение, последующие в выборку попадать не будут. Последующие нелегалы будут найдены после пуша исправлений предыдущих.
	$illegal = $contentstring | Select-String -Pattern ' Refresh\(.*?(Remote|Get\(|GetAll\(|public)' -AllMatches -CaseSensitive
	if ($illegal.Count -ne 0)
	{
		foreach ($match in $illegal.Matches)
		{
			if ($match.Value -ne $null -and ($match.Value.Contains("Remote") -or $match.Value.Contains("Get(") -or $match.Value.Contains("GetAll(")))
			{
				$diff = Get-AddedCode $file
				$str = $match.Value.Trim()
				if ($mod -eq "Pipeline" -and "$diff" -like "*$str*")
				{
					Write-Host "$ErrorMessagePrefix" $file.FullName "`t`t" $match.Value.TrimStart(" ")
					$result = 1
				}
				if ($mod -ne "Pipeline")
				{
					Write-Host "$ErrorMessagePrefix" $file.FullName "`t`t" $match.Value.TrimStart(" ")
					$result = 1
				}
			}
		}
	}
	return $result
}

# Поиск использования Анонимных типов и Создания объектов с помощью new (кроме коллекции List)
function Get-FilesAnonymousIllegal ($file, $mod)
{
	if ($mod -eq "Pipeline")
	{
		$diff = Get-AddedCode $file
		$illegal = $diff | Select-String -Pattern '\s*new\s+(?!.*List)' -AllMatches -CaseSensitive
	}
	else
	{
		$illegal = $file | Select-String -Pattern '\s*new\s+(?!.*List)' -AllMatches -CaseSensitive
	}
	if ($illegal.Count -gt 0 -or $illegal.Matches.Count -gt 0)
	{
		foreach ($match in $illegal.Matches)
		{
			Write-Host "$WarningMessagePrefix" $file.FullName "`t`t" $match.Value.TrimStart(" ")
		}
	}
}

# Поиск Приведения к типу через is, as
function Get-FilesIsAsIllegal ($file, $mod)
{
	if ($mod -eq "Pipeline")
	{
		$diff = Get-AddedCode $file
		$illegal = $diff | Select-String -Pattern '\s(is|as)\s' -AllMatches -CaseSensitive
	}
	else
	{
		$illegal = $file | Select-String -Pattern '\s(is|as)\s' -AllMatches -CaseSensitive
	}
	if ($illegal.Count -gt 0 -or $illegal.Matches.Count -gt 0)
	{
		foreach ($match in $illegal.Matches)
		{
			Write-Host "$WarningMessagePrefix" $file.FullName "`t`t" $match.Value.TrimStart(" ")
		}
	}
}

# Использование Запрещенных классов из .Net
function Get-FilesNetClassIllegal ($file, $mod)
{
	if ($mod -eq "Pipeline")
	{
		$diff = Get-AddedCode $file
		$illegal = $diff | Select-String -Pattern '.*(Tuple|CultureInfo|Convert.To|System.(Windows|Reflection|Xml|Threading|Data))' -AllMatches -CaseSensitive
	}
	else
	{
		$illegal = $file | Select-String -Pattern '.*(Tuple|CultureInfo|Convert.To|System.(Windows|Reflection|Xml|Threading|Data))' -AllMatches -CaseSensitive
	}
	if ($illegal.Count -gt 0 -or $illegal.Matches.Count -gt 0)
	{
		foreach ($match in $illegal.Matches)
		{
			Write-Host "$WarningMessagePrefix" $file.FullName "`t`t" $match.Value.TrimStart(" ")
		}
	}
}

if ($path -ne $null)
{
	Set-Location $path
}

if ($mod -eq "git")
{
	$modifiedFilesPath = git diff --cached --name-only --diff-filter=ACM --line-prefix="${PWD}\"
	$modifiedFiles = [System.Collections.ArrayList]::new()
	foreach ($filePath in $modifiedFilesPath)
	{
		$file = Get-Item $filePath
		$modifiedFiles.Add($file) | Out-Null
	}
	$allFiles = $modifiedFiles
	$withoutServerFiles = $modifiedFiles
	$refreshFiles = $modifiedFiles
	$canExecuteFiles = $modifiedFiles
}

if ($mod -eq "Pipeline")
{
	$firstcommit = git rev-list --min-parents=2 --max-count=1 HEAD
	$modifiedFilesPath = git diff $firstcommit HEAD --name-only '*.cs' ':!*.xaml.cs' ':!*g.i.cs' ':!*.g.cs'
	$modifiedFiles = [System.Collections.ArrayList]::new()
	$withoutServerFiles = [System.Collections.ArrayList]::new()
	$refreshFiles = [System.Collections.ArrayList]::new()
	$canExecuteFiles = [System.Collections.ArrayList]::new()
	foreach ($filePath in $modifiedFilesPath)
	{
		$file = Get-Item $filePath
		if ($file -notmatch '\w*.Server')
		{
			$withoutServerFiles.Add($file) | Out-Null
		}
		if ($file -match '\w*.ClientBase.*(Handlers)')
		{
			$refreshFiles.Add($file) | Out-Null
		}
		if ($file -match '\w*.ClientBase.*Actions')
		{
			$canExecuteFiles.Add($file) | Out-Null
		}
		$modifiedFiles.Add($file) | Out-Null
	}
	$allFiles = $modifiedFiles
}

$exitcode = 0

if ($all -eq "all")
{
	if ($mod -ne "git" -and $mod -ne "Pipeline")
	{
		$allFiles = Get-ChildItem -Include *.cs -Exclude *.xaml.cs, *.g.cs, *g.i.cs -Recurse | Where-Object { $_.FullName -notmatch '\w*.(Debug|AssemblyInfo)' }
		$withoutServerFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | Where-Object { $_.FullName -notmatch '\w*.Server' }
	}

	Write-Host "`n"
	Write-Host "###################################"
	Write-Host "# Rule -> Использование new, as is или запрещенных библиотек .NET." -ForegroundColor Yellow
	foreach ($file in $allFiles)
	{
		Get-FilesAnonymousIllegal $file $mod
		Get-FilesIsAsIllegal $file $mod
		Get-FilesNetClassIllegal $file $mod
	}

	Write-Host "`n"
	Write-Host "###################################"
	Write-Host "# Rule -> Создание, удаление сущностей или использование Get, GetAll вне серверного кода." -ForegroundColor Red
	foreach ($file in $withoutServerFiles)
	{
		$result = Get-FilesCreateDeleteGetIllegal $file $mod
		if ($result -eq 1)
		{
			$exitcode = 1
		}
	}
}

if ($mod -ne "git" -and $mod -ne "Pipeline")
{
	$refreshFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | Where-Object { $_.FullName -match '\w*.ClientBase.*(Handlers)' }
	$canExecuteFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | Where-Object { $_.FullName -match '\w*.ClientBase.*Actions' }
}

Write-Host "`n"
Write-Host "###################################"
Write-Host "# Rule -> Вызов Get, GetAll или серверных функций в Возможности выполнения действий  (CanExecute)." -ForegroundColor Red
foreach ($file in $canExecuteFiles)
{
	$result = Get-FilesCanExecuteIllegal $file $mod
	if ($result -eq 1)
	{
		$exitcode = 1
	}
}

Write-Host "`n"
Write-Host "###################################"
Write-Host "# Rule -> Вызов серверных функций в Обновлении формы (Refresh)." -ForegroundColor Red
foreach ($file in $refreshFiles)
{
	$result = Get-FilesRefreshIllegal $file $mod
	if ($result -eq 1)
	{
		$exitcode = 1
	}
}

Write-Host "###################################"
exit($exitcode)