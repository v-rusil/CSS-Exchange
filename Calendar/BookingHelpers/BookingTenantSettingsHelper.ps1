﻿function GetBookingTenantSettings {
    param([string] $domain)

    if ($Script:MSSupport) {
        $script:OrgConfig = Get-OrganizationConfig -Organization $domain
        $script:OWAMBPolicy = Get-OwaMailboxPolicy -Organization $domain
        $script:AcceptedDomains = Get-AcceptedDomain -Organization $domain
    } else {
        $script:OrgConfig = Get-OrganizationConfig
        $script:OWAMBPolicy = Get-OwaMailboxPolicy
        $script:AcceptedDomains = Get-AcceptedDomain
    }
    $ewsSettings = GetEWSSettings $script:OrgConfig
    $bookingsSettings =  $script:OrgConfig
    $OWAMBPolicy =  $script:OWAMBPolicy
    $acceptedDomains = GetAcceptedDomains $script:AcceptedDomains
    # Define the structure of the tenant settings
    $tenantSettings = [PSCustomObject]@{
        Identity         = $org.Identity
        Guid             = $org.Guid
        DisplayName      = $org.DisplayName
        IsDeHydrated     = $org.IsDeHydrated
        EWSSettings      = $ewsSettings
        BookingsSettings = $bookingsSettings
        OWAMBPolicy      = $OWAMBPolicy
        AcceptedDomains  = $acceptedDomains
    }

    # Return the tenant settings
    return $tenantSettings
}

function GetEWSSettings {
    param($org)
    # Define the structure of the EWS settings
    $EwsSettings = [PSCustomObject]@{
        EwsAllowList               =$org.EwsAllowList
        EwsApplicationAccessPolicy =$org.EwsApplicationAccessPolicy
        EwsBlockList               =$org.EwsBlockList
        EwsEnabled                 =$org.EwsEnabled
    }

    # Return the EWS settings
    return $EwsSettings
}

function GetBookingsSettings {
    param($orgConfig)
    # Define the structure of the Bookings settings
    $BookingsSettings = [PSCustomObject]@{
        BookingsEnabled                             =$orgConfig.BookingsEnabled
        BookingsEnabledLastUpdateTime               =$orgConfig.BookingsEnabledLastUpdateTime
        BookingsPaymentsEnabled                     =$orgConfig.BookingsPaymentsEnabled
        BookingsSocialSharingRestricted             =$orgConfig.BookingsSocialSharingRestricted
        BookingsAddressEntryRestricted              =$orgConfig.BookingsAddressEntryRestricted
        BookingsAuthEnabled                         =$orgConfig.BookingsAuthEnabled
        BookingsCreationOfCustomQuestionsRestricted =$orgConfig.BookingsCreationOfCustomQuestionsRestricted
        BookingsExposureOfStaffDetailsRestricted    =$orgConfig.BookingsExposureOfStaffDetailsRestricted
        BookingsNotesEntryRestricted                =$orgConfig.BookingsNotesEntryRestricted
        BookingsPhoneNumberEntryRestricted          =$orgConfig.BookingsPhoneNumberEntryRestricted
        BookingsMembershipApprovalRequired          =$orgConfig.BookingsMembershipApprovalRequired
        BookingsSmsMicrosoftEnabled                 =$orgConfig.BookingsSmsMicrosoftEnabled
        BookingsNamingPolicyEnabled                 =$orgConfig.BookingsNamingPolicyEnabled
        BookingsBlockedWordsEnabled                 =$orgConfig.BookingsBlockedWordsEnabled
        BookingsNamingPolicyPrefixEnabled           =$orgConfig.BookingsNamingPolicyPrefixEnabled
        BookingsNamingPolicyPrefix                  =$orgConfig.BookingsNamingPolicyPrefix
        BookingsNamingPolicySuffixEnabled           =$orgConfig.BookingsNamingPolicySuffixEnabled
        BookingsNamingPolicySuffix                  =$orgConfig.BookingsNamingPolicySuffix
        BookingsSearchEngineIndexDisabled           =$orgConfig.BookingsSearchEngineIndexDisabled
        IsTenantInGracePeriod                       =$orgConfig.IsTenantInGracePeriod
        IsTenantAccessBlocked                       =$orgConfig.IsTenantAccessBlocked
        IsDehydrated                                =$orgConfig.IsDehydrated
        ServicePlan                                 =$orgConfig.ServicePlan #check doc for serviceplans accepting Bookings4
    }

    # Return the Bookings settings
    return $BookingsSettings
}

function GetOWAMBPolicy {
    param($policy)
    # Define the structure of the OWA mailbox policy
    $OWAMBPolicy = [PSCustomObject]@{
        BookingsMailboxCreationEnabled = $policy.BookingsMailboxCreationEnabled
        BookingsMailboxDomain          = $policy.BookingsMailboxDomain
    }

    # Return the OWA mailbox policy
    return $OWAMBPolicy
}


function GetAcceptedDomains {
    param($domains)


    # Define the structure of the accepted domains
    $acceptedDomains = [PSCustomObject]@{
        DomainName         = $domains.DomainName
        Default            = $domains.Default
        AuthenticationType = $domains.AuthenticationType
    }

    # Return the accepted domains
    return $acceptedDomains
}