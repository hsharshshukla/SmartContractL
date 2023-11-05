// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract Lottery is VRFConsumerBaseV2, Ownable {
    address payable[] public players;
    uint256 public usdEntryFee;
    address payable public recentWinner;
    uint256 public randomness;
    AggregatorV3Interface internal ethUsdPriceFeed;
    VRFCoordinatorV2Interface COORDINATOR;
    // Your subscription ID.
    uint64 s_subscriptionId;

    enum LOTTERY_STATE {
        OPEN, //0
        CLOSED, //1
        CALCULATING_WINNER //2
    }
    LOTTERY_STATE public lottery_state;
    uint256 public fee;
    bytes32 public keyhash;
    event RequestedRandomness(bytes32 requestId);

    // constructor(
    //     address _priceFeed,
    //     address _vrfCoordinator,
    //     address _link,
    //     uint256 _fee,
    //     bytes32 _keyhash
    // ) public VRFConsumerBase(_vrfCoordinator, _link) {
    //     usdEntryFee = 50 * (10 ** 18);
    //     ethUsdPriceFeed = AggregatorV3Interface(_priceFeed);
    //     lottery_state = LOTTERY_STATE.CLOSED;
    //     fee = _fee;
    //     keyhash = _keyhash;
    // }
    constructor(
        address _priceFeed,
        uint64 subscriptionId
    ) VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625) {
        usdEntryFee = 50 * (10 ** 18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeed);
        lottery_state = LOTTERY_STATE.CLOSED;
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        s_subscriptionId = subscriptionId;
    }

    function enter() public payable {
        require(lottery_state == LOTTERY_STATE.OPEN);
        //$50 minimum entry
        require(msg.value >= getEntranceFee(), "Not Enough Eth!");
        players.push(payable(msg.sender)); //0.8 msg.sender is not payable , cast it explicitly
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * (10 ** 10);
        uint256 costToEnter = (usdEntryFee * 10 ** 18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Can't start a new lottery yet"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 2;
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests;
    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;
    event RequestSent(uint256 requestId, uint32 numWords);

    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function endLottery() public onlyOwner {
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        // bytes32 requestId = requestRandomness(keyhash, fee);
        // bytes32 requestId = requestRandomWords(keyhash, s_subscriptionId, fee);
        // emit RequestedRandomness(requestId);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't there yet!"
        );

        //     randomness = _randomness;
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);

        // require(_randomness > 0, "random-not-found");
        // uint256 indexOfWinner = _randomness % players.length;
        // recentWinner = players[indexOfWinner];
        // recentWinner.transfer(address(this).balance);
        // players = new address payable[](0);
        // lottery_state = LOTTERY_STATE.CLOSED;
    }
    // function fulfillRandomness(
    //     bytes32 _requestId,
    //     uint256 _randomness
    // ) internal override {
    //     require(
    //         lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
    //         "You aren't there yet!"
    //     );

    //     require(_randomness > 0, "random-not-found");
    //     uint256 indexOfWinner = _randomness % players.length;
    //     recentWinner = players[indexOfWinner];
    //     recentWinner.transfer(address(this).balance);
    //     players = new address payable[](0);
    //     lottery_state = LOTTERY_STATE.CLOSED;
    //     randomness = _randomness;
    // }
}
