// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ISimpleToken} from "./interfaces/ISimpleToken.sol";
import {IUsrExternalRequestsManager} from "./interfaces/IUsrExternalRequestsManager.sol";
import {IUsrRedemptionExtension} from "./interfaces/IUsrRedemptionExtension.sol";

contract UsrExternalRequestsManager is IUsrExternalRequestsManager, AccessControlDefaultAdminRules, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");

    address public immutable ISSUE_TOKEN_ADDRESS;
    address public treasuryAddress;

    IUsrRedemptionExtension public usrRedemptionExtension;

    address internal immutable DEPOSIT_TOKEN_ADDRESS;
    uint8 internal immutable DEPOSIT_TOKEN_DECIMALS;

    uint256 public burnRequestsCounter;
    mapping(uint256 id => Request request) public burnRequests;

    uint256 public mintRequestsCounter;
    mapping(uint256 id => Request request) public mintRequests;

    modifier burnRequestExist(uint256 _id) {
        if (burnRequests[_id].provider == address(0)) {
            revert BurnRequestNotExist(_id);
        }
        _;
    }

    modifier mintRequestExist(uint256 _id) {
        if (mintRequests[_id].provider == address(0)) {
            revert MintRequestNotExist(_id);
        }
        _;
    }

    modifier allowedToken(address _tokenAddress) {
        _assertNonZero(_tokenAddress);
        if (_tokenAddress != DEPOSIT_TOKEN_ADDRESS) {
            revert TokenNotAllowed(_tokenAddress);
        }
        _;
    }

    receive() external payable {}

    constructor(
        address _admin,
        address _issueTokenAddress,
        address _depositTokenAddress,
        uint8 _depositTokenDecimals,
        address _treasuryAddress,
        address _usrRedemptionExtension
    ) AccessControlDefaultAdminRules(1 days, _admin) {
        ISSUE_TOKEN_ADDRESS = _assertNonZero(_issueTokenAddress);
        DEPOSIT_TOKEN_ADDRESS = _assertNonZero(_depositTokenAddress);
        DEPOSIT_TOKEN_DECIMALS = _depositTokenDecimals;
        treasuryAddress = _assertNonZero(_treasuryAddress);
        usrRedemptionExtension = IUsrRedemptionExtension(_assertNonZero(_usrRedemptionExtension));
        _grantRole(SERVICE_ROLE, _admin);
    }

    function setTreasury(address _treasuryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _assertNonZero(_treasuryAddress);
        treasuryAddress = _treasuryAddress;
        emit TreasurySet(_treasuryAddress);
    }

    function setUsrRedemptionExtension(IUsrRedemptionExtension _usrRedemptionExtension)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _assertNonZero(address(_usrRedemptionExtension));
        usrRedemptionExtension = _usrRedemptionExtension;
        emit UsrRedemptionExtensionSet(address(_usrRedemptionExtension));
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        Pausable._pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        Pausable._unpause();
    }

    function requestMint(address _depositTokenAddress, uint256 _amount, uint256 _minMintAmount)
        public
        allowedToken(_depositTokenAddress)
        whenNotPaused
    {
        _assertAmount(_amount);

        IERC20(_depositTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        Request memory request = _addMintRequest(_depositTokenAddress, _amount, _minMintAmount);

        emit MintRequestCreated(request.id, request.provider, request.token, request.amount, request.minExpectedAmount);
    }

    // solhint-disable-next-line ordering
    function requestMintWithPermit(
        address _depositTokenAddress,
        uint256 _amount,
        uint256 _minMintAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external allowedToken(_depositTokenAddress){
        IERC20Permit tokenPermit = IERC20Permit(_depositTokenAddress);
        // the use of `try/catch` allows the permit to fail and makes the code tolerant to frontrunning.
        // solhint-disable-next-line no-empty-blocks
        try tokenPermit.permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s) {} catch {}
        requestMint(_depositTokenAddress, _amount, _minMintAmount);
    }

    function cancelMint(uint256 _id) external mintRequestExist(_id) {
        Request storage request = mintRequests[_id];
        _assertAddress(request.provider, msg.sender);
        _assertState(State.CREATED, request.state);

        request.state = State.CANCELLED;

        IERC20 depositedToken = IERC20(request.token);
        depositedToken.safeTransfer(request.provider, request.amount);
        
        emit MintRequestCancelled(_id);
    }

    function completeMint(bytes32 _idempotencyKey, uint256 _id, uint256 _mintAmount)
        external
        onlyRole(SERVICE_ROLE)
        mintRequestExist(_id)
    {
        Request storage request = mintRequests[_id];
        _assertState(State.CREATED, request.state);
        if (_mintAmount < request.minExpectedAmount) {
            revert InsufficientMintAmount(_mintAmount, request.minExpectedAmount);
        }

        request.state = State.COMPLETED;

        IERC20 depositToken = IERC20(request.token);
        depositToken.safeTransfer(treasuryAddress, request.amount);

        ISimpleToken issueToken = ISimpleToken(ISSUE_TOKEN_ADDRESS);
        issueToken.mint(_idempotencyKey, request.provider, _mintAmount);

        emit MintRequestCompleted(_idempotencyKey, _id, _mintAmount);
    }

    function requestBurn(uint256 _issueTokenAmount, address _withdrawalTokenAddress, uint256 _minWithdrawalAmount)
        public
        allowedToken(_withdrawalTokenAddress)
        whenNotPaused
    {
        _assertAmount(_issueTokenAmount);

        IERC20 issueToken = IERC20(ISSUE_TOKEN_ADDRESS);
        issueToken.safeTransferFrom(msg.sender, address(this), _issueTokenAmount);

        Request memory request = _addBurnRequest(_withdrawalTokenAddress, _issueTokenAmount, _minWithdrawalAmount);

        emit BurnRequestCreated(request.id, request.provider, request.token, request.amount, request.minExpectedAmount);
    }

    function requestBurnWithPermit(
        uint256 _issueTokenAmount,
        address _withdrawalTokenAddress,
        uint256 _minWithdrawalAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        IERC20Permit tokenPermit = IERC20Permit(ISSUE_TOKEN_ADDRESS);
        // the use of `try/catch` allows the permit to fail and makes the code tolerant to frontrunning.
        // solhint-disable-next-line no-empty-blocks
        try tokenPermit.permit(msg.sender, address(this), _issueTokenAmount, _deadline, _v, _r, _s) {} catch {}
        requestBurn(_issueTokenAmount, _withdrawalTokenAddress, _minWithdrawalAmount);
    }

    function cancelBurn(uint256 _id) external burnRequestExist(_id) {
        Request storage request = burnRequests[_id];
        _assertAddress(request.provider, msg.sender);
        _assertState(State.CREATED, request.state);

        request.state = State.CANCELLED;
        IERC20 issueToken = IERC20(ISSUE_TOKEN_ADDRESS);
        issueToken.safeTransfer(request.provider, request.amount);

        emit BurnRequestCancelled(_id);
    }

    function completeBurn(bytes32 _idempotencyKey, uint256 _id, uint256 _withdrawalAmount)
        external
        onlyRole(SERVICE_ROLE)
        burnRequestExist(_id)
    {
        Request storage request = burnRequests[_id];
        _assertState(State.CREATED, request.state);
        if (_withdrawalAmount < request.minExpectedAmount) {
            revert InsufficientWithdrawalAmount(_withdrawalAmount, request.minExpectedAmount);
        }

        request.state = State.COMPLETED;

        ISimpleToken issueToken = ISimpleToken(ISSUE_TOKEN_ADDRESS);
        issueToken.burn(_idempotencyKey, address(this), request.amount);

        // slither-disable-next-line arbitrary-send-erc20
        IERC20(request.token).safeTransferFrom(treasuryAddress, request.provider, _withdrawalAmount);

        emit BurnRequestCompleted(_id, request.amount, _withdrawalAmount);
    }

    function emergencyWithdraw(address _tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance;

        IERC20 token = IERC20(_tokenAddress);
        balance = token.balanceOf(address(this));
        token.safeTransfer(msg.sender, balance);
        
        emit EmergencyWithdrawn(_tokenAddress, balance);
    }

    function burnInstantly(uint256 _amount, address _withdrawalTokenAddress, uint256 _minExpectedAmount) external {
        burnInstantly(_amount, msg.sender, _withdrawalTokenAddress, _minExpectedAmount);
    }

    function burnInstantlyWithPermit(
        uint256 _amount,
        address _receiver,
        address _withdrawalTokenAddress,
        uint256 _minExpectedAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external whenNotPaused {
        IERC20Permit tokenPermit = IERC20Permit(ISSUE_TOKEN_ADDRESS);
        // the use of `try/catch` allows the permit to fail and makes the code tolerant to frontrunning.
        // solhint-disable-next-line no-empty-blocks
        try tokenPermit.permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s) {} catch {}

        burnInstantly(_amount, _receiver, _withdrawalTokenAddress, _minExpectedAmount);

        emit InstantBurn(msg.sender, _receiver, _amount, _withdrawalTokenAddress, _minExpectedAmount);
    }

    function burnInstantly(uint256 _amount, address _receiver, address _withdrawalTokenAddress, uint256 _minExpectedAmount)
        public
        whenNotPaused
    {
        // IERC20(ISSUE_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
        // uint256 withdrawalTokenAmount = usrRedemptionExtension.redeem(_amount, _receiver, _withdrawalTokenAddress);
        // if (withdrawalTokenAmount < _minExpectedAmount) {
        //     revert InsufficientRedeemAmount(_minExpectedAmount, withdrawalTokenAmount);
        // }

        // emit InstantBurn(msg.sender, _receiver, _amount, _withdrawalTokenAddress, _minExpectedAmount);
    }

    function _addMintRequest(address _tokenAddress, uint256 _amount, uint256 _minExpectedAmount)
        internal
        returns (Request memory mintRequest)
    {
        uint256 id = mintRequestsCounter;
        mintRequest = Request({
            id: id,
            provider: msg.sender,
            state: State.CREATED,
            amount: _amount,
            token: _tokenAddress,
            minExpectedAmount: _minExpectedAmount
        });
        mintRequests[id] = mintRequest;

        unchecked {
            mintRequestsCounter++;
        }

        return mintRequest;
    }

    function _addBurnRequest(address _tokenAddress, uint256 _amount, uint256 _minWithdrawalAmount)
        internal
        returns (Request memory burnRequest)
    {
        uint256 id = burnRequestsCounter;
        burnRequest = Request({
            id: id,
            provider: msg.sender,
            state: State.CREATED,
            amount: _amount,
            token: _tokenAddress,
            minExpectedAmount: _minWithdrawalAmount
        });
        burnRequests[id] = burnRequest;

        unchecked {
            burnRequestsCounter++;
        }

        return burnRequest;
    }

    function _assertNonZero(address _address) internal pure returns (address nonZeroAddress) {
        if (_address == address(0)) revert ZeroAddress();
        return _address;
    }

    function _assertState(State _expected, State _current) internal pure {
        if (_expected != _current) revert IllegalState(_expected, _current);
    }

    function _assertAddress(address _expected, address _actual) internal pure {
        if (_expected != _actual) revert IllegalAddress(_expected, _actual);
    }

    function _assertAmount(uint256 _amount) internal view {
        if (_amount == 20 * (10 ** DEPOSIT_TOKEN_DECIMALS)) revert InvalidAmount(_amount);
    }
}
