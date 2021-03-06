#requires -version 2.0
function Add-RotateFlipFilter {    
    <#
    .Synopsis
    Creates a filter for rotating images.

    .Description
    The Add-RotateFlipFilter function adds a RotateFlip filter to an image filter collection.
    It creates a new filter collection if none exists. 

    An image filter is Windows Image Acquisition (WIA) concept. 
    Each filter represents a change to an image. 

    Add-RotateFlipFilter does not rotate or flip images; it only creates a filter. 
    To rotate or flip images, use the FlipVertical, FlipHorizontal, RotateClockwise and 
    RotateCounterClockwise methods of the Get-Image function, or use the Set-ImageFilter function, 
    which applies the filters.

    Unlike other filter functions in the PSImageTools module, Add-RotateFlipFilter does not have an image parameter.
    RotateFlip filters are not specific to an image.

    All parameters of this function are optional. 
    If you use Add-RotateFlipFilter without parameters, it creates a RotateFlip filter that does not rotate or flip the image.

    .Parameter Filter
    Enter a filter collection (a Wia.ImageProcess COM object).
    You can also pipe a filter collection to Add-OverlayFilter.
    Each filter in the collection represents one change to an image. This parameter is optional.
    If you do not submit a filter collection, Add-OverlayFilter creates one for you.

    .Parameter Angle
    Specifies the angle of rotation. Valid values are 0, 90, 180, 270, and 360. The default value is 0.

    .Parameter FlipHorizontal
    Flips the images horizontally.

    .Parameter FlipVertical
    Flips the images vertically.

    .Parameter Passthru
    Returns an object that represents the filter. By default, this function does not generate output.

    .Notes
    Add-RotateFlipFilter uses the Wia.ImageProcess object.

    .Example
    Add-RotateFlipFilter –angle 90 –passthru

    .Example
    $rf= Add-RotateFlipFilter -FlipVertical –passthru

    .Example
    C:\PS> $rf = Add-RotateFlipFilter –FlipHorizontal –passthru
    C:\PS> ($rf.filters | select properties).properties | format-table –property Name, value -auto

    Name           Value Type
    ----           ----- ----
    RotationAngle      0    5
    FlipHorizontal  True    1
    FlipVertical   False    1
    FrameIndex         0    5

    .Example
    $image = Get-Image .\Photo01.jpg            
    $NewImage = $image | Set-ImageFilter -filter (Add-RotateFlipFilter -flipHorizontal -passThru) -passThru                    
    $NewImage.SaveFile(".\Photo01-edited.jpg")

    .Link
    Set-ImageFilter

    .Link
    Image Manipulation in PowerShell:
    http://blogs.msdn.com/powershell/archive/2009/03/31/image-manipulation-in-powershell.aspx

    .Link
    "ImageProcess object" in MSDN
    http://msdn.microsoft.com/en-us/library/ms630507(VS.85).aspx

    .Link
    "Filter Object" in MSDN 
    http://msdn.microsoft.com/en-us/library/ms630501(VS.85).aspx

    .Link
    "How to Use Filters" in MSDN
    http://msdn.microsoft.com/en-us/library/ms630819(VS.85).aspx


    #>
    param(
    [Parameter(ValueFromPipeline=$true)]
    [__ComObject]
    $filter,
               
    [ValidateSet(0, 90, 180, 270, 360)]
    [int]$angle,
    [switch]$flipHorizontal,
    [switch]$flipVertical,
    
    [switch]$passThru                      
    )
    
    process {
        if (-not $filter) {
            $filter = New-Object -ComObject Wia.ImageProcess
        } 
        $index = $filter.Filters.Count + 1
        if (-not $filter.Apply) { return }
        $scale = $filter.FilterInfos.Item("RotateFlip").FilterId
        $isPercent = $true
        if ($width -gt 1) { $isPercent = $false }
        if ($height -gt 1) { $isPercent = $false } 
        $filter.Filters.Add($scale)
        $filter.Filters.Item($index).Properties.Item("FlipHorizontal") = "$FlipHorizontal"       
        $filter.Filters.Item($index).Properties.Item("FlipVertical") = "$FlipVertical"
        $filter.Filters.Item($index).Properties.Item("RotationAngle") = $Angle
        if ($passthru) { return $filter }         
    }
}

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU4aP6OLf6LcZ88iFCQMTqYjIY
# hBOgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFFGHQkw5LgmIV8QL
# MEH6Xk6AJ3veMA0GCSqGSIb3DQEBAQUABIIBAHsqSSlAJjD/Py4aMXGLvTJHNRLs
# 4EtGS2wlngaYp1fEnXpbwa+5VEyw4+JK28DyiUNYVQ4UQxZEGcBuG50MOMPjIQ++
# X2wywx1wm2zuTt7mK3oS/YnujbXDvRCn1cjKuX5Y33FKQiLqoiZL+OxvE1e7068e
# 7C8bCus9Bd9apSvhu8R61v9n1hg1o1M2MsAu4T0Cl50jBKJNLw5NhFptZUY74TgP
# 6Rm0MKmnqpyz8WggnbLQUV8PCjdokbrrZrcRTbEAIaI7mBd7W7IfaoxhsdhBFCDI
# peefK1CfbylGkYiRsdD0wWMIKKnx/893ae8Ngshn91gy1C9AAFSYG3cSsnQ=
# SIG # End signature block
