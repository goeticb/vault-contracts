// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IDefaultErrors} from "./IDefaultErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUsrRedemptionExtension} from "./IUsrRedemptionExtension.sol";

interface IUsrExternalRequestsManager is IDefaultErrors {
    event MintRequestCreated(
        uint256 indexed id, address indexed provider, address depositToken, uint256 amount, uint256 minMintAmount
    );
    event MintRequestCompleted(bytes32 indexed idempotencyKey, uint256 indexed id, uint256 mintedAmount);
    event MintRequestCancelled(uint256 indexed id);

    event BurnRequestCreated(
        uint256 indexed id,
        address indexed provider,
        address withdrawalTokenAddress,
        uint256 issueTokenAmount,
        uint256 minWithdrawalAmount
    );
    event BurnRequestCompleted(uint256 indexed id, uint256 burnedAmount, uint256 withdrawalAmount);
    event BurnRequestCancelled(uint256 indexed id);

    event InstantBurn(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        address withdrawalToken,
        uint256 minExpectedAmount
    );

    event TreasurySet(address treasuryAddress);
    event UsrRedemptionExtensionSet(address usrRedemptionExtensionAddress);

    event EmergencyWithdrawn(address tokenAddress, uint256 amount);

    error IllegalState(State expected, State current);
    error IllegalAddress(address expected, address actual);
    error MintRequestNotExist(uint256 id);
    error BurnRequestNotExist(uint256 id);
    error TokenNotAllowed(address token);
    error InsufficientMintAmount(uint256 mintAmount, uint256 minMintAmount);
    error InsufficientWithdrawalAmount(uint256 withdrawalAmount, uint256 minWithdrawalAmount);
    error InsufficientRedeemAmount(uint256 minExpectedAmount, uint256 withdrawalAmount);

    // solhint-disable-next-line ordering
    enum State {
        CREATED,
        COMPLETED,
        CANCELLED
    }

    struct Request {
        uint256 id;
        address provider;
        State state;
        uint256 amount;
        address token;
        uint256 minExpectedAmount;
    }

    function setTreasury(address _treasuryAddress) external;

    function setUsrRedemptionExtension(IUsrRedemptionExtension _usrRedemptionExtension) external;

    function pause() external;

    function unpause() external;

    function requestMint(address _depositTokenAddress, uint256 _amount, uint256 _minMintAmount) external;

    // solhint-disable-next-line ordering
    function requestMintWithPermit(
        address _depositTokenAddress,
        uint256 _amount,
        uint256 _minMintAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function cancelMint(uint256 _id) external;

    function completeMint(bytes32 _idempotencyKey, uint256 _id, uint256 _mintAmount) external;

    function requestBurn(uint256 _issueTokenAmount, address _withdrawalTokenAddress, uint256 _minWithdrawalAmount)
        external;

    function requestBurnWithPermit(
        uint256 _issueTokenAmount,
        address _withdrawalTokenAddress,
        uint256 _minWithdrawalAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function cancelBurn(uint256 _id) external;

    function completeBurn(bytes32 _idempotencyKey, uint256 _id, uint256 _withdrawalAmount) external;

    function emergencyWithdraw(address _token) external;

    function burnInstantly(
        uint256 _amount,
        address _receiver,
        address _withdrawalTokenAddress,
        uint256 _minExpectedAmount
    ) external;

    function burnInstantly(uint256 _amount, address _withdrawalTokenAddress, uint256 _minExpectedAmount) external;

    function burnInstantlyWithPermit(
        uint256 _amount,
        address _receiver,
        address _withdrawalTokenAddress,
        uint256 _minExpectedAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;
}
