module Cryptokami.Wallet.API.V1.Handlers.Updates where

import           Universum

import           Cryptokami.Wallet.API.Response (WalletResponse, single)
import           Cryptokami.Wallet.API.V1.Types
import qualified Cryptokami.Wallet.API.V1.Updates as Updates

import           Servant
import           Test.QuickCheck (arbitrary, generate)

handlers :: Server Updates.API
handlers =   nextUpdate
        :<|> applyUpdate

nextUpdate :: Handler (WalletResponse WalletUpdate)
nextUpdate = single <$> (liftIO $ generate arbitrary)

applyUpdate :: Handler (WalletResponse WalletUpdate)
applyUpdate = single <$> (liftIO $ generate arbitrary)
