﻿function Get-BadMailEnabledFolder {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter()]
        [PSCustomObject]
        $FolderData
    )

    begin {
        $startTime = Get-Date
        $progressCount = 0
        $sw = New-Object System.Diagnostics.Stopwatch
        $sw.Start()
        $progressParams = @{
            Activity = "Validating mail-enabled public folders"
            Id       = 2
            ParentId = 1
        }
    }

    process {
        $nonIpmSubtreeMailEnabled = @($folderData.NonIpmSubtree | Where-Object { $_.MailEnabled })
        $ipmSubtreeMailEnabled = @($folderData.IpmSubtree | Where-Object { $_.MailEnabled })
        $mailDisabledWithProxyGuid = @($folderData.IpmSubtree | Where-Object { -not $_.MailEnabled -and $null -ne $_.MailRecipientGuid -and [Guid]::Empty -ne $_.MailRecipientGuid } | ForEach-Object { $_.Identity.ToString() })


        $mailEnabledFoldersWithNoADObject = @()
        $mailPublicFoldersLinked = New-Object 'System.Collections.Generic.Dictionary[string, object]'
        $progressParams.Activity = "Checking for missing AD objects"
        for ($i = 0; $i -lt $ipmSubtreeMailEnabled.Count; $i++) {
            $progressCount++
            if ($sw.ElapsedMilliseconds -gt 1000) {
                $sw.Restart()
                Write-Progress @progressParams -PercentComplete ($i * 100 / $ipmSubtreeMailEnabled.Count) -Status ("$i of $($ipmSubtreeMailEnabled.Count)")
            }
            $result = $ipmSubtreeMailEnabled[$i] | Get-MailPublicFolder -ErrorAction SilentlyContinue
            if ($null -eq $result) {
                $mailEnabledFoldersWithNoADObject += $ipmSubtreeMailEnabled[$i]
            } else {
                $guidString = $result.Guid.ToString()
                if (-not $mailPublicFoldersLinked.ContainsKey($guidString)) {
                    $mailPublicFoldersLinked.Add($guidString, $result) | Out-Null
                }
            }
        }

        $progressCount = 0
        $progressParams.Activity = "Getting all MailPublicFolder objects"
        $allMailPublicFolders = @(Get-MailPublicFolder -ResultSize Unlimited | ForEach-Object {
                $progressCount++
                if ($sw.ElapsedMilliseconds -gt 1000) {
                    $sw.Restart()
                    Write-Progress @progressParams -Status "$i"
                }
            })


        $progressCount = 0
        $progressParams.Activity = "Checking for orphaned MailPublicFolders"
        $orphanedMailPublicFolders = @($allMailPublicFolders | ForEach-Object {
                $progressCount++
                if ($sw.ElapsedMilliseconds -gt 1000) {
                    $sw.Restart()
                    Write-Progress @progressParams -PercentComplete ($progressCount * 100 / $allMailPublicFolders.Count) -Status ("$i of $($allMailPublicFolders.Count)")
                }

                if (!($mailPublicFoldersLinked.ContainsKey($_.Guid.ToString()))) {
                    $orphanedMailPublicFolders += $_
                }
            })


        $progressParams.Activity = "Building EntryId HashSets"
        Write-Progress @progressParams
        $byEntryId = New-Object 'System.Collections.Generic.Dictionary[string, object]'
        $FolderData.IpmSubtree | ForEach-Object { $byEntryId.Add($_.EntryId.ToString(), $_) }
        $byPartialEntryId = New-Object 'System.Collections.Generic.Dictionary[string, object]'
        $FolderData.IpmSubtree | ForEach-Object { $byPartialEntryId.Add($_.EntryId.ToString().Substring(44), $_) }


        $orphanedMPFsThatPointToAMailDisabledFolder = @()
        $orphanedMPFsThatPointToAMailEnabledFolder = @()
        $orphanedMPFsThatPointToNothing = @()
        $emailAddressMergeCommands = @()
        $progressParams.Activity = "Checking for orphans that point to a valid folder"
        for ($i = 0; $i -lt $orphanedMailPublicFolders.Count; $i++) {
            if ($sw.ElapsedMilliseconds -gt 1000) {
                $sw.Restart()
                Write-Progress @progressParams -PercentComplete ($i * 100 / $orphanedMailPublicFolders.Count) -Status ("$i of $($orphanedMailPublicFolders.Count)")
            }

            $thisMPF = $orphanedMailPublicFolders[$i]
            $pf = $null
            if ($null -ne $thisMPF.ExternalEmailAddress -and $thisMPF.ExternalEmailAddress.ToString().StartsWith("expf")) {
                $partialEntryId = $thisMPF.ExternalEmailAddress.ToString().Substring(5).Replace("-", "")
                $partialEntryId += "0000"
                if ($byPartialEntryId.TryGetValue($partialEntryId, [ref]$pf)) {
                    if ($pf.MailEnabled) {

                        $command = GetCommandToMergeEmailAddresses $pf $thisMPF
                        if ($null -ne $command) {
                            $emailAddressMergeCommands += $command
                        }

                        $orphanedMPFsThatPointToAMailEnabledFolder += $thisMPF
                    } else {
                        $orphanedMPFsThatPointToAMailDisabledFolder += $thisMPF
                    }

                    continue
                }
            }

            if ($null -ne $thisMPF.EntryId -and $byEntryId.TryGetValue($thisMPF.EntryId.ToString(), [ref]$pf)) {
                if ($pf.MailEnabled) {

                    $command = GetCommandToMergeEmailAddresses $pf $thisMPF
                    if ($null -ne $command) {
                        $emailAddressMergeCommands += $command
                    }

                    $orphanedMPFsThatPointToAMailEnabledFolder += $thisMPF
                } else {
                    $orphanedMPFsThatPointToAMailDisabledFolder += $thisMPF
                }
            } else {
                $orphanedMPFsThatPointToNothing += $thisMPF
            }
        }
    }

    end {
        Write-Verbose "$($ipmSubtreeMailEnabled.Count) public folders are mail-enabled."
        Write-Verbose "$($mailPublicFoldersLinked.Keys.Count) folders are mail-enabled and are properly linked to an existing AD object."
        Write-Verbose "$($nonIpmSubtreeMailEnabled.Count) System folders are mail-enabled."
        Write-Verbose "$($mailEnabledFoldersWithNoADObject.Count) folders are mail-enabled with no AD object."
        Write-Verbose "$($orphanedMailPublicFolders.Count) MailPublicFolders are orphaned."
        Write-Verbose "$($orphanedMPFsThatPointToAMailEnabledFolder.Count) of those orphans point to mail-enabled folders that point to some other object."
        Write-Verbose "$($orphanedMPFsThatPointToAMailDisabledFolder.Count) of those orphans point to mail-disabled folders."

        $foldersToMailDisable = @()
        $nonIpmSubtreeMailEnabled | ForEach-Object { $foldersToMailDisable += $_.Identity.ToString() }
        $mailEnabledFoldersWithNoADObject | ForEach-Object { $foldersToMailDisable += $_.Identity }

        [PSCustomObject]@{
            FoldersToMailDisable          = $foldersToMailDisable
            MailPublicFoldersToDelete     = $orphanedMPFsThatPointToNothing | ForEach-Object { $_.DistinguishedName.Replace("/", "\/") }
            MailPublicFolderDuplicates    = $orphanedMPFsThatPointToAMailEnabledFolder | ForEach-Object { $mailPublicFolderDuplicates += $_.DistinguishedName }
            EmailAddressMergeCommands     = $emailAddressMergeCommands
            MailDisabledWithProxyGuid     = $mailDisabledWithProxyGuid
            MailPublicFoldersDisconnected = $orphanedMPFsThatPointToAMailDisabledFolder | ForEach-Object { $mailPublicFoldersDisconnected += $_.DistinguishedName }
        }

        Write-Host "Get-BadMailEnabledFolder duration" ((Get-Date) - $startTime)
    }
}

