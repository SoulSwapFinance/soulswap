// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import './libraries/ERC20.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';

contract SoulPower is ERC20('SoulPower', 'SOUL'), AccessControl {

    address public supreme;     // supreme divine
    bytes32 public anunnaki;   // admin role
    bytes32 public thoth;     // minter role

    bytes32 public constant DOMAIN_TYPEHASH = // EIP-712 typehash for the contract's domain
        keccak256('EIP712Domain(string name,uint chainId,address verifyingContract)');
    bytes32 public constant DELEGATION_TYPEHASH = // EIP-712 typehash for the delegation struct used by the contract
        keccak256('Delegation(address delegatee,uint nonce,uint expiry)'); 

    // mappings for user accounts (address)
    mapping(address => mapping(uint => Checkpoint)) public checkpoints;   // vote checkpoints
    mapping(address => uint) public numCheckpoints;                      // checkpoint count
    mapping(address => uint) public nonces;                             // signing / validating states
    mapping(address => address) internal _delegates;                      // each accounts' delegate

    struct Checkpoint {  // checkpoint for marking number of votes from a given timestamp
        uint fromTime;
        uint votes;
    }

    event NewSupreme(address supreme);
    event Rethroned(bytes32 role, address oldAccount, address newAccount);
    event DelegateChanged( // emitted when an account changes its delegate
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );
    event DelegateVotesChanged( // emitted when a delegate account's vote balance changes
        address indexed delegate,
        uint previousBalance,
        uint newBalance
    );

    // restricted to the house of the role passed as an object to obey
    modifier obey(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    // channels the authority vested in anunnaki and thoth to the supreme
    constructor(address _supreme) {
        supreme = _supreme;
        anunnaki = keccak256('anunnaki'); // alpha supreme
        thoth = keccak256('thoth');      // god of wisdom and magic

        _divinationRitual(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE, supreme); // supreme as root admin
        _divinationRitual(anunnaki, anunnaki, supreme);                    // anunnaki as admin of anunnaki
        _divinationRitual(thoth, anunnaki, supreme);                      // anunnaki as admin of thoth

        mint(supreme, 50000000 * 1e18); // mints initial supply of 50M
    }

    // solidifies roles (internal)
    function _divinationRitual(bytes32 _role, bytes32 _adminRole, address _account) internal {
        _setupRole(_role, _account);
        _setRoleAdmin(_role, _adminRole);
    }

    // grants `role` to `newAccount` && renounces `role` from `oldAccount` (public role)
    function rethroneRitual(bytes32 role, address oldAccount, address newAccount) public obey(role) {
        require(oldAccount != newAccount, 'must be a new address');
        grantRole(role, newAccount);     // grants new account
        renounceRole(role, oldAccount); //  removes old account of role
        
        emit Rethroned(role, oldAccount, newAccount);
    }

    // updates supreme address (public anunnaki)
    function newSupreme(address _supreme) public obey(anunnaki) {
        require(supreme != _supreme, 'make a change, be the change');  //  prevents self-destruct
        rethroneRitual(DEFAULT_ADMIN_ROLE, supreme, _supreme);        //   empowers new supreme
        supreme = _supreme;
        
        emit NewSupreme(supreme);
    }

    // checks whether sender has divine role (public view)
    function hasDivineRole(bytes32 role) public view returns (bool) {
        return hasRole(role, msg.sender);
    }

    // mints soul power as the house of thoth so wills (public thoth)
    function mint(address _to, uint _amount) public obey(thoth) {
        _mint(_to, _amount);
        _moveDelegates(address(0), _delegates[_to], _amount);
    }

    // destroys `amount` tokens from the caller (public)
    function burn(uint amount) public {
        _burn(_msgSender(), amount);
        _moveDelegates(_delegates[_msgSender()], address(0), amount);
    }

    // destroys `amount` tokens from the `account` (public)
    function burnFrom(address account, uint amount) public {
        uint currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, 'burn amount exceeds allowance');

        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
        _moveDelegates(_delegates[account], address(0), amount);
    }

    // returns the address delegated by a given delegator (external view)
    function delegates(address delegator) external view returns (address) {
        return _delegates[delegator];
    }

    // delegates to the `delegatee` (external)
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    // delegates votes from signatory to `delegatee` (external)
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), getChainId(), address(this))
        );

        bytes32 structHash = keccak256(
            abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)
        );

        bytes32 digest = keccak256(
            abi.encodePacked('\x19\x01', domainSeparator, structHash)
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), 'delegateBySig: invalid signature');
        require(nonce == nonces[signatory]++, 'delegateBySig: invalid nonce');
        require(block.timestamp <= expiry, 'delegateBySig: signature expired');
        return _delegate(signatory, delegatee);
    }

    // returns current votes balance for `account` (external view)
    function getCurrentVotes(address account) external view returns (uint) {
        uint nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    // returns an account's prior vote count as of a given timestamp (external view)
    function getPriorVotes(address account, uint blockTimestamp) external view returns (uint) {
        require(blockTimestamp < block.timestamp, 'getPriorVotes: not yet determined');
        
        uint nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) { return 0; }

        // checks most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromTime <= blockTimestamp) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // checks implicit zero balance
        if (checkpoints[account][0].fromTime > blockTimestamp) {
            return 0;
        }

        uint lower = 0;
        uint upper = nCheckpoints - 1;
        while (upper > lower) {
            uint center = upper - (upper - lower) / 2; // avoids overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromTime == blockTimestamp) {
                return cp.votes;
            } else if (cp.fromTime < blockTimestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }

        return checkpoints[account][lower].votes;
    }

    function safe256(uint n, string memory errorMessage) internal pure returns (uint) {
        require(n < type(uint).max, errorMessage);
        return uint(n);
    }

    function getChainId() internal view returns (uint) {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint delegatorBalance = balanceOf(delegator); // balance of underlying SOUL (not scaled)
        _delegates[delegator] = delegatee;
        emit DelegateChanged(delegator, currentDelegate, delegatee);
        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decreases old representative
                uint srcRepNum = numCheckpoints[srcRep];
                uint srcRepOld = srcRepNum > 0
                    ? checkpoints[srcRep][srcRepNum - 1].votes
                    : 0;
                uint srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increases new representative
                uint dstRepNum = numCheckpoints[dstRep];
                uint dstRepOld = dstRepNum > 0
                    ? checkpoints[dstRep][dstRepNum - 1].votes
                    : 0;
                uint dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint nCheckpoints,
        uint oldVotes,
        uint newVotes
    ) internal {
        uint blockTimestamp = safe256(block.timestamp, 'block timestamp exceeds 256 bits');

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromTime == blockTimestamp) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else { 
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockTimestamp, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }
}
