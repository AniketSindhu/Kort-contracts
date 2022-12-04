// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./KortToken.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";



interface IPUSHCommInterface {
    function sendNotification(address _channel, address _recipient, bytes calldata _identity) external;
}

contract Kort is ReentrancyGuard, ERC721URIStorage {
    address public owner; // one who created the contract
    address public cron; // one who created the contract
    uint256 public chargeFee; // charge pay to raise a case
    uint256 public stakeFee; // min charge pay to be a jury
    uint256 public totalStaked = 0; // total staking of the system
    using Counters for Counters.Counter;
    Counters.Counter private caseID; // counter for cases
    KortToken public kortToken; // instance of Token

    uint256 constant DECIMALS = 8;

    constructor(
        uint256 _fee,
        uint256 _stakeFee,
        KortToken _token
    ) ERC721("KORT", "KRT") {
        owner = address(this);
        cron = msg.sender;
        chargeFee = _fee;
        stakeFee = _stakeFee;
        kortToken = _token;
    }

    modifier OwnerOnly() {
        require(msg.sender == cron, "owner not calling");
        _;
    }

    // Status of case filing enum
    enum Status {
        WAITING_FOR_APPROVAL,
        APPROVED,
        FINALISED
    }

    // caseFile event
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
        string[] options; // basically here user will add possible resolves
        Status status; // status of the case
        address[] voters; // array of voters
        mapping(address => uint256) votings; // who voted
        mapping(address => bool) claims; // claims taken status
        int256 final_decision; // final selected option
        uint256 finalisedAt; // unix time for case end time
        uint256 totalWinningVotes;
    }
    struct Votes {
        address voter;
        uint256 option;
        uint256 votingPowerAllocated;
        string reason;
    }

    mapping(uint256 => Case) public cases; // cases
    mapping(address => bool) public voters; //  is voter
    mapping(address => uint256) public stakeHolders; // how much stake
    mapping(uint256 => Votes[]) public votemap; // caseID ==> array of Votes

    address pushAdd = 0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa;
    address sourceAdd = 0xaDd5e38E9F6a7c616b6673D69866E8F0349fffa3;
    
    function sendNotification(address _toAdd, string memory _message) public {
        IPUSHCommInterface(pushAdd).sendNotification(
        sourceAdd, // from channel - recommended to set channel via dApp and put it's value -> then once contract is deployed, go back and add the contract address as delegate for your channel
        _toAdd, // to recipient, put address(this) in case you want Broadcast or Subset. For Targetted put the address to which you want to send
        bytes(
            string(
                // We are passing identity here: https://docs.epns.io/developers/developer-guides/sending-notifications/advanced/notification-payload-types/identity/payload-identity-implementations
                abi.encodePacked(
                    "0", // this is notification identity: https://docs.epns.io/developers/developer-guides/sending-notifications/advanced/notification-payload-types/identity/payload-identity-implementations
                    "+", // segregator
                    "3", // this is payload type: https://docs.epns.io/developers/developer-guides/sending-notifications/advanced/notification-payload-types/payload (1, 3 or 4) = (Broadcast, targetted or subset)
                    "+", // segregator
                    "", // this is notificaiton title
                    "+", // segregator
                    _message // notification body
                )
            )
        )
    );

    // start case
    function proposeCase(address _against, string[] memory options,)
        public
        nonReentrant
    {
        require(
            _against != msg.sender,
            "You cannot file a case against yourself"
        );
        //todo take user case fee
        kortToken.transferFrom(msg.sender, owner, chargeFee * (10**DECIMALS));
        caseID.increment();
        Case storage currCase = cases[caseID.current()];
        currCase.caseID = caseID.current();
        currCase.from = msg.sender;
        currCase.against = _against;
        currCase.options = options;
        currCase.status = Status.WAITING_FOR_APPROVAL;
        currCase.final_decision = -1;
        currCase.finalisedAt = 0; // 0 because it is not started yet
        currCase.totalWinningVotes = 0; // total volume(value) of votes is 0 initially

        sendNotification(_against,"Case filed against you");

        emit CaseFile(msg.sender, _against, caseID.current());
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
        kortToken.transferFrom(msg.sender, owner, chargeFee * (10**DECIMALS));

        cases[caseId].status = Status.APPROVED;
        cases[caseId].finalisedAt = block.timestamp + 20 minutes; // now finalise time is setted

        //Minting NFT
        _safeMint(msg.sender, caseID.current());
        _setTokenURI(caseID.current(), _tokenURI);
        
        sendNotification(cases[caseId].from,"Case Approved");

        emit CaseFile(msg.sender, cases[caseId].against, cases[caseId].caseID);
    }

    // function for be a voter
    function stake(uint256 stakeAmt) public {
        require(voters[msg.sender] == false, "already a voter");
        require(stakeAmt >= stakeFee *10**DECIMALS, "staking amt is not enough");
        kortToken.transferFrom(msg.sender, owner, stakeAmt);
        totalStaked = totalStaked + stakeAmt;
        stakeHolders[msg.sender] = stakeAmt;
        voters[msg.sender] = true;
    }

    function voting(
        uint256 _caseId,
        uint256 option,
        string memory _reason
    ) public {
        require(voters[msg.sender] == true, "you are not a voter");
        require(cases[_caseId].votings[msg.sender] == 0, "you already voted");
        Case storage currCase = cases[_caseId];
        require(currCase.status == Status.APPROVED, "case not approved");
        require(currCase.finalisedAt > block.timestamp, "case expired");
        require(
            currCase.options.length > option && option >= 0,
            "invalid option"
        );

        currCase.votings[msg.sender] = 1;

        Votes memory currVote = Votes(
            msg.sender,
            option,
            getStake(msg.sender),
            _reason
        );
        votemap[_caseId].push(currVote);
    }

    function endCase(uint256 _caseId) public {
        require(
            cases[_caseId].finalisedAt <= block.timestamp,
            "voting in progress"
        );
        require(cases[_caseId].status == Status.APPROVED, "case not approved");
        int256[] memory votes;
        // one thing  to note options must be start from zero .. 0 ,1,2...
        for(uint256 i = 0; i < cases[_caseId].options.length; i++){
            votes[i] = 0;
        }
        for (uint256 i = 0; i < votemap[_caseId].length; i++) {
            votes[votemap[_caseId][i].option] =
                votes[votemap[_caseId][i].option] +
                int256(votemap[_caseId][i].votingPowerAllocated);
        }
        int256 maxvote = -1;
        int256 maxvoteindex = 0;
        for (uint256 i = 0; i < votes.length; i++) {
            if (votes[i] > maxvote) {
                maxvote = votes[i];
                maxvoteindex = int256(i);
            }
        }

        address[] memory losers;
        uint256 loserCount = 0;
        for (uint256 i = 0; i < votemap[_caseId].length; i++) {
            // like asking 0 option == index of max which is also same as the option number
            if (votemap[_caseId][i].option != uint256(maxvoteindex)) {
                losers[loserCount] = (votemap[_caseId][i].voter);
                loserCount++;
            }
        }

        for (uint256 i = 0; i < losers.length; i++) {
            stakeHolders[losers[i]] -= ((stakeHolders[losers[i]])/ 10);

            kortToken.burnFrom(losers[i], ((stakeHolders[losers[i]]) / 10));
        }

        cases[_caseId].final_decision = maxvoteindex;
        cases[_caseId].status = Status.FINALISED;
        cases[_caseId].totalWinningVotes = uint256(maxvote);

        sendNotification(cases[_caseId].from,"Case Ends");
        sendNotification(cases[_caseId].against,"Case Ends");
    }

    function claimStake(uint256 caseId) public {
        require(cases[caseId].status == Status.FINALISED, "case not finalised");
        require(cases[caseId].final_decision > 0, "case not won");
        require(cases[caseId].votings[msg.sender] != 0, "you not voted");
        require(cases[caseId].claims[msg.sender] == false, "already claimed");
        uint256 claim = (getVotes(caseId, msg.sender).votingPowerAllocated *
            2 *
            chargeFee *
            10**DECIMALS) / cases[caseId].totalWinningVotes;

        kortToken.transfer(msg.sender, claim);
        cases[caseId].claims[msg.sender] = true;
    }

    function getStake(address user) public view returns (uint256) {
        return stakeHolders[user];
    }

    function getVotes(uint256 caseId, address addy)
        public
        view
        returns (Votes memory)
    {
        //check if case finalised
        require(cases[caseId].status == Status.FINALISED);

        Votes memory vote;
        for (uint256 i = 0; i < votemap[caseId].length; i++) {
            if (votemap[caseId][i].voter == addy) {
                vote = votemap[caseId][i];
            }
        }
        return vote;
    }

    function withdrawStake() public {
        require(voters[msg.sender], "you are not a voter");
        kortToken.transfer(owner, stakeHolders[msg.sender]);
        stakeHolders[msg.sender] = 0;
        voters[msg.sender] = false;
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
