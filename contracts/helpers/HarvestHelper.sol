// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IOwnable {
  function policy() external view returns (address);
  function renounceManagement() external;
  function pushManagement( address newOwner_ ) external;
  function pullManagement() external;
}

contract Ownable is IOwnable {

    address internal _owner;
    address internal _newOwner;

    event OwnershipPushed(address indexed previousOwner, address indexed newOwner);
    event OwnershipPulled(address indexed previousOwner, address indexed newOwner);

    constructor () {
        _owner = msg.sender;
        emit OwnershipPushed( address(0), _owner );
    }

    function policy() public view override returns (address) {
        return _owner;
    }

    modifier onlyPolicy() {
        require( _owner == msg.sender, "Ownable: caller is not the owner" );
        _;
    }

    function renounceManagement() public virtual override onlyPolicy() {
        emit OwnershipPushed( _owner, address(0) );
        _owner = address(0);
    }

    function pushManagement( address newOwner_ ) public virtual override onlyPolicy() {
        require( newOwner_ != address(0), "Ownable: new owner is the zero address");
        emit OwnershipPushed( _owner, newOwner_ );
        _newOwner = newOwner_;
    }
    
    function pullManagement() public virtual override {
        require( msg.sender == _newOwner, "Ownable: must be new owner to pull");
        emit OwnershipPulled( _owner, _newOwner );
        _owner = _newOwner;
    }
}

interface ISummoner {
    function deposit( uint pid, uint amount ) external;
    function pendingSoul( uint pid, address user ) external view returns ( uint pendingPayout );
    function enterStaking( uint amount ) external;
    function poolLength() external view returns (uint);
}

contract HarvestHelper is Ownable {

    ISummoner public immutable summoner = ISummoner(0xce6ccbB1EdAD497B4d53d829DF491aF70065AB5B);
    uint public poolLength;

    function updateLength( uint length, bool useDefault ) public onlyPolicy {
        useDefault 
            ? poolLength = summoner.poolLength() - 1 : poolLength = length;
    }

    function harvestAll( bool stake ) external {
    // starts at 1: skips staking (pid 0)
        for( uint pid = 1; pid < poolLength; pid++ ) {
        // check: does user have a pending balance ?
            if ( summoner.pendingSoul( pid, msg.sender ) > 0 ) {
            // assigns rewardsAmount = pending rewards.
                uint rewardsAmount = summoner.pendingSoul( pid, msg.sender );
            // "deposits" nothing (0 LP) to force a [ harvest ] on pid.
                summoner.deposit( pid, 0 );
                // enters staking: if stake == true.
                    if ( stake == true ) summoner.enterStaking( rewardsAmount );
            }
        }
    }
}
