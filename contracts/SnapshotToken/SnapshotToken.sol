pragma solidity 0.4.15;

import '../IsContract.sol';
import '../Snapshot/DailyAndSnapshotable.sol';
import '../Standards/IERC667Token.sol';
import '../Standards/IERC667Callback.sol';
import '../Standards/IERC20Token.sol';
import '../Standards/ISnapshotToken.sol';
import '../Standards/ISnapshotTokenParent.sol';
import './Controlled.sol';
import './ControllerClaims.sol';
import './Helpers/Allowance.sol';
import './Helpers/BasicSnapshotToken.sol';
import './Helpers/MMint.sol';
import './Helpers/TokenInfo.sol';
import './ITokenController.sol';

/*
    Copyright 2016, Remco Bloemen, Jordi Baylina

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/// @title SnapshotToken Contract
/// @author Remco Bloemen, Jordi Baylina
/// @dev This token contract's goal is to make it easy for anyone to clone this
///  token using the token distribution at a given block, this will allow DAO's
///  and DApps to upgrade their features in a decentralized manner without
///  affecting the original token
/// @dev It is ERC20 compliant, but still needs to under go further testing.


/// @dev The actual token contract, the default controller is the msg.sender
///  that deploys the contract, so usually this token will be deployed by a
///  token controller contract, which Giveth will call a "Campaign"

// Consumes the MMint mixin from SnapshotToken
contract SnapshotToken is
    IERC20Token,
    IERC667Token,
    ISnapshotToken,
    MMint,
    BasicSnapshotToken,
    DailyAndSnapshotable,
    Allowance,
    TokenInfo,
    Controlled,
    ControllerClaims,
    IsContract
{

    string private constant VERSION = "ST_1.0";

    // Flag that determines if the token is transferable or not.
    bool public transfersEnabled;

////////////////
// Constructor
////////////////

    /// @notice Constructor to create a MiniMeToken
    /// @param parentToken Address of the parent token, set to 0x0 if it is a
    ///  new token
    /// @param parentSnapshot Block of the parent token that will
    ///  determine the initial distribution of the clone token, set to 0 if it
    ///  is a new token
    /// @param tokenName Name of the new token
    /// @param decimalUnits Number of decimals of the new token
    /// @param tokenSymbol Token Symbol for the new token
    /// @param _transfersEnabled If true, tokens will be able to be transferred
    function SnapshotToken(
        ISnapshotTokenParent parentToken,
        uint parentSnapshot,
        string tokenName,
        uint8 decimalUnits,
        string tokenSymbol,
        bool _transfersEnabled
    )
        BasicSnapshotToken(parentToken, parentSnapshot)
        DailyAndSnapshotable()
        Allowance()
        TokenInfo(tokenName, decimalUnits, tokenSymbol, VERSION)
        Controlled()
        ControllerClaims()
    {
        transfersEnabled = _transfersEnabled;
    }

////////////////
// Fallback
////////////////

    /// @notice The fallback function: If the contract's controller has not been
    ///  set to 0, then the `proxyPayment` method is called which relays the
    ///  ether and creates tokens as described in the token controller contract
    function ()
        public
        payable
    {
        require(isContract(controller));
        require(controller.proxyPayment.value(msg.value)(msg.sender));
    }

///////////////////
// Public functions
///////////////////

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    /// Overrides the public function in SnapshotTokenBase
    function transfer(address _to, uint256 _amount)
        public
        returns (bool success)
    {
        return transfer(msg.sender, _to, _amount);
    }

    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
    ///  its behalf. This is a modified version of the ERC20 approve function
    ///  to be a little bit safer
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return True if the approval was successful
    /// Overrides the public function in AllowanceBase
    function approve(address _spender, uint256 _amount)
        public
        returns (bool success)
    {
        require(transfersEnabled);

        // Alerts the token controller of the approve function call
        if (isContract(controller)) {
            require(controller.onApprove(msg.sender, _spender, _amount));
        }

        return Allowance.approve(_spender, _amount);
    }

    /// @notice `msg.sender` approves `_spender` to send `_amount` tokens on
    ///  its behalf, and then a function is triggered in the contract that is
    ///  being approved, `_spender`. This allows users to use their tokens to
    ///  interact with contracts in one function call instead of two
    /// @param _spender The address of the contract able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return True if the function call was successful
    /// Overrides the public function in AllowanceBase
    function approveAndCall(address _spender, uint256 _amount, bytes _extraData)
        public
        returns (bool success)
    {
        require(approve(_spender, _amount));

        IERC667Callback(_spender).receiveApproval(
            msg.sender,
            _amount,
            this,
            _extraData
        );

        return true;
    }

////////////////
// Enable tokens transfers
////////////////

    /// @notice Enables token holders to transfer their tokens freely if true
    /// @param _transfersEnabled True if transfers are allowed in the clone
    function enableTransfers(bool _transfersEnabled)
        public
        onlyController
    {
        transfersEnabled = _transfersEnabled;
    }

////////////////
// Generate and destroy tokens
////////////////

    /// @notice Mints `_amount` tokens that are assigned to `_owner`
    /// @param _owner The address that will be assigned the new tokens
    /// @param _amount The quantity of tokens generated
    /// @return True if the tokens are generated correctly
    function generateTokens(address _owner, uint _amount)
        public
        onlyController
        returns (bool)
    {
        return BasicSnapshotToken.mGenerateTokens(_owner, _amount);
    }

    /// @notice Burns `_amount` tokens from `_owner`
    /// @param _owner The address that will lose the tokens
    /// @param _amount The quantity of tokens to burn
    /// @return True if the tokens are burned correctly
    function destroyTokens(address _owner, uint _amount)
        public
        onlyController
        returns (bool)
    {
        return BasicSnapshotToken.mDestroyTokens(_owner, _amount);
    }

////////////////
// Internal functions
////////////////

    /// @dev This is the actual transfer function in the token contract, it can
    ///  only be called by other functions in this contract.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    /// Implements the abstract function from AllowanceBase
    function mAllowanceTransfer(address _from, address _to, uint _amount)
        internal
        returns(bool)
    {
        return transfer(_from, _to, _amount);
    }

    /// @dev This is the actual transfer function in the token contract, it can
    ///  only be called by other functions in this contract.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    /// Implements the abstract function from AllowanceBase
    function transfer(address _from, address _to, uint _amount)
        internal
        returns(bool)
    {
        require(transfersEnabled);

        // Alerts the token controller of the transfer
        if (isContract(controller)) {
            require(controller.onTransfer(_from, _to, _amount));
        }

        // Do not allow transfer to 0x0 or the token contract itself
        require(_to != 0);
        require(_to != address(this));

        return mTransfer(_from, _to, _amount);
    }
}
