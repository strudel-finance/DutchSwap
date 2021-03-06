pragma solidity ^0.6.9;

//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//::::::::::: @#::::::::::: @#:::::::::::: #@j:::::::::::::::::::::::::
//::::::::::: ##::::::::::: @#:::::::::::: #@j:::::::::::::::::::::::::
//::::::::::: ##::::::::::: @#:::::::::::: #@j:::::::::::::::::::::::::
//::::: ########: ##:: ##:: DUTCh>: ihD%y: #@Whdqy:::::::::::::::::::::
//::: ###... ###: ##:: ##:: @B... @@7...t: N@N.. R@K:::::::::::::::::::
//::: ##::::: ##: ##:: ##:: @Q::: @Q.::::: N@j:: z@Q:::::::::::::::::::
//:::: ##DuTCH##: .@QQ@@#:: hQQQh <R@QN@Q: N@j:: z@Q:::::::::::::::::::
//::::::.......: =Q@y....:::....:::......::...:::...:::::::::::::::::::
//:::::::::::::: h@W? sWAP@! 'DW;:::::: KK. ydSWAP@t: NNKNQBdt:::::::::
//:::::::::::::: 'zqRqj*. L@R h@w: QQ: L@5 Q@... d@@: @@U... @Q::::::::
//:::::::::::::::::...... Q@^ ^@@N@wt@BQ@ <@Q^::: @@: @@}::: @@:::::::: 
//:::::::::::::::::: U@@QKt... D@@L.. B@Q.. KDUTCH@Q: @@QQ#QQq:::::::::
//:::::::::::::::::::.....::::::...:::...::::.......: @@!.....:::::::::
//::::::::::::::::::::::::::::::::::::::::::::::::::: @@!::::::::::::::
//::::::::::::::::::::::::::::::::::::::::::::::::::: @@!::::::::::::::
//::::::::::::::01101100:01101111:01101111:01101011::::::::::::::::::::
//:::::01100100:01100101:01100101:01110000:01111001:01110010:::::::::::
//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// DutchSwap Auction V1.1
//   Copyright (c) 2020 DutchSwap.com
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  
// If not, see <https://github.com/deepyr/DutchSwap/>.
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// Authors:
// * Adrian Guerrera / Deepyr Pty Ltd
//
// ---------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later                        
// ---------------------------------------------------------------------


import "./Utils/SafeMathPlus.sol";


