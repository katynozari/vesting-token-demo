# Token Vesting Smart Contracts

A robust and flexible token vesting system built on Ethereum, featuring customizable vesting schedules, airdrop functionality, and secure token distribution mechanisms.

## 🌟 Features

- **Token Vesting**
  - Fixed and flexible vesting schedules
  - Customizable vesting parameters (duration, units, start time)
  - Revocable and non-revocable grants
  - Maximum 10 vesting schedules per address

- **Token Distribution**
  - Fixed amount airdrops
  - Flexible amount airdrops
  - Batch distribution (up to 100 recipients)

- **Security Features**
  - Pausable functionality
  - Reentrancy protection
  - Access control roles
  - Safe token transfers using OpenZeppelin

## 🛠️ Technical Stack

- **Foundry**: Modern, fast Ethereum development framework
- **Solidity**: ^0.8.20
- **OpenZeppelin Contracts**: For secure, standard implementations

## 📥 Installation & Setup

```bash
# Clone the repository
git clone [your-repo-url]

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

## 🧪 Testing

The project includes comprehensive test suites built with Foundry:

```bash
# Run all tests
forge test

# Run tests with verbosity level 2
forge test -vv

# Run tests with gas report
forge test --gas-report
```

### Test Coverage
- Vesting schedule creation and management
- Token distribution mechanisms
- Access control and permissions
- Edge cases and security scenarios

## 📋 Smart Contracts

### VestingToken.sol
- ERC20 token with vesting capabilities
- Total Supply: 10,000,000 tokens
- Implements AccessControl for role-based permissions
- Tracks vesting schedules per address

### VestingTokenManager.sol
- Manages vesting schedule creation and token distribution
- Handles both fixed and flexible vesting parameters
- Implements airdrop functionality
- Emergency pause functionality

## 🛠️ Technical Details

### Prerequisites
- Solidity ^0.8.20
- OpenZeppelin Contracts

### Key Components

#### Vesting Schedule Parameters
- `granter`: Address receiving the vested tokens
- `amount`: Number of tokens to vest
- `start`: Vesting start time
- `duration`: Vesting duration
- `unit`: Number of vesting periods
- `revocable`: Whether the grant can be revoked

## 🔧 Usage

### Deploying Contracts

1. Deploy `VestingToken.sol` first with parameters:
   - `_admin`: Address for admin role
   - `_vestingManager`: Address for vesting manager role

2. Deploy `VestingTokenManager.sol` with parameters:
   - `_initialOwner`: Contract owner address
   - `_vestToken`: Address of deployed VestingToken

### Creating Vesting Schedules

```solidity
// Fixed vesting for multiple addresses
createFixedVestingSchedules(
    addresses[],
    amount,
    startTime,
    duration,
    unit,
    revocable
)

// Flexible vesting for multiple addresses
createFlexibleVestingSchedules(
    VestingParams[]
)
```

### Distributing Airdrops

```solidity
// Fixed amount airdrop
distributeFixedAirdrop(
    recipients[],
    amount
)

// Flexible amount airdrop
distributeFlexibleAirdrop(
    recipients[],
    amounts[]
)
```

## 🔒 Security

- Built with OpenZeppelin's secure contract library
- Implements reentrancy guards
- Role-based access control
- Pausable functionality for emergency situations

## 📜 License

MIT License

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
