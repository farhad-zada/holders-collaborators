// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Level {
    string name;
    uint256 threshold;
    uint256 min;
    uint256 max;
}

struct Token {
    address token;
    uint256 price;
}

struct Holding {
    address holder;
    uint256 amount;
}

struct Collaborator {
    address collaborator;
    address token;
    uint256 amount;
}

enum Status {
    ACTIVE,
    PAUSED,
    CLOSED
}

contract Holders is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant PRICE_DECIMALS = 1e18;
    Level[] private s_levels;
    Token[] private s_tokens;
    Collaborator[] private s_collaborators;
    Status private s_status;

    /// @dev s_holdings[token] => [(holder, amount), ...]
    mapping(address => Holding[]) private s_holdings;

    /// @dev s_holding_index[token][holder] => index
    mapping(address => mapping(address => uint256)) private s_holding_index;

    /// @dev s_token_holding[token] => total
    mapping(address => uint256) private s_token_holding;

    event Hold(address indexed holder, address indexed token, uint256 amount);
    event Collaborate(
        address indexed collaborator,
        address indexed token,
        uint256 amount
    );

    modifier tokenAvailable(address m_token) {
        for (uint256 i = 0; i < s_tokens.length; i++) {
            if (s_tokens[i].token == m_token) {
                _;
                break;
            }
        }
    }

    modifier holdingAvailable(
        address m_token,
        address m_holder,
        uint256 m_amount
    ) {
        require(s_status == Status.ACTIVE, "Holders: stake not available");
        Level memory l = _level();
        uint256 index = s_holding_index[m_token][m_holder];
        uint256 totalAmount = s_holdings[m_token][index].amount + m_amount;
        uint256 totalAmountInBase = (totalAmount * s_tokens[0].price) /
            PRICE_DECIMALS;
        require(totalAmountInBase >= l.min, "Holders: amount below minimum");
        require(totalAmountInBase <= l.max, "Holders: amount above maximum");
        _;
    }

    function initialize(
        Level[] memory m_levels,
        Token[] memory m_tokens
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        require(m_levels.length > 0, "Holders: levels required");
        require(m_tokens.length > 1, "Holders: tokens required");
        s_levels = m_levels;
        s_tokens = m_tokens;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // WRITE FUNCTIONS

    function holding(
        address m_token,
        uint256 m_amount
    )
        external
        tokenAvailable(m_token)
        holdingAvailable(m_token, msg.sender, m_amount)
    {
        _holding(m_token, m_amount);
    }

    function collaborate(
        address m_token,
        uint256 m_amount
    ) external tokenAvailable(m_token) {
        _collaborate(m_token, m_amount);
    }

    function withdraw(address m_token, uint256 m_amount) external onlyOwner {
        IERC20 token = IERC20(m_token);
        token.transfer(msg.sender, m_amount);
    }

    // INTERNAL FUNCTIONS
    function _tokenLevel(address m_token) internal view returns (Level memory) {
        uint256 tokensInBase = (s_token_holding[m_token] * s_tokens[0].price) /
            PRICE_DECIMALS;
        for (uint256 i = 0; i < s_levels.length; i++) {
            if (s_levels[i].threshold > tokensInBase) {
                return s_levels[i];
            }
        }
        return s_levels[s_levels.length - 1];
    }

    function _level() internal view returns (Level memory l) {
        l = s_levels[s_levels.length - 1];
        for (uint256 i = 0; i < s_tokens.length; i++) {
            Level memory tl = tokenLevel(s_tokens[i].token);
            if (tl.threshold < l.threshold) {
                l = tl;
            }
        }
    }

    function _collaborate(address m_token, uint256 m_amount) internal {
        IERC20(m_token).transferFrom(msg.sender, address(this), m_amount);
        s_collaborators.push(
            Collaborator({
                collaborator: msg.sender,
                token: m_token,
                amount: m_amount
            })
        );
        emit Collaborate(msg.sender, m_token, m_amount);
    }

    function _holding(address m_token, uint256 m_amount) internal {
        IERC20 token = IERC20(m_token);
        token.transferFrom(msg.sender, address(this), m_amount);
        s_holdings[m_token].push(
            Holding({holder: msg.sender, amount: m_amount})
        );
        s_token_holding[m_token] += m_amount;
        if (s_holding_index[m_token][msg.sender] == 0) {
            s_holding_index[m_token][msg.sender] = s_holdings[m_token].length;
        }
        emit Hold(msg.sender, m_token, m_amount);
    }

    // READ FUNCTIONS

    function levels() external view returns (Level[] memory) {
        return s_levels;
    }

    function tokens() external view returns (Token[] memory) {
        return s_tokens;
    }

    function collaborators() external view returns (Collaborator[] memory) {
        return s_collaborators;
    }

    function status() external view returns (Status) {
        return s_status;
    }

    function tokenLevel(
        address m_token
    ) public view tokenAvailable(m_token) returns (Level memory l) {
        return _tokenLevel(m_token);
    }

    function level() public view returns (Level memory l) {
        return _level();
    }

    function holdings(
        address m_token
    ) external view tokenAvailable(m_token) returns (Holding[] memory h) {
        return s_holdings[m_token];
    }

    function holding(
        address m_token,
        address m_holder
    ) external view tokenAvailable(m_token) returns (Holding memory h) {
        uint256 index = s_holding_index[m_token][m_holder];
        return s_holdings[m_token][index];
    }
}
