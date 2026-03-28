$flagMappings = @{
    "afghanistan2.png" = "afghanistan.png"
    "Algeria2.png" = "algeria.png"
    "America2.png" = "united_states.png"
    "Australia2.png" = "australia.png"
    "Austria2.png" = "austria.png"
    "Bangladesh2.png" = "bangladesh.png"
    "Belgium2.png" = "belgium.png"
    "brazil2.png" = "brazil.png"
    "Cambodia2.png" = "cambodia.png"
    "Canada2.png" = "canada.png"
    "Chile2.png" = "chile.png"
    "China2.png" = "china.png"
    "Colombia2.png" = "colombia.png"
    "Ecuador2.png" = "ecuador.png"
    "england2.png" = "united_kingdom.png"
    "Finland2.png" = "finland.png"
    "france2.png" = "france.png"
    "germany2.png" = "germany.png"
    "Indonesia2.png" = "indonesia.png"
    "Iran2.png" = "iran.png"
    "Iraq2.png" = "iraq.png"
    "Israel2.png" = "israel.png"
    "Italy2.png" = "italy.png"
    "Jamaica2.png" = "jamaica.png"
    "Japan2.png" = "japan.png"
    "korea2.png" = "south_korea.png"
    "Lebanon2.png" = "lebanon.png"
    "Malaysia2.png" = "malaysia.png"
    "Mexico2.png" = "mexico.png"
    "Mongolia2.png" = "mongolia.png"
    "Myanmar2.png" = "myanmar.png"
    "Nepal2.png" = "nepal.png"
    "netherlands2.png" = "netherlands.png"
    "Nigeria2.png" = "nigeria.png"
    "norway2.png" = "norway.png"
    "Pakistan2.png" = "pakistan.png"
    "Peru2.png" = "peru.png"
    "Philippines2.png" = "philippines.png"
    "Poland2.png" = "poland.png"
    "Portugal2.png" = "portugal.png"
    "Romania2.png" = "romania.png"
    "Russia2.png" = "russia.png"
    "Rwanda2.png" = "rwanda.png"
    "SaudiArabia2.png" = "saudi_arabia.png"
    "Senegal2.png" = "senegal.png"
    "singapore2.png" = "singapore.png"
    "SouthAfrica2.png" = "south_africa.png"
    "spain2.png" = "spain.png"
    "Switzerland2.png" = "switzerland.png"
    "Syria2.png" = "syria.png"
    "Taiwan2.png" = "taiwan.png"
    "Thailand2.png" = "thailand.png"
    "Turkey2.png" = "turkey.png"
    "Ukraine2.png" = "ukraine.png"
    "Uruguay2.png" = "uruguay.png"
    "Venezuela2.png" = "venezuela.png"
    "Vietnam2.png" = "vietnam.png"
}

# 소스 및 대상 디렉토리 설정
$sourceDir = "assets/images/flags"
$tempDir = "assets/images/flags_new"

# 임시 디렉토리 생성
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force
}

# 파일 복사 및 이름 변경
foreach ($oldName in $flagMappings.Keys) {
    $oldPath = Join-Path $sourceDir $oldName
    $newName = $flagMappings[$oldName]
    $newPath = Join-Path $tempDir $newName
    
    if (Test-Path $oldPath) {
        Copy-Item -Path $oldPath -Destination $newPath -Force
        Write-Host "복사됨: $oldName -> $newName"
    } else {
        Write-Host "파일을 찾을 수 없음: $oldPath" -ForegroundColor Yellow
    }
}

Write-Host "작업 완료. 새 파일은 $tempDir 에 있습니다." -ForegroundColor Green 