## What is the Safe Harbor Initiative?

The Safe Harbor initiative is a legal framework for protocols to allow the rescue of funds being actively exploited. Essentially, this framework aims to give legal protection and financial incentives to well-intentioned whitehats who are capable of rescuing funds that are being stolen.


## Who created the Safe Harbor Initiative?

The Safe Harbor initiative was created by the Security Alliance - a team of professionals spearheading public good projects that bolster the security of the Web3 community. See [securityalliance.org](https://securityalliance.org/) for more info.


## What are the components?

The main legal document is the [“Whitehat Safe Harbor Agreement”](../documents/agreement.pdf). This legal document contains the following exhibits:

- **Certain Defined Terms (Exhibit A):** defines relevant terminology
- **DAO Adoption Procedure (Exhibit B):** describes how a protocol should initiate adoption
- **Security Team Adoption Procedures (Exhibit C):** for acknowledgment by dev/security team
- **User Adoption Procedures (Exhibit D):** user acknowledgment added to front-end ToS
- **Whitehat Risk Disclosures (Exhibit E):** lists the risks associated with funds rescue
- **Adoption Form (Exhibit F):** completed during the adoption procedure
- **Summary (Exhibit G)**
- **Protocol FAQ (Exhibit H)**

A helper document called the [Whitehat Safe Harbor Agreement - Summary”](../documents/summary.pdf) also exists to summarize the main ideas.

The on-chain components of the Safe Harbor initiative exist within the [registry-contracts/](../registry-contracts/) directory in the safe-harbor GitHub repo.


## How does this differ from a bug bounty program?

In bug bounty programs, whitehats identify and report security vulnerabilities that are not yet publicly known. This allows for a more controlled response, as the information is initially shared with a limited audience, reducing immediate risk.

With the Safe Harbor Initiative, whitehat intervention is permitted only after an exploit has been attempted by a separate malicious actor. This scenario requires a more immediate and urgent response. The Safe Harbor agreement preemptively grants whitehats the authorization to act in these circumstances, ensuring that they can address immediate threats without the delay of communicating with the protocol.


## What are the requirements for a whitehat to participate?

To assist in a rescue, a whitehat must have sufficient experience in blockchain security to perform the rescue competently. While there is no formal standard, they should have some background experience in software engineering, security, and/or blockchain auditing.  They must also be free from OFAC sanctions and not involved in legal issues related to any other blockchain exploits.


## Can a protocol impose KYC requirements on rescue payouts?

Yes, protocols have the option to implement KYC requirements in their agreement. For a list of choices a protocol can make during adoption, refer to **Exhibit F (Adoption Form)**.