
$trPath = "c:\Apache24\htdocs\my-cpan\amberdb\docs\tr\AmberDB_Veritabani_Sistemi.md"
$enPath = "c:\Apache24\htdocs\my-cpan\amberdb\docs\en\AmberDB_User-Guide.en.md"

function Check-Doc($filePath, $lang) {
    Write-Host "=== Checking $lang Document: $filePath ===" -ForegroundColor Cyan
    $content = Get-Content $filePath -Raw -Encoding UTF8
    
    # 1. Check code blocks balance
    $codeBlockCount = [regex]::Matches($content, '```').Count
    if ($codeBlockCount % 2 -ne 0) {
        Write-Host "ERROR: Code blocks are NOT balanced! Count: $codeBlockCount" -ForegroundColor Red
    } else {
        Write-Host "OK: Code blocks are balanced ($codeBlockCount tags)." -ForegroundColor Green
    }
    
    # 2. Extract Level 2 Headers (## N.)
    $h2List = [regex]::Matches($content, '(?m)^##\s+(\d+)\.\s+(.+)$')
    Write-Host "Found $($h2List.Count) Level-2 section headers." -ForegroundColor Green
    
    for ($i = 0; $i -lt $h2List.Count; $i++) {
        $num = [int]$h2List[$i].Groups[1].Value
        $expected = $i + 1
        $title = $h2List[$i].Groups[2].Value
        if ($num -ne $expected) {
            Write-Host "ERROR: Section number mismatch! Expected $expected, got $num - $title" -ForegroundColor Red
        }
    }
    
    # 3. Extract TOC entries
    $tocEntries = [regex]::Matches($content, '(?m)^(\d+)\.\s+\[([^\]]+)\]\(#([^)]+)\)')
    Write-Host "Found $($tocEntries.Count) TOC entries." -ForegroundColor Green
    
    if ($tocEntries.Count -ne $h2List.Count) {
        Write-Host "WARNING: TOC entries count ($($tocEntries.Count)) != H2 count ($($h2List.Count))" -ForegroundColor Yellow
    }
    
    for ($i = 0; $i -lt [Math]::Min($tocEntries.Count, $h2List.Count); $i++) {
        $tocNum = $tocEntries[$i].Groups[1].Value
        $h2Num = $h2List[$i].Groups[1].Value
        if ($tocNum -ne $h2Num) {
            Write-Host "ERROR: TOC item $i ($tocNum) doesn't match H2 ($h2Num)" -ForegroundColor Red
        }
    }
    
    # 4. Check Subheadings (### N.M)
    $h3List = [regex]::Matches($content, '(?m)^###\s+(\d+)\.(\d+)\s+(.+)$')
    Write-Host "Found $($h3List.Count) Level-3 subheadings (N.M format)." -ForegroundColor Green
    
    # Check 4-level headers (#### N.M.P)
    $h4List = [regex]::Matches($content, '(?m)^####\s+(\d+)\.(\d+)\.(\d+)\s+(.+)$')
    Write-Host "Found $($h4List.Count) Level-4 subheadings (N.M.P format)." -ForegroundColor Green
    
    # Check for any rogue headers starting with non-hierarchical numbers e.g. "### 1." or "#### 1."
    $rogueH3 = [regex]::Matches($content, '(?m)^###\s+\d+\.\s+')
    if ($rogueH3.Count -gt 0) {
        Write-Host "WARNING: Found $($rogueH3.Count) rogue '### N.' headers:" -ForegroundColor Yellow
        foreach ($m in $rogueH3) { Write-Host "   $($m.Value)" -ForegroundColor Yellow }
    } else {
        Write-Host "OK: No rogue '### N.' subheadings found." -ForegroundColor Green
    }
    
    $rogueH4 = [regex]::Matches($content, '(?m)^####\s+\d+\.\s+')
    if ($rogueH4.Count -gt 0) {
        Write-Host "WARNING: Found $($rogueH4.Count) rogue '#### N.' headers:" -ForegroundColor Yellow
        foreach ($m in $rogueH4) { Write-Host "   $($m.Value)" -ForegroundColor Yellow }
    } else {
        Write-Host "OK: No rogue '#### N.' subheadings found." -ForegroundColor Green
    }
    
    Write-Host "Done checking $lang.`n"
}

Check-Doc $trPath "Turkish"
Check-Doc $enPath "English"
