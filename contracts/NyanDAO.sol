// SPDX-License-Identifier: UNLICENSED
// @title NyanDAO....🗳️_🐈_🍣_🍱
// @author Gatoshi Nyakamoto

pragma solidity 0.8.4;

/// @notice Interface for NYAN token staking.
interface IMeowshi {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract NyanDAO {
    IMeowshi nyan = IMeowshi(0xEb8B45EB9084D05b25B045Ff8fE4d18fb1248B38);
    //uint256 public proposalCount = proposals.length; // counter for proposals
    uint256 public period = 3 days; // voting period in blocks ~ 17280 3 days for 15s/block
    uint256 public lock = 3 days;  // vote lock in blocks ~ 17280 3 days for 15s/block
    uint256 public minimum = 1e18 * 10000; // you need 10000 NYAN to propose
    uint256 public govLock;
    Proposal[] public proposals; // array list of proposal structs
    
    mapping(address => uint256) public balances;
    mapping(address => uint256) public voteLock;

    struct Proposal {
        address proposer;
        address[] targets;
        uint256[] values;
        bytes[] actions;
        uint256 totalForVotes;
        uint256 totalAgainstVotes;
        uint256 start; // block start;
        uint256 end;   // start + period
    }
    
    /// @dev Reentrancy guard.
    uint unlocked = 1;
    modifier guard() {
        require(unlocked == 1, 'Baal::locked');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        govLock = block.timestamp + 14 days;
    }

    function enter(uint256 amount) external {
        uint256 bal = nyan.balanceOf(address(this));
        nyan.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += nyan.balanceOf(address(this)) - bal;
    }

    function leave(uint256 amount) external {
        require(voteLock[msg.sender] < block.timestamp, "still votelocked");
        balances[msg.sender] -= amount;
        nyan.transfer(msg.sender, amount);
    }

    function propose(address[] calldata targets, uint256[] calldata values, bytes[] calldata actions) external {
        require(block.timestamp >= govLock, "No governance for 2 weeks");
        require(balances[msg.sender] > minimum, "<minimum");
        proposals.push(Proposal({
            proposer: msg.sender,
            targets: targets,
            values: values,
            actions: actions,
            totalForVotes: 0,
            totalAgainstVotes: 0,
            start: block.timestamp,
            end: block.timestamp + period
        }));
        voteLock[msg.sender] = block.timestamp + lock;
    }

    function vote(uint256 id, bool approve) external {
        Proposal storage prop = proposals[id];
        require(prop.start < block.timestamp, "<start");
        require(prop.end > block.timestamp, ">end");
        if (approve) {
            prop.totalForVotes += balances[msg.sender];
        } else {
            prop.totalAgainstVotes += balances[msg.sender];
        }
        voteLock[msg.sender] = block.timestamp + lock;
    }

    function execute(uint id) external guard returns (bytes[] memory results) {
        // ... if the proposal is over, has passed, and has passed a 3 day pause 
        Proposal storage prop = proposals[id];
        if ((prop.end + lock) < block.timestamp && prop.totalForVotes > prop.totalAgainstVotes)
            for (uint256 i = 0; i < prop.targets.length; i++) {
                (bool success, bytes memory result) = prop.targets[i].call{value: prop.values[i]}(prop.actions[i]); // execute low-level call(s)
                require(success, "action failed");
                results[i] = result;
            }
    }
    
    /// @dev Fallback ETH deposit.
    receive() external payable {}
}
