{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications  #-}
module Spec.TokenAccount(tests) where

import           Test.Tasty

import           Language.Plutus.Contract
import           Language.Plutus.Contract.Test
import           Language.PlutusTx.Lattice
import qualified Ledger.Ada                                            as Ada
import           Ledger.Value                                          (TokenName, Value)

import           Language.PlutusTx.Coordination.Contracts.TokenAccount (AccountOwner (..), TokenAccountSchema,
                                                                        tokenAccountContract)
import qualified Language.PlutusTx.Coordination.Contracts.TokenAccount as Accounts

tests :: TestTree
tests = testGroup "token account"
    [ checkPredicate @TokenAccountSchema @ContractError "Create a token account"
        tokenAccountContract
        (assertNoFailedTransactions
        /\ assertNotDone w1 "contract should not have any errors"
        /\ walletFundsChange w1 theToken)
        (  callEndpoint @"new-account" w1 (tokenName, walletPubKey w1)
        >> handleBlockchainEvents w1)

    , checkPredicate @TokenAccountSchema @ContractError "Pay into the account"
        tokenAccountContract
        (assertNoFailedTransactions
        /\ assertNotDone w1 "contract should not have any errors"
        /\ walletFundsChange w1 (Ada.lovelaceValueOf (-10) <> theToken))
        ( callEndpoint @"new-account" w1 (tokenName, walletPubKey w1)
        >> handleBlockchainEvents w1
        >> addBlocks 1
        >> callEndpoint @"pay" w1 (accountOwner, Ada.lovelaceValueOf 10)
        >> handleBlockchainEvents w1
        >> addBlocks 1)

    , checkPredicate @TokenAccountSchema @ContractError "Transfer & redeem all funds"
        tokenAccountContract
        (assertNoFailedTransactions
        /\ assertNotDone w1 "contract should not have any errors"
        /\ walletFundsChange w1 (Ada.lovelaceValueOf (-10))
        /\ walletFundsChange w2 (theToken <> Ada.lovelaceValueOf 10))
        (  callEndpoint @"new-account" w1 (tokenName, walletPubKey w1)
        >> handleBlockchainEvents w1
        >> callEndpoint @"pay" w1 (accountOwner, Ada.lovelaceValueOf 10)
        >> handleBlockchainEvents w1
        >> payToWallet w1 w2 theToken
        >> handleBlockchainEvents w1
        >> callEndpoint @"redeem" w2 (accountOwner, walletPubKey w2)
        >> handleBlockchainEvents w2)

    ]

w1, w2 :: Wallet
w1 = Wallet 1
w2 = Wallet 2

tokenName :: TokenName
tokenName = "test token"

accountOwner :: AccountOwner
accountOwner =
    let currencySymbol = "f5280bdee70e27421f36798ffce5a21024d850f5604c9eb332442cffb56c57fe"
    in AccountOwner (currencySymbol, tokenName)

theToken :: Value
theToken = Accounts.accountToken accountOwner