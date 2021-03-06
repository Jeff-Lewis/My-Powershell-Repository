function Use-BookshelfSchematic
{
    <#
    .Synopsis
        Builds a web application according to a schematic
    .Description
        Use-Schematic builds a web application according to a schematic.
        
        Web applications should not be incredibly unique: they should be built according to simple schematics.        
    .Notes
    
        When ConvertTo-ModuleService is run with -UseSchematic, if a directory is found beneath either Pipeworks 
        or the published module's Schematics directory with the name Use-Schematic.ps1 and containing a function 
        Use-Schematic, then that function will be called in order to generate any pages found in the schematic.
        
        The schematic function should accept a hashtable of parameters, which will come from the appropriately named 
        section of the pipeworks manifest
        (for instance, if -UseSchematic Blog was passed, the Blog section of the Pipeworks manifest would be used for the parameters).
        
        It should return a hashtable containing the content of the pages.  Content can either be static HTML or .PSPAGE                
    #>
    [OutputType([Hashtable])]
    param(
    # Any parameters for the schematic
    [Parameter(Mandatory=$true)][Hashtable]$Parameter,
    
    # The pipeworks manifest, which is used to validate common parameters
    [Parameter(Mandatory=$true)][Hashtable]$Manifest,
    
    # The directory the schemtic is being deployed to
    [Parameter(Mandatory=$true)][string]$DeploymentDirectory,
    
    # The directory the schematic is being deployed from
    [Parameter(Mandatory=$true)][string]$InputDirectory  
    )
    
    begin {
        $pages = @{}
    }
    
    process {           
        if (-not $parameter.Books) {
            Write-Error "No books found on bookshelf"
            return
        }
        
        
        
        $needsTableAccess = $parameter.Books | 
            Where-Object { 
                $_.Chapters | 
                    Where-Object { 
                        $_.Pages | 
                            Where-Object { $_.Id }
                    } 
            }
                 
        if ($needsTableAccess) { 
            if (-not $Manifest.Table.Name) {
                Write-Error "No table found in manifest"
                return
            }
            
            if (-not $Manifest.Table.StorageAccountSetting) {
                Write-Error "No storage account name setting found in manifest"
                return
            }
            
            if (-not $manifest.Table.StorageKeySetting) {
                Write-Error "No storage account key setting found in manifest"
                return
            }
            
        }

        $NewPages = @{}                                
        $chapterNumber = 1
        foreach ($bookInfo in @($parameter.Books)) {
            $book = New-Object PSOBject -Property $bookInfo
            $safeBookName = $book.Name.Replace(" ", "_").Replace("&", "_and_").Replace("?", "").Replace(":", "-").Replace(";", "-").Replace("!", "")
            foreach ($chapterInfo in @($book.Chapters)) {
                $chapter = New-Object PSObject -Property $chapterInfo
                
                $PageNumber = 1
                foreach ($pageInfo in @($chapter.Pages)) {
                    $page = New-Object PSOBject -Property $pageInfo                
                    $webPage = 
                        if ($page.Id) {
@"
`$storageAccount  = Get-WebConfigurationSetting -Setting `$pipeworksManifest.Table.StorageAccountSetting 
`$storageKey= Get-WebConfigurationSetting -Setting `$pipeworksManifest.Table.StorageKeySetting 
`$part, `$row  = '$($page.Id)' -split '\:'
`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$chapterNumber = '$chapterNumber'
`$chapterName = @'
$(if ($chapter.Name) { $chapter.Name })
'@.Trim()
`$longPageName = "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber"
`$PageNumber = '$PageNumber'
`$bookName = '$($book.Name)'
`$safeBookName  = '$safeBookName'
`$chapterPageCount = $(@($chapter.pages).Count)
`$pageName = @'
$(if ($page.Title) { $page.Title} else { "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber" })
'@.Trim()
if (-not `$session["StoryPage`$(`$pageName)Content"]) {
    `$session["StoryPage`$(`$pageName)Content"] = 
        Show-WebObject -StorageAccount $storageAccount -StorageKey $storageKey -Table $pipeworksManifest.Table.Name -Part $part -Row $row
} 
"@
                    } elseif ($page.Content) {
                        $htmlContent = if ($page.Content -like "*<*") {
                            $page.Content
                        } else {
                            ConvertFrom-Markdown $page.Content
                        }
@"

`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$pageName = @'
$(if ($page.Title) { $page.Title} else { "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber" })
'@.Trim()
`$longPageName = "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber"
`$chapterNumber = '$chapterNumber'
`$chapterName = @'
$(if ($chapter.Name) { $chapter.Name })
'@.Trim()

`$PageNumber = '$PageNumber'
`$bookName = '$($book.Name)'
`$safeBookName  = '$safeBookName'
`$chapterPageCount = $(@($chapter.pages).Count)
if (-not `$session["StoryPage`$(`$pageName)Content"]) {
    `$session["StoryPage`$(`$pageName)Content"] = @'
$htmlContent 
'@    
}        

"@                            
                    } elseif ($page.File) {
                        $htmlContent = if ($page.File -like "*.htm?") {
                            (Get-Content "$moduleRoot\$($page.File)" -ReadCount 0) -join ([Environment]::NewLine)
                        } elseif ($page.File -like "*.md") {
                            ConvertFrom-Markdown "$((Get-Content "$moduleRoot\$($page.File)" -ReadCount 0) -join ([Environment]::NewLine))"
                        } elseif ($page.File -like "*.walkthru.help.txt") {
                            Write-WalkthruHTML -WalkThru (Get-Walkthru -File "$moduleRoot\$($page.File)") -StepByStep 
                        }
                        
                        
@"

`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$longPageName = "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber"
`$pageName = @'
$(if ($page.Title) { $page.Title} else { "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber" })
'@.Trim()

`$chapterNumber = '$chapterNumber'
`$chapterName = @'
$(if ($chapter.Name) { $chapter.Name })
'@.Trim()

`$PageNumber = '$PageNumber'
`$bookName = '$($book.Name)'
`$safeBookName  = '$safeBookName'
`$chapterPageCount = $(@($chapter.pages).Count)
if (-not `$session["StoryPage`$(`$pageName)Content"]) {
    `$session["StoryPage`$(`$pageName)Content"] = @'
$htmlContent 
'@    
}        

"@                     
                    }
                    
                    $webPage += {
$pageContent = $session["StoryPage$($pageName)Content"]
$browserSpecificStyle =
    if ($Request.UserAgent -clike "*IE*") {
        @{'height'='60%';"margin-top"="-5px"}
    } else {
        @{'min-height'='60%'}
    }  

$coreStyle = @{
}


$bn, $cn, $pn = $LongPageName -split "\|"
$centerWidth  = 100 - ([Double]$lMargin.Replace("%", "") + [Double]$lMargin.Replace("%", ""))

$titleSection = "
<div style='margin-left:auto;margin-right:auto' id='TitleArea'>
<p>
<a href='$SafeBookName.aspx'>$bn</a>
<p/>
<p style='text-indent:5px;font-size:medium'>
<a href='$SafeBookName.$ChapterNumber.aspx'>$cn</a> $(if ($pageName -ne $longPageName) { 
    "| <a href='$SafeBookName.$ChapterNumber.$pageNumber.aspx'>$pageName</a>"
} else {
})
</p>
<p style='font-size:small;text-align:right'>
$pn
</p>
<hr/>
</div>
$pageContent" | New-Region -LayerID Page -Style @{
        'Margin-Left' = $lMargin
        'Margin-Right' = $rMargin
        'Position' = 'absolute'
        'Margin-Top' = '1%'                
        'Width' = "${centerWidth}%"
    }

$lastPageButton = 
    if ($pageNumber -gt 1) {
        Write-Link -Style @{"Font-Size" ="xx-large"} -Url "$safeBookName.$($chapterNumber).$([int]$pageNumber - 1).aspx" -Caption "<span class='ui-icon ui-icon-arrowthickstop-1-w' style='font-size:x-large'>&nbsp;</span>" -Button |
            New-Region -LayerID LastPageButtonContainer -Style @{
                'Margin-Left' = '3px'
                'Top' = '45%'
                'Height' = '130px'
                'Width' = '130px'                                
                'Position' = 'Absolute'
            }
    } else {
        ""
    }

$nextPageButton = 
    if ($pageNumber -lt ($chapterPageCount)) {
        Write-Link -Style @{"Font-Size" ="3em"} -Url "$safeBookName.$($chapterNumber).$([int]$pageNumber + 1).aspx" -Caption "<span class='ui-icon ui-icon-arrowthickstop-1-e' style='font-size:x-large'>&nbsp;</span>" -Button |
            New-Region -LayerID NextPageButtonContainer -Style @{
                'Margin-Left' = '3px'
                'Top' = '45%'
                'Height' = '130px'
                'Width' = '130px'
                'Right' = '0px'
                'Position' = 'Absolute'
            }
    } else {
        ""
    }
                                     
                                     
$pageNumberSection =
    $pageNumber | 
    New-Region -Style @{
        'Right' = '10px'
        'Bottom' = '10px'
        'font-size' = 'medium'
        'position' = 'absolute'
    }
                                         
                        
$titleSection, $lastpageButton, $pageContentSection, $nextPageButton,$pageNumberSection |
    New-WebPage  -Title $pageName
                
                    }
                    $NewPages["$SafeBookName.${ChapterNumber}.${PageNumber}.pspage"] = "<| $webPage |>"
                    $pageNumber++
                
                }            
                
                # Make chapter page
                $chapterPage = @"
`$chapterNumber = '$chapterNumber'
`$safeBookName = '$safeBookName'


`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$longPageName = "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name })"
`$chapterPageCount = $(@($chapter.pages).Count)

"@ + {
    $centerWidth  = 100 - ([Double]$lMargin.Replace("%", "") + [Double]$lMargin.Replace("%", ""))
$bn, $cn = $longPageName -split "\|"
$chapterPageContent = @"
<div style='margin-left:auto;margin-right:auto' id='TitleArea'>
<p>
<a href='$SafeBookName.aspx'>$bn</a>
<p/>
<p style='text-indent:5px;font-size:medium'>
<a href='$SafeBookName.$ChapterNumber.aspx'>$cn</a>
</p>
<hr/>
</div>
"@
$chapterPageContent += "<div style='text-align:center;margin-left:$($centerWidth/4)%;margin-right:$($centerWidth/4)%'>"
$chapterPageContent += @"
    <style>
	#feedback { font-size: 1.4em; }
	#pages .ui-selecting { background: #FECA40; }
	#pages .ui-selected { background: #F39814; color: white; }
	#pages { list-style-type: none; margin: 0; padding: 0; }
	#pages li { margin: 3px; padding: 1px; float: left; width: 50px; height: 50px; font-size: 2em; text-align: center; }
	</style>
	<script>
	`$(function() {
		`$( "#pages" ).selectable({
            selected: function(event, ui) { 
                window.location = ("$SafeBookName.$ChapterNumber." + ui.selected.innerText.replace(' ','') + ".aspx") 
            } 
        });
	});
	</script>
"@
$chapterPageContent += "<ol id='pages'>"
$chapterPageContent += 
    foreach ($n in 1..$ChapterPageCount) {
    "
	<li class=`"ui-state-default`">$n</li>
    "
}
$chapterPageContent += "</ol>"
$chapterPageContent += "</div>"
$chapterPageContent | 
    New-Region -LayerID Page -Style @{
        'Margin-Left' = $lMargin
        'Margin-Right' = $rMargin
        'Position' = 'absolute'
        'Margin-Top' = '1%'
        'font-size' = 'large'        
        'Width' = "${centerWidth}%"
    } |
    New-WebPage -Title $longPageNAme 

}
            
                $newPages["$safeBookName.${ChapterNumber}.pspage"]= "<| $chapterPage |>"
                $chapterNumber++
            }            
            
            
            $bookPage = @"
`$safeBookName = '$safeBookName'

`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$bookName = '$($Book.Name)'
`$longPageName = "$($Book.Name)"
`$chapterCount = $(@($book.Chapters).Count)

"@ + {
    $centerWidth  = 100 - ([Double]$lMargin.Replace("%", "") + [Double]$lMargin.Replace("%", ""))
$bn  = $longPageName
$PageContent = @"
<div style='margin-left:auto;margin-right:auto' id='TitleArea'>
<p>
<a href='$SafeBookName.aspx'>$bn</a>
<p/>
<hr/>
</div>
"@
$PageContent  += "<div style='text-align:center;margin-left:$($centerWidth/4)%;margin-right:$($centerWidth/4)%'>"

$book = $pipeworksManifest.Bookshelf.Books | Where-Object { $_.Name -eq $bookName } 

$chapterNum = 1
$PageContent  += 
    foreach ($chapter in $book.Chapters) {
        $h  = "<br/>"
        $h += Write-Link -Caption $chapter.Name -Url "$SafeBookName.$chapterNum.1.aspx" -Style @{"Width"="100%"} -button    
        $h += "<br/>"
        $h
        $chapteRNum++
    }

$PageContent  += "</div>"
$PageContent  | 
    New-Region -LayerID Page -Style @{
        'Margin-Left' = $lMargin
        'Margin-Right' = $rMargin
        'Position' = 'absolute'
        'Margin-Top' = '1%'
        'font-size' = 'large'        
        'Width' = "${centerWidth}%"
    } |
    New-WebPage -Title $longPageNAme 

}
            # Make book page
            if (-not ($newPages["Default.pspage"])) {
                $newPages["Default.pspage"] = "<| $bookPage |>"
            }
            $NewPages["$SafeBookName.pspage"] = "<| $bookPage |>"
        }                
                
    }
    end {
        $NewPages
    }
} 

 
 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0MrJQuoI83iBBNgcjODePXlU
