# Verificação automática do projeto (rode antes de todo commit):
#   powershell -ExecutionPolicy Bypass -File scripts/verificar.ps1
#
# 1) Sintaxe de todos os .luau (luau-compile)
# 2) Nomes desconhecidos / variáveis com erro de digitação (luau-analyze, ignorando globais do Roblox)
# 3) Chamadas Modulo.funcao que não existem no módulo de destino
# 4) Gera o MMOTESTE.rbxlx com o Rojo
#
# Precisa de tools/rojo.exe, tools/luau-compile.exe e tools/luau-analyze.exe
# (https://github.com/rojo-rbx/rojo/releases e https://github.com/luau-lang/luau/releases).

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$falhas = 0

function Ferramenta($nome) {
	$caminho = Join-Path $root "tools\$nome"
	if (Test-Path $caminho) { return $caminho }
	$comando = Get-Command ($nome -replace "\.exe$", "") -ErrorAction SilentlyContinue
	if ($comando) { return $comando.Source }
	return $null
}

$arquivos = Get-ChildItem src -Recurse -Filter *.luau

# 1) Sintaxe
$compile = Ferramenta "luau-compile.exe"
if ($compile) {
	Write-Host "== 1) Sintaxe ==" -ForegroundColor Cyan
	foreach ($f in $arquivos) {
		$saida = & $compile --null $f.FullName 2>&1
		if ($LASTEXITCODE -ne 0) {
			$falhas++
			Write-Host ($saida | Out-String) -ForegroundColor Red
		}
	}
	Write-Host "Arquivos: $($arquivos.Count)"
} else {
	Write-Host "luau-compile.exe não encontrado em tools/ (pulando sintaxe)" -ForegroundColor Yellow
}

# 2) Análise
$analyze = Ferramenta "luau-analyze.exe"
if ($analyze) {
	Write-Host "== 2) Análise ==" -ForegroundColor Cyan
	$globais = 'game|workspace|script|Instance|Vector3|Vector2|CFrame|Color3|UDim2|UDim|Enum|TweenInfo|NumberSequence|ColorSequence|NumberRange|Random|task|typeof|warn|tick|os|Region3|RaycastParams|NumberSequenceKeypoint|ColorSequenceKeypoint|Ray|DateTime|utf8|Font|Rect|BrickColor|PhysicalProperties'
	$saida = & $analyze --formatter=plain ($arquivos.FullName) 2>&1 | ForEach-Object { "$_" }
	$relevante = $saida | Where-Object {
		$_ -notmatch "Unknown global '($globais)'" -and
		$_ -notmatch "Unknown type '($globais)'" -and
		$_ -notmatch "Type inference failed to complete" -and
		$_ -notmatch "LocalUnused"
	}
	if ($relevante) {
		$falhas++
		$relevante | ForEach-Object { Write-Host $_ -ForegroundColor Red }
	} else {
		Write-Host "Sem problemas."
	}
} else {
	Write-Host "luau-analyze.exe não encontrado em tools/ (pulando análise)" -ForegroundColor Yellow
}

# 3) Chamadas entre módulos
Write-Host "== 3) Chamadas entre módulos ==" -ForegroundColor Cyan
$definicoes = @{}
foreach ($f in $arquivos) {
	$nome = if ($f.BaseName -like "init*") { $f.Directory.Name } else { $f.BaseName }
	$conteudo = Get-Content $f.FullName -Raw
	$conjunto = New-Object System.Collections.Generic.HashSet[string]
	foreach ($m in [regex]::Matches($conteudo, "(?m)^\s*function\s+$nome[\.:](\w+)")) { [void]$conjunto.Add($m.Groups[1].Value) }
	foreach ($m in [regex]::Matches($conteudo, "(?m)^\s*$nome\.(\w+)\s*=")) { [void]$conjunto.Add($m.Groups[1].Value) }
	$definicoes[$nome] = $conjunto
}
$problemas = @()
foreach ($f in $arquivos) {
	$conteudo = Get-Content $f.FullName -Raw
	foreach ($modulo in $definicoes.Keys) {
		if ($modulo -in @("Client", "Server", "WorldGen", "Remotes")) { continue }
		foreach ($m in [regex]::Matches($conteudo, "(?<![\w\.])$modulo\.(\w+)")) {
			if (-not $definicoes[$modulo].Contains($m.Groups[1].Value)) {
				$problemas += "$($f.Name): $modulo.$($m.Groups[1].Value) não existe em $modulo"
			}
		}
	}
}
$problemas = $problemas | Sort-Object -Unique
if ($problemas) {
	$falhas++
	$problemas | ForEach-Object { Write-Host $_ -ForegroundColor Red }
} else {
	Write-Host "Sem problemas."
}

# 4) Build
$rojo = Ferramenta "rojo.exe"
if ($rojo) {
	Write-Host "== 4) Build ==" -ForegroundColor Cyan
	& $rojo build default.project.json -o MMOTESTE.rbxlx
	if ($LASTEXITCODE -ne 0) { $falhas++ }
} else {
	Write-Host "rojo.exe não encontrado em tools/ (pulando build)" -ForegroundColor Yellow
}

Write-Host ""
if ($falhas -gt 0) {
	Write-Host "FALHOU: $falhas etapa(s) com problema." -ForegroundColor Red
	exit 1
}
Write-Host "OK: tudo certo. Lembre de testar no Studio (Play) também." -ForegroundColor Green
exit 0
