pragma solidity 0.4.24;

import "./chainlink/ChainlinkClient.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract GameBet is ChainlinkClient, Ownable {
    uint256 constant private ORACLE_PAYMENT = 1 * LINK;
    string public apiEndpoint = "https://apiv2.apifootball.com/";
    string public matchId;
    string public homeTeam;
    string public awayTeam;

    bool public matchScheduled = false;
    bool public matchStarted = false;
    bool public matchFinished = false;

    string public score;

    event CheckMatchScheduled (
        bytes32 indexed _requestId,
        bool scheduled
    );

    event MatchStarted(
        bytes32 indexed _requestId,
        bool _started
    );

    constructor(string _matchId, string _homeTeam, string _awayTeam){
        matchId = _matchId;
        homeTeam = _homeTeam;
        awayTeam = _awayTeam;
        setPublicChainlinkToken();
    }

    /**
     * @dev call after contract is funded with LINK.
     */
    function initCheckMatchScheduled(address _oracle, string _jobId) public {
        require(!matchScheduled, "Match already scheduled.");
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(_jobId), this, this.callbackMatchScheduled.selector);
        req.add("match_id", matchId); // required by getMatch
        req.add("copyPath", "1.match_status");
        sendChainlinkRequestTo(_oracle, req, ORACLE_PAYMENT);
    }

    function callbackMatchScheduled(bytes32 _requestId, bool _scheduled)
        public
        recordChainlinkFulfillment(_requestId)
    {
        matchScheduled = _scheduled;
        emit CheckMatchScheduled(_requestId, _scheduled);
    }

    /**
     * @dev triggered after the game kick off.
     */
    function informMatchStarted(address _oracle, string _jobId) public {
        require(!matchStarted, "Match already scheduled.");
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(_jobId), this, this.callbackMatchStarted.selector);
        req.add("match_id", matchId); // required by getMatch
        req.add("copyPath", "1.match_status");
        sendChainlinkRequestTo(_oracle, req, ORACLE_PAYMENT);
    }

    function callbackMatchStarted(bytes32 _requestId, bool _started)
        public
        recordChainlinkFulfillment(_requestId)
    {
        matchStarted = _started;
        emit MatchStarted(_requestId, _started);
    }

    /**
     * @dev bet with Ether
     * @param _betType 0: homeTeam, 1: awayTeam, 2: draw
     */
    function bet(uint256 _betType) public payable {
        require(matchScheduled, "Match info not confirmed yet.");
        require(!matchStarted, "Game has already started");
    }

    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
        result := mload(add(source, 32))
        }
    }
}