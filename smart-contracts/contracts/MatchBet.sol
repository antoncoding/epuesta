pragma solidity 0.4.24;

import "./chainlink/ChainlinkClient.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract MatchBasic is ChainlinkClient, Ownable {
    uint256 constant private ORACLE_PAYMENT = 1 * LINK;

    string constant private HOMETEAM_SCORE_JOBID = "";
    string constant private AWAYTEAM_SCORE_JOBID = "";
    string constant private CHECK_SCHEDULED_JOBID = "";
    string constant private CHECK_STARTED_JOBID = "";
    string constant private CHECK_FINISHED_JOBID = "";

    string public matchId;
    string public homeTeam;
    string public awayTeam;

    address public oracle;

    bool public matchScheduled = false;
    bool public matchStarted = false;
    bool public matchFinished = false;
    bool public matchFinaled = false;

    bool public homeTeamScoreRecorded = false;
    bool public awayTeamScoreRecorded = false;

    uint8 finalResult;
    uint8 homeTeamScore;
    uint8 awayTeamScore;

    uint256 public ownerTips = 0;
    uint256 public totalPool = 0;
    uint256 public sharePerBet = 0;

    mapping(address => uint256[3]) betRecord;
    mapping(uint8 => uint256) typePool;

    event CheckMatchScheduled (
        bytes32 indexed _requestId,
        bool scheduled
    );

    event MatchStarted(
        bytes32 indexed _requestId,
        bool _started
    );

    event MatchFinaled(
        uint8 _homeTeamScore,
        uint8 _awayTeamScore,
        uint8 _type
    );

    constructor(string _matchId, string _homeTeam, string _awayTeam, address _oracle) public {
        matchId = _matchId;
        homeTeam = _homeTeam;
        awayTeam = _awayTeam;
        oracle = _oracle;
        setPublicChainlinkToken();
    }

    /**
     * @dev call after contract is funded with LINK.
     */
    function initCheckMatchScheduled() public {
        require(!matchScheduled, "Match already scheduled.");
        requestFootballOracle(CHECK_SCHEDULED_JOBID, this.callbackMatchScheduled.selector);
    }

    function callbackMatchScheduled(bytes32 _requestId, bool _scheduled) public recordChainlinkFulfillment(_requestId) {
        matchScheduled = _scheduled;
        emit CheckMatchScheduled(_requestId, _scheduled);
    }

    /**
     * @dev triggered after the game kick off.
     */
    function informMatchStarted() public {
        require(!matchStarted, "Match already scheduled.");
        requestFootballOracle(CHECK_STARTED_JOBID, this.callbackMatchStarted.selector);
    }

    function callbackMatchStarted(bytes32 _requestId, bool _started) public recordChainlinkFulfillment(_requestId) {
        matchStarted = _started;
        emit MatchStarted(_requestId, _started);
    }

    function informMatchFinished() public {
        require(!matchStarted, "Match Not started.");
        requestFootballOracle(CHECK_FINISHED_JOBID, this.callbackMatchFinished.selector);
    }

    function callbackMatchFinished(bytes32 _requestId, bool _started) public recordChainlinkFulfillment(_requestId) {
        matchStarted = _started;
        emit MatchStarted(_requestId, _started);
    }

    function requestHometeamScore() public {
        require(matchFinished && !homeTeamScoreRecorded, "Home team score already updated.");
        requestFootballOracle(HOMETEAM_SCORE_JOBID, this.callbackHometeamScore.selector);
    }

    function requestAwayteamScore() public {
        require(matchFinished && !awayTeamScoreRecorded, "Away team score already updated.");
        requestFootballOracle(AWAYTEAM_SCORE_JOBID, this.callbackAwayteamScore.selector);
    }

    function callbackHometeamScore(bytes32 _requestId, uint8 _score) public recordChainlinkFulfillment(_requestId) {
        homeTeamScore = _score;
        homeTeamScoreRecorded = true;
    }

    function callbackAwayteamScore(bytes32 _requestId, uint8 _score) public recordChainlinkFulfillment(_requestId) {
        awayTeamScore = _score;
        awayTeamScoreRecorded = true;
    }

    function matchResultFinal() public {
        require(!matchFinaled, "Match Finaled");
        require(homeTeamScoreRecorded && awayTeamScoreRecorded, "Team Scores not confirmed.");
        if (homeTeamScore > awayTeamScore)
            finalResult = 0;
        else if (homeTeamScore < awayTeamScore)
            finalResult = 1;
        else
            finalResult = 2;

        sharePerBet = totalPool.div(typePool[finalResult]);
        emit MatchFinaled(homeTeamScore, awayTeamScore, finalResult);
    }

    /**
     * @dev bet with Ether
     * @param _betType 0: homeTeam, 1: awayTeam, 2: draw
     */
    function bet(uint8 _betType) public payable {
        require(matchScheduled, "Match info not confirmed yet.");
        require(!matchStarted, "Game has already started");
        require(_betType < 3, "Invalid betType");
        totalPool.add(msg.value);
        typePool[_betType].add(msg.value);
        betRecord[msg.sender][_betType].add(msg.value);
    }

    function withdrawPrize() public {
        require(matchFinaled, "Match result not confirmed.");
        require(betRecord[msg.sender][finalResult] > 0, "Nothing to withdraw.");
        uint256 amount = betRecord[msg.sender][finalResult].mul(sharePerBet);
        betRecord[msg.sender][finalResult] = 0;
        msg.sender.transfer(amount);
    }

    function requestFootballOracle (string _jobId, bytes4 _callbackFunctionSignature) internal {
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(_jobId), this, _callbackFunctionSignature);
        req.add("match_id", matchId);
        sendChainlinkRequestTo(oracle, req, ORACLE_PAYMENT);
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