contract DutchSwapAuction is Owned {

    using SafeMath for uint256;
    uint256 private constant TENPOW18 = 10 ** 18;

    uint256 public amountRaised;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public startPrice;
    uint256 public minimumPrice;
    uint256 public tokenSupply;
    uint256 public tokenSold;
    bool public finalised;
    uint256 public withdrawDelay;   // delay in seconds preventing withdraws
    uint256 public tokenWithdrawn;  // the amount of auction tokens already withdrawn by bidders
    IERC20 public auctionToken; 
    address payable public wallet;
    mapping(address => uint256) public commitments;

    uint256 private unlocked = 1;

    event AddedCommitment(address addr, uint256 commitment, uint256 price);

    modifier lock() {
        require(unlocked == 1, 'Locked');
        unlocked = 0;
        _;
        unlocked = 1;
    }       

    /// @dev Init function 
    function initDutchAuction(
        address _token, 
        uint256 _tokenSupply, 
        //uint256 _startDate, 
        uint256 _auctionDuration,
        uint256 _startPrice, 
        uint256 _minimumPrice,
        uint256 _withdrawDelay,
        address payable _wallet
    ) 
        external onlyOwner
    {
        require(_auctionDuration > 0, "Auction duration should be longer than 0 seconds");
        require(_startPrice > _minimumPrice, "Start price should be bigger than minimum price");
        require(_minimumPrice > 0, "Minimum price should be bigger than 0");

        auctionToken = IERC20(_token);

        require(IERC20(auctionToken).transferFrom(msg.sender, address(this), _tokenSupply), "Fail to transfer tokens to this contract");

        // 100 tokens are subtracted from totalSupply to ensure that this contract holds more tokens than tokenSuppy.
        // This is to prevent any reverting of withdrawTokens() in case of any insufficiency of tokens due to programming
        // languages' inability to handle float precisely, which might lead to extremely small insufficiency in tokens
        // to be distributed. This potentail insufficiency is extremely small (far less than 1 token), which is more than
        // sufficiently compensated hence.       
        tokenSupply =_tokenSupply.sub(100000000000000000000);
        startDate = block.timestamp;
        endDate = block.timestamp.add(_auctionDuration);
        startPrice = _startPrice;
        minimumPrice = _minimumPrice; 
        withdrawDelay = _withdrawDelay;
        wallet = _wallet;
        finalised = false;
    }


    // Dutch Auction Price Function
    // ============================
    //  
    // Start Price ----- 
    //                   \ 
    //                    \
    //                     \
    //                      \ ------------ Clearing Price
    //                     / \            = AmountRaised/TokenSupply
    //      Token Price  --   \
    //                  /      \ 
    //                --        ----------- Minimum Price
    // Amount raised /          End Time
    //

    /// @notice The average price of each token from all commitments. 
    function tokenPrice() public view returns (uint256) {
        return amountRaised.mul(TENPOW18).div(tokenSold);
    }

    /// @notice Token price decreases at this rate during auction.
    function priceGradient() public view returns (uint256) {
        uint256 numerator = startPrice.sub(minimumPrice);
        uint256 denominator = endDate.sub(startDate);
        return numerator.div(denominator);
    }

      /// @notice Returns price during the auction 
    function priceFunction() public view returns (uint256) {
        /// @dev Return Auction Price
        if (block.timestamp <= startDate) {
            return startPrice;
        }
        if (block.timestamp >= endDate) {
            return minimumPrice;
        }
        uint256 priceDiff = block.timestamp.sub(startDate).mul(priceGradient());
        uint256 price = startPrice.sub(priceDiff);
        return price;
    }

    /// @notice How many tokens the user is able to claim
    function tokensClaimable(address _user) public view returns (uint256) {
        if(!auctionEnded()) {
            return 0;
        }
        return commitments[_user].mul(TENPOW18).div(tokenPrice());
    }

    /// @notice Returns bool if successful or time has ended
    function auctionEnded() public view returns (bool){
        return block.timestamp > endDate;
    }

    /// @notice Returns true and 0 if delay time is 0, otherwise false and delay time (in seconds) 
    function checkWithdraw() public view returns (bool, uint256) {
        if (block.timestamp < endDate) {
            return (false, endDate.sub(block.timestamp).add(withdrawDelay));
        }

        uint256 _elapsed = block.timestamp.sub(endDate);
        if (_elapsed >= withdrawDelay) {
            return (true, 0);
        } else {
            return (false, withdrawDelay.sub(_elapsed));
        }
    }

    /// @notice Returns the amount of auction tokens already withdrawn by bidders
    function getTokenWithdrawn() public view returns (uint256) {
        return tokenWithdrawn;
    }

    /// @notice Returns the amount of auction tokens sold but not yet withdrawn by bidders
    function getTokenNotYetWithdrawn() public view returns (uint256) {
        if (block.timestamp < endDate) {
            return tokenSold;
        }
        uint256 totalTokenSold = amountRaised.mul(TENPOW18).div(tokenPrice());
        return totalTokenSold.sub(tokenWithdrawn);
    }

    //--------------------------------------------------------
    // Commit to buying tokens 
    //--------------------------------------------------------

    /// @notice Buy Tokens by committing ETH to this contract address 
    receive () external payable {
        commitEth(msg.sender);
    }

    /// @notice Commit ETH to buy tokens on sale
    function commitEth (address payable _from) public payable lock {
        //require(address(paymentCurrency) == ETH_ADDRESS);
        require(block.timestamp >= startDate && block.timestamp <= endDate);

        uint256 tokensToPurchase = msg.value.mul(TENPOW18).div(priceFunction());
        // Get ETH able to be committed
        uint256 tokensPurchased = calculatePurchasable(tokensToPurchase);

        tokenSold = tokenSold.add(tokensPurchased);

        // Accept ETH Payments
        uint256 ethToTransfer = tokensPurchased < tokensToPurchase ? msg.value.mul(tokensPurchased).div(tokensToPurchase) : msg.value;

        uint256 ethToRefund = msg.value.sub(ethToTransfer);
        if (ethToTransfer > 0) {
            addCommitment(_from, ethToTransfer);
        }
        // Return any ETH to be refunded
        if (ethToRefund > 0) {
            _from.transfer(ethToRefund);
        }
    }

    /// @notice Commits to an amount during an auction
    function addCommitment(address _addr,  uint256 _commitment) internal {
        commitments[_addr] = commitments[_addr].add(_commitment);
        amountRaised = amountRaised.add(_commitment);
        emit AddedCommitment(_addr, _commitment, tokenPrice());
    }

    /// @notice Returns the amount able to be committed during an auction
    function calculatePurchasable(uint256 _tokensToPurchase) 
        public view returns (uint256)
    {
        uint256 maxPurchasable = tokenSupply.sub(tokenSold);
        if (_tokensToPurchase > maxPurchasable) {
            return maxPurchasable;
        }
        return _tokensToPurchase;
    }

    //--------------------------------------------------------
    // Modify WithdrawDelay In Auction 
    //--------------------------------------------------------

    /// @notice Removes withdraw delay
    /// @dev This function can only be carreid out by the owner of this contract.
    function removeWithdrawDelay() external onlyOwner {
        withdrawDelay = 0;
    }
    
    /// @notice Add withdraw delay
    /// @dev This function can only be carreid out by the owner of this contract.
    function addWithdrawDelay(uint256 _delay) external onlyOwner {
        withdrawDelay = withdrawDelay.add(_delay);
    }


    //--------------------------------------------------------
    // Finalise Auction
    //--------------------------------------------------------

    /// @notice Auction finishes successfully above the reserve
    /// @dev Transfer contract funds to initialised wallet. 
    function finaliseAuction () public {
        require(!finalised && auctionEnded());
        finalised = true;

        //_tokenPayment(paymentCurrency, wallet, amountRaised);
        wallet.transfer(amountRaised);
    }

    /// @notice Withdraw your tokens once the Auction has ended.
    function withdrawTokens() public lock {
        require(auctionEnded(), "DutchSwapAuction: Auction still live");
        (bool canWithdraw,) = checkWithdraw();
        require(canWithdraw == true, "DutchSwapAuction: Withdraw Delay");
        uint256 fundsCommitted = commitments[ msg.sender];
        require(fundsCommitted > 0, "You have no bidded tokens");
        uint256 tokensToClaim = tokensClaimable(msg.sender);
        commitments[ msg.sender] = 0;
        tokenWithdrawn = tokenWithdrawn.add(tokensToClaim);

        /// @notice Successful auction! Transfer tokens bought.
        if (tokensToClaim > 0 ) {
            _tokenPayment(auctionToken, msg.sender, tokensToClaim);
        }
    }

    // /// @notice Sends any unclaimed tokens or stuck tokens after 30 days
    // function transferLeftOver(address tokenAddress, uint256 tokens) public returns (bool success) {
    //     require(block.timestamp > endDate.add(30 * 24 * 60 * 60), "Transfer stuck tokens 30 days after end date");
    //     require(tokens > 0, "Cannot transfer 0 tokens");
    //     _tokenPayment(tokenAddress, wallet, tokens );
    //     return true;
    // }

    /// @dev Helper function to handle ERC20 payments
    function _tokenPayment(IERC20 _token, address payable _to, uint256 _amount) internal {
        require(_token.transfer(_to, _amount), "Fail to transfer tokens");
    }

}