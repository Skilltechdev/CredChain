# Decentralized Credential Management Smart Contract

A Clarity smart contract for managing verifiable credentials on the Stacks blockchain. This contract enables authorized institutions to issue, manage, and revoke digital credentials, while allowing recipients to verify their credentials' authenticity and validity.

## Features

- **Issuer Management**
  - Register new credential issuers
  - Suspend existing issuers
  - Track issuer verification status

- **Credential Operations**
  - Issue new credentials
  - Revoke existing credentials
  - Set expiration dates
  - Store credential hashes

- **Verification**
  - Verify credential validity
  - Check credential status
  - Validate expiration dates

## Contract Structure

### Data Maps

1. `verified-issuers`: Stores information about authorized credential issuers
   - Fields:
     - name: Institution name (UTF-8 string, max 100 chars)
     - verification-date: Block height when verified
     - status: "active" or "suspended"

2. `credentials`: Stores issued credentials
   - Fields:
     - recipient: Principal receiving the credential
     - issuer: Principal who issued the credential
     - credential-type: Type of credential (UTF-8 string, max 50 chars)
     - issue-date: Block height when issued
     - expiry-date: Block height when expires
     - credential-hash: 32-byte hash of credential data
     - status: "active" or "revoked"

### Public Functions

#### Administrative Functions

1. `register-issuer`
   - Parameters:
     - institution-principal: Principal address of the institution
     - institution-name: Name of the institution
   - Description: Registers a new authorized credential issuer

2. `suspend-issuer`
   - Parameters:
     - institution-principal: Principal address of the institution
   - Description: Suspends an existing issuer's authorization

#### Credential Management

1. `issue-credential`
   - Parameters:
     - recipient-principal: Principal receiving the credential
     - credential-type: Type of credential
     - valid-for: Duration in blocks
     - credential-hash: Hash of credential data
   - Description: Issues a new credential to a recipient

2. `revoke-credential`
   - Parameters:
     - credential-id: Unique identifier of the credential
   - Description: Revokes an existing credential

#### Read-Only Functions

1. `get-credential`
   - Parameters:
     - credential-id: Unique identifier of the credential
   - Description: Retrieves credential information

2. `verify-credential`
   - Parameters:
     - credential-id: Unique identifier of the credential
   - Description: Checks if a credential is valid and not expired

3. `get-issuer-info`
   - Parameters:
     - issuer-principal: Principal address of the issuer
   - Description: Retrieves issuer information

4. `get-credentials-by-recipient`
   - Parameters:
     - recipient-principal: Principal address of the recipient
   - Description: Retrieves credentials owned by a recipient

## Error Codes

- ERR-NOT-AUTHORIZED (u1): User not authorized for the operation
- ERR-ALREADY-REGISTERED (u2): Issuer already registered
- ERR-INVALID-STATUS (u3): Invalid credential or issuer status
- ERR-EXPIRED (u4): Credential has expired
- ERR-INVALID-INPUT (u5): Invalid input parameters
- ERR-INVALID-LENGTH (u6): String length exceeds maximum

## Security Features

- Input validation for all public functions
- Principal address validation
- String length validation
- Status validation
- Credential hash validation
- Authorization checks for administrative functions
- Expiration date enforcement

## Usage Examples

### Registering an Issuer
```clarity
(contract-call? .credential register-issuer 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  u"University of Blockchain")
```

### Issuing a Credential
```clarity
(contract-call? .credential issue-credential
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  u"Bachelor of Science"
  u52560
  0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef)
```

### Verifying a Credential
```clarity
(contract-call? .credential verify-credential u1)
```

## Development and Testing

To deploy and test this contract:

1. Install the Clarinet development environment
2. Clone the repository
3. Run tests: `clarinet test`
4. Deploy to testnet: `clarinet deploy --testnet`

## Project Structure

credential-management/
├── contracts/
│   ├── credential.clar          # Core contract
│   ├── credential-registry.clar  # Contract for credential type management
│   └── credential-access.clar   # Contract for access control & permissions
├── tests/
│   ├── credential_test.ts       # Core contract tests
│   ├── registry_test.ts         # Registry contract tests
│   └── access_test.ts          # Access control tests
├── scripts/
│   ├── deploy.ts               # Deployment scripts
│   └── setup.ts               # Initial setup scripts
├── frontend/                   # Web interface
│   ├── src/
│   ├── public/
│   └── components/
├── docs/
│   ├── api.md                 # API documentation
│   ├── architecture.md        # System architecture
│   └── schemas.md            # Credential schemas
└── README.md