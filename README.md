# GetIllegals
Репозиторий с шаблоном разработки «Скрипт-анализатор для поиска нелегалов».

## Описание
Шаблон позволяет найти в коде разработки Directum RX запрещенные конструкции.
Чтобы произвести проверку, нужно запустить .bat файл прописав в нем необходимые параметры:

+ **-all all**, при указании которого выводятся все найденные конструкции описанные ниже, без него только 1 и 2.

+ **-path "Путь до проверяемой папки"**, папка в которой необходимо проверить файлы на присутствие запрещенных конструкций. 

+ **> "Путь до файла"**, файл в который будет сохранен результат работы скрипта, без него, вывод в консоль.

Также есть возможность использования данного скрипта при коммите.

### На текущий момент реализована возможность нахождения следующих запрещенных конструкций:
1. Remote-функции в "Обновлении формы".
2. Remote-функции и получение сущностей через Get, GetAll в "Возможности выполнения действий".
3. Создание, удаление, получение сущностей через Get и GetAll не в серверном коде.
4. Использование анонимных типов.
5. Приведение к типу через is, as.
6. Использование запрещенных класов .Net.

## Порядок установки
Скрипт не имеет инсталлятора. Установка не требуется.

Для проверки необходимо:
1. [Скачать](https://tfsozrrx.directum.ru/DefaultCollection/849b60ab-13af-4f70-848e-01b6520ca395/_api/_versioncontrol/itemContentZipped?repositoryId=f6920874-c65e-490d-8f1b-4fe34d4f922c&path=%2F&version=GBmaster&__v=5).
2. Разархивировать в папку с исходными файлами разработки.
3. Изменить файл **Запуск.bat**, указав в нем необходимые параметры.
4. Запустить утилиту с помощью **Запуск.bat**, посмотреть результат работы.



## Модификация
Для модификации скрипта требуется наличие на рабочем месте разработчика интегрированной среды сценариев PowerShell ISE.

Модификация выполняется за счет разработки новых функций для поиска нелегалов с помощью регулярных выражений.
Например, мы хотим добавить поиск серверных функций в "Обновлении формы." Для этого:
1. Необходимо получить все файлы из родительской папки. В данном случае файл будет иметь в имени "Handlers", и так как данный код относится к клиентскому, то полный путь будет содержать "ClientBase".
```
$refreshFiles = Get-ChildItem -Include *.cs -Exclude *.g.cs, *g.i.cs -Recurse | ? { $_.FullName -match '\w*.ClientBase.*(Handlers)' }
```
2. Разработать функцию для поиска серверных функций. Серверные функции в клиентском коде вызываются через Remote. Необходимо найти в файле данные вхождения, и если они есть, то вывести имя файла.
```
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
```
3. Пройтись в цикле по всем отфильтрованным файлам в пункте 1, функцией разработанной на шаге 2.
```
foreach($file in $refreshFiles)
{
    $result = Get-FilesRefreshIllegal($file)
    if ($result -eq 1)
    {
        $exitcode = 1;
    }
}
```
В примере выше реализована возможность блокировки коммита при найденных нелегалах. Если такая функиональность не нужна, необходимо сократить код.
```
function Get-FilesRefreshIllegal ($file)
{
    $content = Get-Content $file.FullName | % { $contentstring += $_ }
    $illegal = $contentstring | Select-String -Pattern ' Refresh\(.*?(Remote|public)' -AllMatches -CaseSensitive
    if ($illegal.Count -ne 0)
    {
        foreach ($match in $illegal.Matches)
        {
            if($match.Value -ne $null -and $match.Value.Contains("Remote"))
            {
                Write-Host $file.FullName
            }
        }
    }
}
foreach($file in $refreshFiles)
{
    Get-FilesRefreshIllegal($file)
}
```
