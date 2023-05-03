// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ICO is Ownable, ReentrancyGuard {
    // The token being sold
    IERC20 public saleToken;
    IERC20 public acceptToken;

    // Address where funds are collected
    address payable public wallet;
    uint8 public currentSale = 0;
    bool public isSaleLive;
    uint256 public totalTokenRelease;
    uint256 public totalUniqueAddress;

    uint256 public depositDeadline; //timestamp
    uint256 public cliff;
    uint256 public unlockPercentAtCliff;
    uint256 public unlockFrequency; // duration post cliff after which we unlock {unlockPercent} tokens
    uint256 public unlockPercent;
    uint256 public totalLockedTokens; // total tokens across all users
    uint256 public fundRaisedViaEth;
    uint256 public fundRaisedViaToken;

    struct Sale {
        bool lockIn;
        uint8 icoRate;
        uint256 startTime;
        uint256 endTime;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 fundingTarget;
    }
    Sale[] public saleInfo;
    mapping(uint256 => uint256) public totalFunding;
    mapping(address => uint256) public fundingByAcccount;
    mapping(address => uint256) public depositAmount; //total deposited token by user
    mapping(address => uint256) public totalWithdrawnBalance; // total token withdrawn by user

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(
        address indexed purchaser,
        uint256 value,
        uint256 amount
    );

    event Deposit(
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );

    event UpdateLockInDeadLine(uint256 timelime);

    event SaleCreated(uint8 indexed saleId, Sale saleInfo);
    event SaleUpdated(uint8 indexed saleId, Sale saleInfo);

    /**
     * @param _wallet Address where collected funds will be forwarded to
     * @param _token Address of the token being sold
     */
    constructor(
        address _wallet,
        IERC20 _token,
        IERC20 _saleToken,
        uint256 _depositDeadline,
        uint256 _cliff, //time when we get coin lockin in
        uint256 _unlockPercentAtCliff,
        uint256 _unlockFrequency, //what
        uint256 _unlockPercent
    ) {
        require(
            _wallet != address(0) &&
                address(_saleToken) != address(0) &&
                address(_token) != address(0),
            "Wallet address can't be zero address!"
        );
        require(
            address(_token) != address(_saleToken),
            "Sale and Accept token can't be the same!"
        );
        require(
            block.timestamp < _depositDeadline,
            "Deposit Deadline should be greator than current time"
        );
        require(
            _unlockPercentAtCliff > 0 && _unlockPercentAtCliff <= 100,
            "Values can't be zero and Percent values can't be more than 100"
        );

        wallet = payable(_wallet);
        acceptToken = _token;
        saleToken = _saleToken;

        depositDeadline = _depositDeadline;
        cliff = _cliff;
        unlockPercentAtCliff = _unlockPercentAtCliff;
        unlockFrequency = _unlockFrequency;
        unlockPercent = _unlockPercent;
    }

    modifier checkMinAndMaxAmount(uint256 amount) {
        require(
            amount >= saleInfo[currentSale].minAmount &&
                amount <= saleInfo[currentSale].maxAmount,
            "Amount does not meet min and max criteria!"
        );
        _;
    }

    modifier verifyAcceptTokenAllowance(uint256 amount) {
        require(
            IERC20(acceptToken).allowance(msg.sender, address(this)) >= amount,
            "Allowance is too low!"
        );
        _;
    }

    modifier isSaleActive() {
        require(
            isSaleLive && saleInfo[currentSale].endTime > block.timestamp,
            "Sale is not live or ended!"
        );
        _;
    }

    modifier capReached(uint256 _amount) {
        require(
            saleInfo[currentSale].fundingTarget >
                totalFunding[currentSale] + _amount,
            "Funding Target Wiil Be Reached, Try lesser amount!"
        );
        _;
    }

    function initiateSale(
        uint8 rate,
        uint256 startTime,
        uint256 endTime,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 fundingTarget,
        bool lockin
    ) external onlyOwner {
        require(!isSaleLive, "Sale is live currently!");
        require(
            startTime > block.timestamp,
            "Start time should be more than current time!"
        );
        require(endTime > startTime, "Endtime can't be less then start time!");
        require(minAmount > 0, "Minimum Amount can't be zero!");
        require(
            maxAmount > minAmount,
            "Max amount can't be less than min amount!"
        );
        require(rate > 0, "Rate can't be zero!");
        require(fundingTarget > 0, "Funding target can't be zero!");
        saleInfo.push(
            Sale({
                startTime: startTime,
                endTime: endTime,
                minAmount: minAmount,
                maxAmount: maxAmount,
                fundingTarget: fundingTarget,
                icoRate: rate,
                lockIn: lockin
            })
        );
        currentSale = uint8(saleInfo.length - 1);
        emit SaleCreated(currentSale, saleInfo[currentSale]);
    }

    function updateAcceptToken(IERC20 _tokenAddress) external onlyOwner {
        require(address(_tokenAddress) != address(0));
        require(
            address(_tokenAddress) != address(saleToken),
            "Sale and Accept token can't be the same!"
        );
        acceptToken = _tokenAddress;
    }

    function updateSaleToken(IERC20 _tokenAddress) external onlyOwner {
        require(address(_tokenAddress) != address(0));
        require(
            address(_tokenAddress) != address(acceptToken),
            "Sale and Accept token can't be the same!"
        );
        saleToken = _tokenAddress;
    }

    function startSale() external onlyOwner returns (bool) {
        require(
            saleInfo[currentSale].startTime <= block.timestamp &&
                saleInfo[currentSale].endTime >= block.timestamp,
            "Sale time didn't match!"
        );
        isSaleLive = true;
        return true;
    }

    function endSale() external onlyOwner returns (bool) {
        isSaleLive = false;
        return true;
    }

    function updateRate(uint8 rate)
        external
        onlyOwner
        isSaleActive
        returns (bool)
    {
        require(rate > 0, "Rate can't be zero!");
        saleInfo[currentSale].icoRate = rate;
        emit SaleUpdated(currentSale, saleInfo[currentSale]);
        return true;
    }

    function extendSale(uint256 endTime)
        external
        onlyOwner
        isSaleActive
        returns (bool)
    {
        require(
            endTime > block.timestamp,
            "Sale end time should be more than current time!"
        );
        saleInfo[currentSale].endTime = endTime;
        emit SaleUpdated(currentSale, saleInfo[currentSale]);
        return true;
    }

    function updateLockInDeadLine(uint256 time) external onlyOwner {
        require(
            time > block.timestamp,
            "Lockin deadline time should be more than current time!"
        );
        emit UpdateLockInDeadLine(time);
        depositDeadline = time;
    }

    function buyToken(uint256 amount)
        external
        isSaleActive
        checkMinAndMaxAmount(amount)
        capReached(amount)
        verifyAcceptTokenAllowance(amount)
        nonReentrant
    {
        require(
            !saleInfo[currentSale].lockIn,
            "You're trying to buy in Lockin sale!"
        );
        uint256 tokens = saleInfo[currentSale].icoRate * amount;
        emit TokenPurchase(msg.sender, amount, tokens);
        totalFunding[currentSale] += amount;
        fundRaisedViaToken += amount;
        if (fundingByAcccount[msg.sender] == 0) {
            totalUniqueAddress++;
        }
        fundingByAcccount[msg.sender] += amount;
        totalTokenRelease += tokens;
        require(
            IERC20(acceptToken).transferFrom(msg.sender, wallet, amount),
            "Transfer Failed!"
        );

        require(
            IERC20(saleToken).transferFrom(wallet, msg.sender, tokens),
            "Transfer Failed!"
        );
    }

    function buyTokenWithEth()
        public
        payable
        isSaleActive
        checkMinAndMaxAmount(msg.value)
        capReached(msg.value)
    {
        require(
            !saleInfo[currentSale].lockIn,
            "You're trying to buy in Lockin sale!"
        );
        uint256 amount = msg.value;
        uint256 tokens = saleInfo[currentSale].icoRate * amount;
        emit TokenPurchase(msg.sender, amount, tokens);
        totalFunding[currentSale] += amount;
        fundRaisedViaEth += amount;
        if (fundingByAcccount[msg.sender] == 0) {
            totalUniqueAddress++;
        }
        fundingByAcccount[msg.sender] += amount;
        totalTokenRelease += tokens;

        _forwardFunds();
        require(
            IERC20(saleToken).transferFrom(wallet, msg.sender, tokens),
            "Transfer Failed!"
        );
    }

    function buyTokenWithLockIn(uint256 amount)
        external
        isSaleActive
        checkMinAndMaxAmount(amount)
        capReached(amount)
        verifyAcceptTokenAllowance(amount)
        nonReentrant
    {
        require(
            saleInfo[currentSale].lockIn,
            "You're trying to buy lock tokens!"
        );
        require(block.timestamp < depositDeadline, "deposit period over!");
        uint256 tokens = saleInfo[currentSale].icoRate * amount;
        emit TokenPurchase(msg.sender, amount, tokens);
        emit Deposit(msg.sender, address(this), amount);
        totalFunding[currentSale] += amount;
        fundRaisedViaToken += amount;
        if (fundingByAcccount[msg.sender] == 0) {
            totalUniqueAddress++;
        }
        fundingByAcccount[msg.sender] += amount;
        totalTokenRelease += tokens;
        depositAmount[msg.sender] += amount; //user balance updated
        totalLockedTokens += amount; // total contract tokens updated
        require(
            IERC20(acceptToken).transferFrom(msg.sender, wallet, amount),
            "Transfer Failed!"
        );
        require(
            IERC20(saleToken).transferFrom(wallet, address(this), amount),
            "Transfer Failed!"
        );
    }

    function buyTokenWithLockInWithEth()
        external
        payable
        isSaleActive
        checkMinAndMaxAmount(msg.value)
        capReached(msg.value)
    {
        require(
            saleInfo[currentSale].lockIn,
            "You're trying to buy lock tokens!"
        );
        require(block.timestamp < depositDeadline, "deposit period over!");
        uint256 amount = msg.value;
        uint256 tokens = saleInfo[currentSale].icoRate * amount;
        emit TokenPurchase(msg.sender, amount, tokens);
        emit Deposit(msg.sender, address(this), amount);
        totalFunding[currentSale] += amount;
        fundRaisedViaEth += amount;
        if (fundingByAcccount[msg.sender] == 0) {
            totalUniqueAddress++;
        }
        fundingByAcccount[msg.sender] += amount;
        totalTokenRelease += tokens;
        depositAmount[msg.sender] += amount; //user balance updated
        totalLockedTokens += amount; // total contract tokens updated

        _forwardFunds();
        require(
            IERC20(saleToken).transferFrom(wallet, address(this), amount),
            "Transfer Failed!"
        );
    }

    function withdraw(uint256 userRequestedWithdrawAmount) external {
        require(
            block.timestamp > depositDeadline,
            "Withdraw period not started!"
        );

        uint256 netWithdrawable = getNetWithdrawableBalance(msg.sender);

        require(
            netWithdrawable >= userRequestedWithdrawAmount,
            "Requested amount is higher than net withdrawable amount OR user has already withdrawn all the depositAmount"
        );

        emit Withdraw(address(this), msg.sender, userRequestedWithdrawAmount);
        // Withdraw available amount
        totalWithdrawnBalance[msg.sender] += userRequestedWithdrawAmount;
        totalLockedTokens -= userRequestedWithdrawAmount;

        require(
            IERC20(saleToken).transfer(msg.sender, userRequestedWithdrawAmount),
            "Transfer Failed!"
        );
    }

    function _forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    function withdrawEth() external onlyOwner {
        wallet.transfer(address(this).balance);
    }

    receive() external payable {}

    fallback() external {}

    //Calculate netWithdrawable amount for a user
    function getNetWithdrawableBalance(address userAddress)
        public
        view
        returns (uint256)
    {
        uint256 currentWithdrawableBalance = getCurrentUnlockedBalance(
            userAddress
        );
        uint256 netWithdrawable = currentWithdrawableBalance -
            totalWithdrawnBalance[userAddress];
        return netWithdrawable;
    }

    // Calculate total unlocked balance of a user (including already withdrawn)
    function getCurrentUnlockedBalance(address userAddress)
        public
        view
        returns (uint256)
    {
        uint256 totalPercentUnlocked = 0;
        uint256 totalBalance = depositAmount[userAddress];
        uint256 unlockTime = depositDeadline + cliff; //Time at end of cliff

        //when the ico has not ended yet
        if (block.timestamp < unlockTime) {
            return 0;
        }

        if (unlockFrequency > 0) {
            totalPercentUnlocked =
                unlockPercentAtCliff +
                (((block.timestamp - unlockTime) * unlockPercent) /
                    unlockFrequency);
        } else if (unlockFrequency == 0) {
            totalPercentUnlocked = unlockPercentAtCliff;
        }

        if (totalPercentUnlocked > 100) totalPercentUnlocked = 100;
        return (totalPercentUnlocked * totalBalance) / 100;
    }

    //balance of tokens erc20
    function checkBalance() external view returns (uint256) {
        return IERC20(saleToken).balanceOf(msg.sender);
    }

    function checkAcceptTokenBalance() external view returns (uint256) {
        return IERC20(acceptToken).balanceOf(msg.sender);
    }

    function tokenReceivedAsPerRate(uint256 amount)
        external
        view
        returns (uint256)
    {
        return saleInfo[currentSale].icoRate * amount;
    }
}