function GetCommandToMergeEmailAddresses($publicFolder, $orphanedMailPublicFolder) {
    $linkedMailPublicFolder = Get-PublicFolder $publicFolder.Identity | Get-MailPublicFolder
    $emailAddressesOnGoodObject = @($linkedMailPublicFolder.EmailAddresses | Where-Object { $_.ToString().StartsWith("smtp:", "OrdinalIgnoreCase") } | ForEach-Object { $_.ToString().Substring($_.ToString().IndexOf(':') + 1) })
    $emailAddressesOnBadObject = @($orphanedMailPublicFolder.EmailAddresses | Where-Object { $_.ToString().StartsWith("smtp:", "OrdinalIgnoreCase") } | ForEach-Object { $_.ToString().Substring($_.ToString().IndexOf(':') + 1) })
    $emailAddressesToAdd = $emailAddressesOnBadObject | Where-Object { -not $emailAddressesOnGoodObject.Contains($_) }
    $emailAddressesToAdd = $emailAddressesToAdd | ForEach-Object { "`"" + $_ + "`"" }
    if ($emailAddressesToAdd.Count -gt 0) {
        $emailAddressesToAddString = [string]::Join(",", $emailAddressesToAdd)
        $command = "Get-PublicFolder `"$($publicFolder.Identity)`" | Get-MailPublicFolder | Set-MailPublicFolder -EmailAddresses @{add=$emailAddressesToAddString}"
        return $command
    } else {
        return $null
    }
}
