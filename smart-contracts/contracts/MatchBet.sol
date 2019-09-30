pragma solidity 0.4.24;

import "./chainlink/ChainlinkClient.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";


contract MatchBasic is ChainlinkClient, Ownable {
    uint256 constant private ORACLE_PAYMENT = 1 * LINK;
    IERC20 betToken;

    string constant private MATCH_SCORE_JOBID = "eec87c8a809842bbb5aff539f93bbbb9";
    string constant private MATCH_STATUS_JOBID = "2ca3a3c228f94173a0e6bf643d7ee219";

    string public matchId;
    string public homeTeam;
    string public awayTeam;
    address public oracle;

    bool public homeTeamVerified = false;
    bool public awayTeamVerified = false;
    bool public matchStarted = false;
    bool public matchFinished = false;
    bool public matchResultFinalized = false;

    bool public homeTeamScoreRecorded = false;
    bool public awayTeamScoreRecorded = false;

    uint8 public finalResult;
    uint8 public homeTeamScore;
    uint8 public awayTeamScore;

    uint256 public ownerTips = 0;
    uint256 public totalPool = 0;
    uint256 public sharePerBet = 0;

    mapping(address => uint256[3]) public betRecord;
    mapping(uint8 => uint256) public typePool;

    event MatchInfoVerified (
        bytes32 indexed _requestId,
        string field
    );

    event MatchStarted(
        bytes32 indexed _requestId
    );

    event MatchFinished(
        bytes32 indexed _requestId
    );

    event MatchFinaled(
        uint8 _homeTeamScore,
        uint8 _awayTeamScore,
        uint8 _type
    );

    event Bet(
        address indexed _address,
        uint256 _amount
    );

    event Withdraw(
        address indexed _address,
        uint256 _amount
    );

    constructor(string _matchId, string _homeTeam, string _awayTeam, address _oracle, address _betToken) public {
        matchId = _matchId;
        homeTeam = _homeTeam;
        awayTeam = _awayTeam;
        oracle = _oracle;
        setPublicChainlinkToken();
        betToken = IERC20(_betToken);
    }

    /**
     * @dev call after contract is funded with LINK.
     */
    function verifyHomeTeam() public {
        require(!homeTeamVerified, "Home team info already verified with oracle");
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(MATCH_STATUS_JOBID), this, this.callbackVerifyHomeTeam.selector);
        req.add("match_id", matchId);
        req.add("copyPath", "match_hometeam_name");
        req.add("operator", "eq");
        req.add("value", homeTeam);
        sendChainlinkRequestTo(oracle, req, ORACLE_PAYMENT);
    }

    function callbackVerifyHomeTeam(bytes32 _requestId, bool _verified) public recordChainlinkFulfillment(_requestId) {
        homeTeamVerified = _verified;
        emit MatchInfoVerified(_requestId, "Home Team Name");
    }

    /**
     * @dev call after contract is funded with LINK.
     */
    function verifyAwayTeam() public {
        require(!awayTeamVerified, "Away team info already verified with oracle");
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(MATCH_STATUS_JOBID), this, this.callbackVerifyAwayTeam.selector);
        req.add("match_id", matchId);
        req.add("copyPath", "match_awayteam_name");
        req.add("operator", "eq");
        req.add("value", awayTeam);
        sendChainlinkRequestTo(oracle, req, ORACLE_PAYMENT);
    }

    function callbackVerifyAwayTeam(bytes32 _requestId, bool _verified) public recordChainlinkFulfillment(_requestId) {
        awayTeamVerified = _verified;
        emit MatchInfoVerified(_requestId, "Away Team Name");
    }

    /**
     * @dev triggered after the game kick off.
     */
    function verifyMatchStarted() public {
        require(!matchStarted, "Match already started.");
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(MATCH_STATUS_JOBID), this, this.callbackMatchStarted.selector);
        req.add("match_id", matchId);
        req.add("copyPath", "match_live");
        req.add("operator", "eq");
        req.add("value", "1");
        sendChainlinkRequestTo(oracle, req, ORACLE_PAYMENT);
    }

    function callbackMatchStarted(bytes32 _requestId, bool _started) public recordChainlinkFulfillment(_requestId) {
        if (_started) {
            matchStarted = _started;
            emit MatchStarted(_requestId);
        }
    }

    function verifyMatchFinished() public {
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(MATCH_STATUS_JOBID), this, this.callbackMatchFinished.selector);
        req.add("match_id", matchId);
        req.add("copyPath", "match_status");
        req.add("operator", "eq");
        req.add("value", "Finished");
        sendChainlinkRequestTo(oracle, req, ORACLE_PAYMENT);
    }

    function callbackMatchFinished(bytes32 _requestId, bool _finished) public recordChainlinkFulfillment(_requestId) {
        if (_finished) {
            matchFinished = _finished;
            emit MatchFinished(_requestId);
        }
    }

    function requestHometeamScore() public {
        require(matchFinished && !homeTeamScoreRecorded, "Home team score already updated.");
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(MATCH_SCORE_JOBID), this, this.callbackHometeamScore.selector);
        req.add("match_id", matchId);
        req.add("copyPath", "match_hometeam_score");
        sendChainlinkRequestTo(oracle, req, ORACLE_PAYMENT);
    }

    function requestAwayteamScore() public {
        require(matchFinished && !awayTeamScoreRecorded, "Away team score already updated.");
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(MATCH_SCORE_JOBID), this, this.callbackAwayteamScore.selector);
        req.add("match_id", matchId);
        req.add("copyPath", "match_awayteam_score");
        sendChainlinkRequestTo(oracle, req, ORACLE_PAYMENT);
    }

    function callbackHometeamScore(bytes32 _requestId, uint8 _score) public recordChainlinkFulfillment(_requestId) {
        homeTeamScore = _score;
        homeTeamScoreRecorded = true;
    }

    function callbackAwayteamScore(bytes32 _requestId, uint8 _score) public recordChainlinkFulfillment(_requestId) {
        awayTeamScore = _score;
        awayTeamScoreRecorded = true;
    }

    function finalizeMatch() public {
        require(!matchResultFinalized, "Match Finaled");
        require(homeTeamScoreRecorded && awayTeamScoreRecorded, "Team Scores not confirmed.");
        if (homeTeamScore > awayTeamScore)
            finalResult = 0;
        else if (homeTeamScore < awayTeamScore)
            finalResult = 1;
        else
            finalResult = 2;

        matchResultFinalized = true;
        sharePerBet = totalPool.div(typePool[finalResult]);
        emit MatchFinaled(homeTeamScore, awayTeamScore, finalResult);
    }

    /**
     * @dev bet with Ether
     * @param _betType 0: homeTeam, 1: awayTeam, 2: draw
     */
    function bet(uint8 _betType, uint256 _amount) public {
        require(homeTeamVerified && awayTeamVerified, "Match info not confirmed yet.");
        require(!matchStarted, "Game has already started");
        require(_betType < 3, "Invalid betType");
        if (betToken.transferFrom(msg.sender, this, _amount)) {
            totalPool = totalPool.add(_amount);
            typePool[_betType] = typePool[_betType].add(_amount);
            betRecord[msg.sender][_betType] = betRecord[msg.sender][_betType].add(_amount);
            emit Bet(msg.sender, _amount);
        }
    }

    function withdrawPrize() public {
        require(matchResultFinalized, "Match result not confirmed.");
        require(betRecord[msg.sender][finalResult] > 0, "Nothing to withdraw.");
        uint256 _amount = betRecord[msg.sender][finalResult].mul(sharePerBet);
        betRecord[msg.sender][finalResult] = 0;
        if (betToken.transfer(msg.sender, _amount)) {
            emit Withdraw(msg.sender, _amount);
        }
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