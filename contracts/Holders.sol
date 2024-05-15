// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Example initializer arguments:
/*
[["Level 1", 1000000000000000000, 100000000000000000000, 1000000000000000000000],["Level 2", 10000000000000000000000, 1000000000000000000000, 10000000000000000000000],["Level 3", 100000000000000000000000, 10000000000000000000000, 100000000000000000000000]]
[["token 1 address", 5000000000000000000], ["token 2 address", 10000000000000000000]]
1630489200,
Math.round(Date.now()/1000)+3000;
*/

contract Holders is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private s_startsAt;
    uint256 private s_endsAt;
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

    modifier holdingAvailable(
        Token memory m_token,
        address m_holder,
        uint256 m_amount
    ) {
        require(_status() == Status.ACTIVE, "Holders: stake not available");
        Level memory l = _level();
        uint256 index = s_holding_index[m_token.token][m_holder];
        uint256 totalAmount;
        if (index > 0) {
            totalAmount =
                s_holdings[m_token.token][index - 1].amount +
                m_amount;
        } else {
            totalAmount = m_amount;
        }
        uint256 totalAmountInBase = (totalAmount * m_token.price) /
            PRICE_DECIMALS;
        require(totalAmountInBase >= l.min, "Holders: amount below minimum");
        require(totalAmountInBase <= l.max, "Holders: amount above maximum");
        _;
    }

    function initialize(
        Level[] memory m_levels,
        Token[] memory m_tokens,
        uint256 m_startsAt,
        uint256 m_endsAt
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        _insertLevels(m_levels);
        _insertTokens(m_tokens);
        s_startsAt = m_startsAt;
        s_endsAt = m_endsAt;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // INITIALIZER FUNCTIONS

    function _insertLevels(Level[] memory m_levels) internal onlyOwner {
        require(m_levels.length > 0, "Holders: levels required");
        for (uint256 i = 0; i < m_levels.length; i++) {
            s_levels.push(m_levels[i]);
        }
    }

    function _insertTokens(Token[] memory m_tokens) internal onlyOwner {
        require(m_tokens.length > 1, "Holders: tokens required");
        for (uint256 i = 0; i < m_tokens.length; i++) {
            s_tokens.push(m_tokens[i]);
        }
    }

    // WRITE FUNCTIONS

    function holding(address m_token, uint256 m_amount) external {
        Token memory token = _findToken(m_token);
        _holding(token, m_amount);
    }

    function collaborate(address m_token, uint256 m_amount) external {
        Token memory token = _findToken(m_token);
        _collaborate(token.token, m_amount);
    }

    function withdraw(address m_token, uint256 m_amount) external onlyOwner {
        IERC20 token = IERC20(m_token);
        token.transfer(msg.sender, m_amount);
    }

    function setStatus(Status m_status) external onlyOwner {
        s_status = m_status;
    }

    // INTERNAL FUNCTIONS
    function _holding(
        Token memory m_token,
        uint256 m_amount
    ) internal holdingAvailable(m_token, msg.sender, m_amount) {
        IERC20 token = IERC20(m_token.token);
        token.transferFrom(msg.sender, address(this), m_amount);
        s_token_holding[m_token.token] += m_amount;
        uint256 index = s_holding_index[m_token.token][msg.sender];
        if (index == 0) {
            s_holdings[m_token.token].push(
                Holding({holder: msg.sender, amount: m_amount})
            );
            s_holding_index[m_token.token][msg.sender] = s_holdings[
                m_token.token
            ].length;
        } else {
            s_holdings[m_token.token][index - 1].amount += m_amount;
        }
        emit Hold(msg.sender, m_token.token, m_amount);
    }

    function _tokenLevel(
        Token memory m_token
    ) internal view returns (Level memory) {
        uint256 tokensInBase = (s_token_holding[m_token.token] *
            m_token.price) / PRICE_DECIMALS;
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
        for (uint256 i = 0; i < s_collaborators.length; i++) {
            if (s_collaborators[i].collaborator == msg.sender) {
                s_collaborators[i].amount += m_amount;
                emit Collaborate(msg.sender, m_token, m_amount);
                return;
            }
        }
        s_collaborators.push(
            Collaborator({
                collaborator: msg.sender,
                token: m_token,
                amount: m_amount
            })
        );
        emit Collaborate(msg.sender, m_token, m_amount);
    }

    function _status() internal view returns (Status) {
        if (block.timestamp < s_startsAt) {
            return Status.WAITING;
        }
        if (block.timestamp > s_endsAt) {
            return Status.CLOSED;
        }
        return s_status;
    }

    function _findToken(address m_token) internal view returns (Token memory) {
        for (uint256 i = 0; i < s_tokens.length; i++) {
            if (s_tokens[i].token == m_token) {
                return s_tokens[i];
            }
        }
        revert("Holders: token not found");
    }

    // READ FUNCTIONS

    function startsAt() external view returns (uint256) {
        return s_startsAt;
    }

    function endsAt() external view returns (uint256) {
        return s_endsAt;
    }

    function levels() external view returns (Level[] memory) {
        return s_levels;
    }

    function tokens() external view returns (Token[] memory) {
        return s_tokens;
    }

    function collaborators() external view returns (Collaborator[] memory) {
        return s_collaborators;
    }

    function status() external view returns (Status s) {
        return _status();
    }

    function tokenLevel(address m_token) public view returns (Level memory l) {
        Token memory token = _findToken(m_token);
        return _tokenLevel(token);
    }

    function level() public view returns (Level memory l) {
        return _level();
    }

    function holdings(
        address m_token
    ) external view returns (Holding[] memory h) {
        return s_holdings[m_token];
    }

    function holding(
        address m_token,
        address m_holder
    ) external view returns (Holding memory h) {
        uint256 index = s_holding_index[m_token][m_holder];
        if (index == 0) {
            return Holding({holder: m_holder, amount: 0});
        }
        return s_holdings[m_token][index - 1];
    }

    function tokenTotal(address m_token) external view returns (uint256) {
        return s_token_holding[m_token];
    }
}

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
    CLOSED,
    WAITING
}
