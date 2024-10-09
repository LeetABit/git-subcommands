$currentDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repositoryDirectory = Split-Path -Path $currentDirectory -Parent
$srcPath = Join-Path -Path $repositoryDirectory -ChildPath 'src'
$tempPath = Join-Path -Path $currentDirectory -ChildPath 'temp'
if (-not (@($env:PATH -split ';') -contains $srcPath)) {
    $env:PATH += ";$srcPath"
}

$fileName = $MyInvocation.MyCommand.Name
Get-ChildItem -Path $currentDirectory -Filter "*.ps1" |
    Where-Object { $_.Name -ne $fileName } |
    ForEach-Object {
    $file = $_
    $null = New-Item -Path $tempPath -ItemType Directory -ErrorAction SilentlyContinue
    Push-Location $tempPath
    try {
        $expected = (& $file.FullName)[-1]
        $output = (git semver -v -t -a 2>&1)
        $version = $output[-1]
        Write-Information "$($file.Name)" -InformationAction Continue
        if ($expected -ne $version) {
            throw "  Expected '$expected' but got '$version'.`nOutput: $output"
        } else {
            Write-Information "  OK" -InformationAction Continue
        }
    }
    finally {
        Pop-Location
        Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
