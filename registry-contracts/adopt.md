# Safe Harbor Agreement Implementation Standard

## Introduction

A protocol finalizes its agreement to the Safe Harbor constitution by sending an on-chain transaction from an address representative of the protocol's decision-making body to the Safe Harbor Registry Contract. This transaction will call the `adoptSafeHarbor()` function with the `details` that the protocol has chosen.

This document aims to standardize the contents of `AgreementDetails`, ensuring consistency and compliance across all agreements. Standardization of these contents will help Whitehats understand the contents of the Agreement more easily in potentially time-sensitive environments, and will help software parse and display multiple agreements in a standardized manner. 

## Scope

This standard recommends an optional format for recording agreement details in the Safe Harbor Registry, based on Exhibit F (Adoption Form) variables. It focuses on recording the following variables on-chain:

 - Assets Under Scope
 - Bounty Percentage
 - Limitations on Whitehats
 - Protocol's Contact Information

## Standard Agreement Format

### AgreementDetails Struct

```solidity
struct AgreementDetails {
    // The name of the protocol adopting the agreement.
    string protocolName;
    // The assets in scope of the agreement.
    string scope;
    // The contact details (required for pre-notifying).
    string contactDetails;
    // The bounty terms (e.g. percentage bounty, cap, if payable immediately).
    string bountyTerms;
    // Address where recovered funds should be sent.
    address assetRecoveryAddress;
    // IPFS hash of the actual agreement document, which confirms all terms.
    string agreementURI;
}
```

## Detail Structures

Agreement details are recorded in either plain text, structured JSON data, or as an address to an on-chain entity in the case of `assetRecoveryAddress`.

### protocolName

The name of the protocol adopting the agreement. This should be the legal name of the protocol where applicable and should be written in plain text.

### scope

This section outlines the assets covered under the agreement, including both static and implicit assets, to ensure comprehensive coverage of all relevant protocol assets.

 - **staticAssets**: Defines specific smart contract addresses owned by the protocol and the chains on which these contracts are deployed.
 - **implicitAssets**: Lists on-chain addresses responsible for deploying smart contracts, indicating whether new contracts deployed by these addresses after the agreement's posting are included.
 - **additionalInfo**: Provides space for detailing assets not covered by the above categories.

```javascript
{
    "staticAssets": [
        {
            "address": "0x1A2b3C4d5E6f7G8h9I0j",
            "chains": [1, 56, 137] // Ethereum, Binance Smart Chain, and Polygon
        }
    ],
    "implicitAssets": [
        {
            "deployer": "0x9H8g7F6e5D4c3B2a1A0b",
            "chains": [1],
            "includeNewContracts": true
        }
    ],
    "additionalInfo": "Includes all governance contracts deployed by 0x9H8g7F6e5D4c3B2a1A0b on Ethereum."
}
```

### contactDetails

Specifies the protocol's contact information for Whitehats to use in the event funds are recovered from an active exploit. This section ensures Whitehats have clear instructions on whom to contact.

 - **primaryContact**: The main point of contact, including a name and email address, for initiating communication post-recovery.
 - **secondaryContacts**: Additional contact points, potentially including other protocol members or a third-party program administrator, to ensure multiple avenues for reporting.
 - **additionalInfo**: Provides space for any extra details about contacting the protocol.

```javascript
{
    "primaryContact": {
        "name": "John Doe, Security Lead",
        "email": "security@protocolxyz.com"
    },
    "secondaryContacts": [
        {
            "name": "Jane Smith, CTO",
            "contact": "jane.smith@protocolxyz.com"
        }
    ],
    "additionalInfo": "For urgent matters, use the protocol's official contact form on our website."
}
```

### bountyTerms

The bounty terms outlined what Whitehats are eligible under the protocol's version of the Safe Harbor agreement, what identification / diligence requirements the Whitehat must perform, and what bounty the Whitehat is eligible for after recovering funds from an active exploit.

 - **identityRequirement**: Identity requirements for the Whitehats eligible under the agreement. [Options – (“Anonymous,” “Pseudonymous,” or “Named”)] 
 - **diligenceRequirements**: Description of what KYC, sanctions, diligence, or other verification will be performed on Whitehats to determine their eligibility to receive the bounty. [Plain Text] 
 - **percentage**: Percentage of the funds recovered by a Whitehat under the Safe Harbor agreement, rewarded as a bounty. [Number 1-100]
 - **cap**: Maximum value rewarded as a bounty to a Whitehat under the Safe Harbor agreement, expressed in US dollars. [Number]
 - **retainable**: Indicates if the Whitehat can retain part of the recovered funds as a bounty. For instance, with a 10% retainable bounty on $1,000,000 recovery, the Whitehat would return $900,000 to the protocol's `assetRecoveryAddress`. [true/false]
 - **additionalInfo**: Provides space for additional bounty terms or conditions.

```javascript
{
    "identityRequirement": "Pseudonymous",
    "diligenceRequirements": "Must pass basic sanctions check and not be from a high-risk jurisdiction.",
    "percentage": 5,
    "cap": 1000000, // $1,000,000 USD
    "retainable": false,
    "additionalInfo": "Bounties are paid out after thorough review of the recovery operation and within 90 days of asset return."
}
```

### assetRecoveryAddress

The on-chain address where recovered funds under the Safe Harbor agreement should be sent to. This address should be a multisig wallet, hardware wallet, threshold signature wallet, DAO treasury, or another form of secure wallet controlled by the protocol.

### agreementURI

The IPFS hash of the actual agreement document confirming all terms. In the event of any conflict or inconsistency between information in the `AgreementDetails` and the text of the Agreement, the text of the Agreement will govern.


## Versioning

### 1.0

Creation of the `Safe Harbor Agreement Implementation Standard` 