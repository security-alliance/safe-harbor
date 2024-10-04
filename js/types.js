export const primaryType = "AgreementDetailsV1";

export const types = {
    EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
        { name: "chainId", type: "uint256" },
        { name: "verifyingContract", type: "address" },
    ],
    AgreementDetailsV1: [
        { name: "protocolName", type: "string" },
        { name: "contactDetails", type: "Contact[]" },
        { name: "chains", type: "Chain[]" },
        { name: "bountyTerms", type: "BountyTerms" },
        { name: "agreementURI", type: "string" }
    ],
    Contact: [
        { name: "name", type: "string" },
        { name: "contact", type: "string" }
    ],
    Chain: [
        { name: "assetRecoveryAddress", type: "address" },
        { name: "accounts", type: "Account[]" },
        { name: "id", type: "uint256" }
    ],
    Account: [
        { name: "accountAddress", type: "address" },
        { name: "childContractScope", type: "uint8" },
        { name: "signature", type: "bytes" }
    ],
    BountyTerms: [
        { name: "bountyPercentage", type: "uint256" },
        { name: "bountyCapUSD", type: "uint256" },
        { name: "retainable", type: "bool" },
        { name: "identity", type: "uint8" },
        { name: "diligenceRequirements", type: "string" }
    ]
};