# la+gggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE0MDcxNzAwMDAwMFoXDTE1MDcy
# MjEyMDAwMFowaTELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAk9OMREwDwYDVQQHEwhI
# YW1pbHRvbjEcMBoGA1UEChMTRGF2aWQgV2F5bmUgSm9obnNvbjEcMBoGA1UEAxMT
# RGF2aWQgV2F5bmUgSm9obnNvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAM3+T+61MoGxUHnoK0b2GgO17e0sW8ugwAH966Z1JIzQvXFa707SZvTJgmra
# ZsCn9fU+i9KhC0nUpA4hAv/b1MCeqGq1O0f3ffiwsxhTG3Z4J8mEl5eSdcRgeb+1
# jaKI3oHkbX+zxqOLSaRSQPn3XygMAfrcD/QI4vsx8o2lTUsPJEy2c0z57e1VzWlq
# KHqo18lVxDq/YF+fKCAJL57zjXSBPPmb/sNj8VgoxXS6EUAC5c3tb+CJfNP2U9vV
# oy5YeUP9bNwq2aXkW0+xZIipbJonZwN+bIsbgCC5eb2aqapBgJrgds8cw8WKiZvy
# Zx2qT7hy9HT+LUOI0l0K0w31dF8CAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrE
# uXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBTnMIKoGnZIswBx8nuJckJGsFDU
# lDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAw
# bjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYB
# BQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEB
# BHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsG
# AQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEy
# QXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG
# 9w0BAQsFAAOCAQEAVlkBmOEKRw2O66aloy9tNoQNIWz3AduGBfnf9gvyRFvSuKm0
# Zq3A6lRej8FPxC5Kbwswxtl2L/pjyrlYzUs+XuYe9Ua9YMIdhbyjUol4Z46jhOrO
# TDl18txaoNpGE9JXo8SLZHibwz97H3+paRm16aygM5R3uQ0xSQ1NFqDJ53YRvOqT
# 60/tF9E8zNx4hOH1lw1CDPu0K3nL2PusLUVzCpwNunQzGoZfVtlnV2x4EgXyZ9G1
# x4odcYZwKpkWPKA4bWAG+Img5+dgGEOqoUHh4jm2IKijm1jz7BRcJUMAwa2Qcbc2
# ttQbSj/7xZXL470VG3WjLWNWkRaRQAkzOajhpTCCBTAwggQYoAMCAQICEAQJGBtf
# 1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAw
# MFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1
# f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+ykn
# x9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4c
# SocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTm
# K/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/B
# ougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0w
# ggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEA
# PuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH2
# 0ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV
# +7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyP
# u6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD
# 2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6S
# kepobEQysmah5xikmmRR7zGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# MTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcg
# Q0ECEALqUCMY8xpTBaBPvax53DkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFExs1HiyyYRxzwaj
# 7Ihr8eWJkDHbMA0GCSqGSIb3DQEBAQUABIIBAIkotn6P93lBaWq97/p3xkih+yY4
# qUN3MW6sIdhPY7y1fR9jXMIxFR19YL3jrY+DBDUiY7mtg0X7ZE06zF1sIKYjYjIL
# QjEUq88pIQZFmUh3fS1p0vaztKSgvnpxwp5veiD1zV7N+Mb+6/bMQnEYu5ewd3Q8
# vW4yoZH+H/ROyahdBTqwm56pWY0P7sXC9hq6l997yr51lAqNlbU9CjcGKQURlOHv
# WNd/vvR1hkhEftArszeBk4PxoM8cUfo/Le36MQAhgYAMAk2cKqmjvyFPXrnoGOUk
# NBhqcsMrVR1I2Qol2go69nZEP17f5z8HF0/9bqs+lIN2XWNjKMKdoP3nv+c=
# SIG # End signature block
