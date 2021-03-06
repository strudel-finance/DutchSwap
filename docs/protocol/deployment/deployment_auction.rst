.. meta::
    :keywords: deployment scripts

.. _deployment_auction:

DutchSwap Deployment
=============================================

Environment
-------------------------------------------
**Local Environment Setup** 

This needs to set up with the following requirements:

* `Install brownie  <https://eth-brownie.readthedocs.io/en/stable/install.html>`_
* `Install Ganache CLI <https://www.npmjs.com/package/ganache-cli>`_

Script
------
We have already deployed Dutchswap Factory Contract for the respective testnet and also in mainnet

If you want to deploy the factories please deploy Auction factory using ref:`deployment_factory`

The links to addresses are :ref:`deployed_contracts`

Create ERC20 Token:
----------------------------
`Only follow the Create ERC20 Token below Steps if you dont have an ERC20Token`



* First we need a ERC20 token. We create a token using ERC20 Token Factory smart contract **BokkyPooBahsFixedSupplyTokenFactory**. The address of token factory is found in Deployed Smart Contract page
  

* Copy the Fixed ERC20 Factory address of the required network and create a token factory using::

        token_factory = BokkyPooBahsFixedSupplyTokenFactory.at(token_factory_address)
    
* Create a transaction to deploy ERC20Token ::

        tx = token_factory.deployTokenContract(SYMBOL,NAME,DECIMALS,NUMBER_OF_AUCTION_TOKENS,{'from': accounts[0], "value": "@value ethers"})

Deploy a new token contract. The account executing this function will be assigned as the owner of the new token contract. The entire totalSupply is minted for the token contract owner.

This transaction will create a ERC20 Fixed Supply ERC20 Token with the properties you pass for the values of the parameters
The parameters are:

1. SYMBOL: The symbol representing the token

2. NAME: The name of the token created

3. DECIMALS:In ERC20 tokens, that scaling factor is denoted by the value of decimals , which indicates how many 0's there are to the right of the decimal point the fixed-point representation of a token

4. NUMBER_OF_AUCTION_TOKENS: The number of tokens that will be minted to the token contract owner's account

5. @value: The value in ether of the total supplied tokens. This must be atleast the minimumFee(0.1 ethers).

*  We need the token to be able to use it. How do we get it? Simple just pass the address of the token we get from above transaction::

         auction_token = FixedSupplyToken.at(web3.toChecksumAddress(tx.events['TokenDeployed']['token']))

* Okay so we have created a token for which we want to auction. Lets create a auction!

Create Dutch auction
---------------------------

* First we need a Auction Factory which actually creates an Auction for the specified ERC20 Token. We have already deployed DutchSwapFactory at respective addresses found in:

   :ref:`deployed_contracts`

* Copy the Auction Factory address of the required network and create a Auction Factory using::
    
   auction_factory = DutchSwapFactory.at(auction_factory_address)

* Before creating an auction we need to approve the Auction Factory to be able to transfer the tokens::
        
   auction_token.approve(auction_factory,AUCTION_TOKENS, {"from": accounts[0]})

* Now lets create a dutch auction by deploying it using the factory::

   tx = auction_factory.deployDutchAuction(auction_token, AUCTION_TOKENS, AUCTION_START,AUCTION_END,PAYMENT_CURRENCY, AUCTION_START_PRICE, AUCTION_RESERVE, wallet, {"from": accounts[0]})

This function creates dutch auction and approves the created dutch auction to use the supplied auction_token for the auction.

The parameters to pass are as follows:

1.auction_token: This is the address of ERC20 Token we just created

2.AUCTION_TOKENS:The supply of total number of tokens for the auction(uint256). This must be in wei(ie totalSupply * 10**18)

3.AUCTION_START: The start date for the auction(uint)

4.AUCTION_END: The end date for the auction(uint)]

5.PAYMENT_CURRENCY: Address of the currency you want to be paid with. Can be ethereum address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) or a token address

6.AUCTION_START_PRICE: Start Price for the token to start auction(in  wei). This should be the maximum price you want your token to be valued at

7.AUCTION_RESERVE: Minimum price you want the token to be valued at.

8.wallet: The address that you want your payment to be received at if the auction is successfuly. It is also the address that you will receive your tokens at if the auction is not successful.

* Finally we need the actual address where the auction has been deployed. This is given by::

    dutch_auction = DutchSwapAuction.at(web3.toChecksumAddress(tx.events['DutchAuctionDeployed']['addr']))

deploy_DutchSwapAuction.py
------------------------------
Okay so all the script mentioned above are put into a deployment script in the file deploy_DutchSwapAuction.py



Please check the code and supply the parameters as per your requirements

All you need to do is run the command:

`brownie run deploy_DutchSwapAuction.py`

The link for the **deploy_DutchSwapAuction.py**:

`deploy_DutchSwapAuction  <https://github.com/deepyr/DutchSwap/blob/master/scripts/deploy_DutchSwapAuction.py>`_

For local setup in your ganacheCLI you need to modify it a little:

In line 27 of deploy_DutchSwapAuction.py change `USE_EXISTING_FACTORY` to False



