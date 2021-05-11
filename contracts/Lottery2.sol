pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

import "./LotteryNFT.sol";

// import "@nomiclabs/buidler/console.sol";

contract Lottery2 is Initializable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeERC20 for IERC20;

    struct AirdropInfo {
        address addr;
        uint256 amount;
    }

    address public adminAddress;
    LotteryNFT public lotteryNFT;
    uint256 public failingRandomNumber; // the randomnumber to cal the failing Id
    uint256 public oneTicketAmount; // total sell Amount of skb
    uint256 public failingAmount; // amount of failing tickets
    uint256 public oneTicketPrice; // claim price of one failing ticket
    uint256 public ticketsAmount; // amount of gotten tickets
    // IERC20 public sellToken; // skb
    AirdropInfo[] public selledList; // skb
    IERC20 public buyToken; // usdt
    bool public drawingPhase; // default false
    bool public drawed; // default false

    mapping (address => uint8) public whiteInfoUser;
    mapping (address => uint256[]) public userLotteryList;

    bool public buyClosed;

    event Buy(address indexed user, uint256 tokenId);
    event Drawing(uint256 indexed randomNumber, uint256 failingNumber);
    event Claim(address indexed user, uint256 tokenId);
    event DevWithdraw(address indexed user, uint256 amount);

    constructor() public {}

    function initialize(
        LotteryNFT _lottery,
        // IERC20 _sellToken,
        IERC20 _buyToken,
        uint256 _oneTicketAmount,
        uint256 _failingAmount,
        address _adminAddress
    ) initializer public {
        lotteryNFT = _lottery;
        // sellToken = _sellToken;
        buyToken = _buyToken;
        oneTicketAmount = _oneTicketAmount;
        failingAmount = _failingAmount;
        adminAddress = _adminAddress;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "admin: wut?");
        _;
    }

    function setClaimPrice(uint256 _price) external onlyAdmin {
        oneTicketPrice = _price;
    }

    function closeBuy() external onlyAdmin {
        buyClosed = true;
    }

    function setWhiteList(address[] memory _addresses, uint8[] memory _ticketAmout) external onlyAdmin {
        for (uint i = 0; i < _addresses.length; i++) {
            whiteInfoUser[_addresses[i]] = _ticketAmout[i];
        }
    }

    function enterDrawingPhase() external onlyAdmin {
        require(!drawed, 'drawed');
        drawingPhase = true;
    }
    
    // add externalRandomNumber to prevent node validators exploit
    function drawing(uint256 _externalRandomNumber) external onlyAdmin {
        require(!drawed, "reset?");
        require(drawingPhase, "enter drawing phase first");
        uint256 gapNum = ticketsAmount.div(failingAmount);
        bytes32 _structHash;
        uint256 _randomNumber;
        bytes32 _blockhash = blockhash(block.number-1);

        // random num between 0 ~ gapNum-1
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                ticketsAmount,
                _externalRandomNumber
            )
        );
        _randomNumber  = uint256(_structHash);
        assembly {_randomNumber := mod(_randomNumber, gapNum)}
        failingRandomNumber = _randomNumber;
        drawed = true;
        emit Drawing(_externalRandomNumber, failingRandomNumber);
    }

    function multiClaim(uint8 _amount) external {
        require(!drawed, 'drawed, can not buy now');
        require(!drawingPhase, 'drawing, can not buy now');
        require (whiteInfoUser[msg.sender] >= _amount, 'exceed tickets amount');

        ticketsAmount = ticketsAmount + _amount;
        whiteInfoUser[msg.sender] = uint8(whiteInfoUser[msg.sender].sub(_amount));

        for (uint i = 0; i < _amount; i++) {
            uint256 tokenId = lotteryNFT.newLotteryItem(msg.sender);
            userLotteryList[msg.sender].push(tokenId);
            emit Claim(msg.sender, tokenId);
        }

    }

    function multiBuy(uint256[] memory _tickets) external {
        require(!buyClosed, 'buy closed already');
        uint256 totalReward = 0;
        uint256 payAmount = 0;
        for (uint i = 0; i < _tickets.length; i++) {
            require (msg.sender == lotteryNFT.ownerOf(_tickets[i]), "not from owner");
            require (!lotteryNFT.getClaimStatus(_tickets[i]), "claimed");
            if(isWinningTicket(_tickets[i])) {
                totalReward = totalReward.add(oneTicketAmount);
                payAmount = payAmount.add(oneTicketPrice);
                emit Buy(msg.sender, _tickets[i]);
            }
        }
        lotteryNFT.multiClaimReward(_tickets);
        if (totalReward>0) {
            buyToken.safeTransferFrom(address(msg.sender), address(this), payAmount);
            // sellToken.safeTransfer(address(msg.sender), totalReward);
            selledList.push(AirdropInfo(address(msg.sender), totalReward));
        }
    }

    function isWinningTicket(uint256 _tokenId) public view returns(bool) {
        uint256 gapNum = ticketsAmount.div(failingAmount);
        if(
            _tokenId.sub(_tokenId.div(gapNum).mul(gapNum)) == failingRandomNumber
            &&
            _tokenId <= gapNum.mul(failingAmount)
        ) {
            return false;
        }
        return true;
    }

    function getUserLotteryListLength(address userAddr) public view returns(uint256) {
        return userLotteryList[userAddr].length;
    }

    function getSelledListLength() public view returns(uint256) {
        return selledList.length;
    }

    function setAdmin(address _adminAddress) public onlyAdmin {
        adminAddress = _adminAddress;
    }

    function setFailingAmount(uint256 _amount) public onlyAdmin {
        failingAmount = _amount;
    }

    function adminWithdraw(uint256 _amount) public onlyAdmin {
        buyToken.safeTransfer(address(msg.sender), _amount);
        emit DevWithdraw(msg.sender, _amount);
    }

}
