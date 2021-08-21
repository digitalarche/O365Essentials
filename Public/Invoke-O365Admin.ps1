﻿function Invoke-O365Admin {
    [cmdletBinding(SupportsShouldProcess)]
    param(
        [uri] $Uri,
        [alias('Authorization')][System.Collections.IDictionary] $Headers,
        [validateset('GET', 'DELETE', 'POST', 'PATCH')][string] $Method = 'GET',
        [string] $ContentType = "application/json; charset=UTF-8",
        [System.Collections.IDictionary] $Body
    )
    if (-not $Headers -and $Script:AuthorizationO365Cache) {
        # This forces a reconnect of session in case it's about to time out. If it's not timeouting a cache value is used
        $Headers = Connect-O365Admin -Headers $Headers
    } else {
        Write-Warning "Invoke-O365Admin - Not connected. Please connect using Connect-O365Admin."
        return
    }
    if (-not $Headers) {
        Write-Warning "Invoke-O365Admin - Authorization error. Skipping."
        return
    }
    $RestSplat = @{
        Headers     = $Headers.Headers
        Method      = $Method
        ContentType = $ContentType
    }
    #$RestSplat.Headers."x-ms-mac-hosting-app" = 'M365AdminPortal'
    #$RestSplat.Headers."x-ms-mac-version" = 'host-mac_2021.8.16.1'
    #$RestSplat.Headers."sec-ch-ua" = '"Chromium";v="92", " Not A;Brand";v="99", "Microsoft Edge";v="92"'
    #$RestSplat.Headers."x-portal-routekey" = 'weu'
    #$RestSplat.Headers."x-ms-mac-appid" = 'feda2aab-4737-4646-a86c-98a7742c70e6'
    #$RestSplat.Headers."x-adminapp-request" = '/Settings/Services/:/Settings/L1/Whiteboard'
    #$RestSplat.Headers."x-ms-mac-target-app" = 'MAC'
    #$RestSplat.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36 Edg/92.0.902.73'
    #$RestSplat.Headers.Cookie = 'MC1=GUID=480c128a5ba04faea7df151a53bdfa9a&HASH=480c&LV=202107&V=4&LU=1627670649689'

    if ($Body) {
        $RestSplat['Body'] = $Body | ConvertTo-Json -Depth 5
    }
    $RestSplat.Uri = $Uri
    try {
        Write-Verbose "Invoke-O365Admin - Querying [$Method] $($RestSplat.Uri)"
        if ($PSCmdlet.ShouldProcess($($RestSplat.Uri), "Querying [$Method]")) {
            #$CookieContainer = [System.Net.CookieContainer]::new()
            #$CookieContainer.MaxCookieSize = 8096
            $OutputQuery = Invoke-RestMethod @RestSplat -Verbose:$false
            if ($Method -in 'GET') {
                if ($null -ne $OutputQuery) {
                    $OutputQuery
                }
                if ($OutputQuery.'@odata.nextLink') {
                    $RestSplat.Uri = $OutputQuery.'@odata.nextLink'
                    $MoreData = Invoke-O365Admin @RestSplat -FullUri
                    if ($MoreData) {
                        $MoreData
                    }
                }
            } elseif ($Method -in 'POST') {
                $OutputQuery
            } else {
                return $true
            }
        }
    } catch {
        $RestError = $_.ErrorDetails.Message
        if ($RestError) {
            try {
                $ErrorMessage = ConvertFrom-Json -InputObject $RestError -ErrorAction Stop
                # Write-Warning -Message "Invoke-Graph - [$($ErrorMessage.error.code)] $($ErrorMessage.error.message), exception: $($_.Exception.Message)"
                Write-Warning -Message "Invoke-O365Admin - Error JSON: $($_.Exception.Message) $($ErrorMessage.error.message)"
            } catch {
                Write-Warning -Message "Invoke-O365Admin - Error: $($RestError.Trim())"
            }
        } else {
            Write-Warning -Message "Invoke-O365Admin - $($_.Exception.Message)"
        }
        if ($_.ErrorDetails.RecommendedAction) {
            Write-Warning -Message "Invoke-O365Admin - Recommended action: $RecommendedAction"
        }
        if ($Method -notin 'GET', 'POST') {
            return $false
        }
    }
}