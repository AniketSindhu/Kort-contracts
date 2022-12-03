// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./KortToken.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Kort is ReentrancyGuard, ERC721URIStorage {
    address public owner; // one who created the contract
    uint256 public chargeFee;
    uint256 public stakeFee;
    uint256 public totalStaked = 0;
    using Counters for Counters.Counter;
    Counters.Counter private caseID;
    KortToken public kortToken;

    uint256 constant DECIMALS = 8;

    constructor(
        uint256 _fee,
        uint256 _stakeFee,
        KortToken _token
    ) ERC721("KORT", "KRT") {
        owner = msg.sender;
        chargeFee = _fee;
        stakeFee = _stakeFee;
        kortToken = _token;
    }

    modifier OwnerOnly
    {
        require(  msg.sender == owner);
        _;
    }

    enum Status {
        WAITING_FOR_APPROVAL,
        APPROVED,
        FINALISED
    }

    event CaseFile(
        address indexed _from,
        address indexed _against,
        uint256 _caseID
    );

    // struct of a case
    struct Case {
        uint256 caseID;
        address from;
        address against;
        string[] options;
        Status status;
        address[] voters;
        int256 final_decision;
        uint256 finalisedAt;
    }
    struct Votes {
        address voter;
        uint256 option;
        uint256 votingPowerAllocated;
    }

    

    mapping(uint256 => Case) public cases;
    mapping(address => bool) public voters;
    mapping(address => uint) public stakeHolders;
    mapping(uint256 => Votes[]) public votemap;

    // start case
    function proposeCase(address _against, string[] memory options)
        public
        nonReentrant
    {
        require(
            _against != msg.sender,
            "You cannot file a case against yourself"
        );
        //todo take user case fee
        kortToken.transfer(owner, chargeFee * (10**DECIMALS), msg.sender);
        caseID.increment();

        cases[caseID.current()] = Case(
            caseID.current(),
            msg.sender,
            _against,
            options,
            Status.WAITING_FOR_APPROVAL,
            new address[](0),
            -1,
            0
        );
    }

    // function file a case
    function approveCase(uint256 caseId, string memory _tokenURI)
        public
        nonReentrant
    {
        //check if case exists
        require(cases[caseId].caseID != 0, "Case does not exist");
        //check if case is already approved
        require(
            cases[caseId].status == Status.WAITING_FOR_APPROVAL,
            "Case already approved"
        );
        //todo take fee from user
        kortToken.transfer(owner, chargeFee * (10**DECIMALS), msg.sender);

        cases[caseId].status = Status.APPROVED;
        cases[caseId].finalisedAt = block.timestamp + 7 days;

        //Minting NFT
        _safeMint(msg.sender, caseID.current());
        _setTokenURI(caseID.current(), _tokenURI);

        emit CaseFile(msg.sender, cases[caseId].against, cases[caseId].caseID);
    }

    // function for be a voter
    function stake(uint256 stakeAmt) public {
        require(voters[msg.sender] == false, "already a voter");
        require(stakeAmt >= stakeFee, "staking amt is not enough");
        kortToken.transfer(owner, stakeAmt * (10**DECIMALS), msg.sender);
        totalStaked = totalStaked + stakeAmt;
        stakeHolders[msg.sender] = stakeAmt;
        voters[msg.sender] = true;
    }

    function voting(uint256 _caseId, uint256 option) public {
        require(voters[msg.sender] == true, "you are not a voter");
        Case storage currCase = cases[_caseId];
        require(currCase.status == Status.APPROVED, "case not approved");
        require(currCase.finalisedAt > block.timestamp, "case expired");
        require(
            currCase.options.length > option && option > 0,
            "invalid option"
        );

    Votes memory currVote = Votes(msg.sender, option, getStake(msg.sender));
        votemap[_caseId].push(currVote);
    }

    function endCase(uint _caseId) public OwnerOnly{
       
        require(cases[_caseId].finalisedAt <= block.timestamp,"voting in progress");
        require(cases[_caseId].status == Status.APPROVED,"case not approved");
        int256[] memory votes = new int256[](cases[_caseId].options.length);
        for(uint i=0;i<votemap[_caseId].length;i++){
            votes[votemap[_caseId][i].option ] = votes[votemap[_caseId][i].option] + 1;
        }
        int maxvote = -1;
        for(uint i=0;i<votes.length;i++){
            if(votes[i] > maxvote){
                maxvote = votes[i];
            }
        }

        cases[_caseId].final_decision = 
        


        
    } 


    function getStake(address user) public view returns (uint256) {
        return stakeHolders[user];
    } 




    /*     function getMessageHash(string memory _message, uint256 _nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_message, _nonce));
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function verify(
        address _signer,
        string memory _message,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 messageHash = getMessageHash(_message, _nonce);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))

            s := mload(add(sig, 64))

            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    } */
}
