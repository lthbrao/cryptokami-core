
module Cryptokami.Wallet.API
       ( WalletAPI
       , walletAPI
       ) where

import           Servant ((:<|>), (:>), Proxy (..))

import           Cryptokami.Wallet.API.Types
import qualified Cryptokami.Wallet.API.V0 as V0
import qualified Cryptokami.Wallet.API.V1 as V1

-- | The complete API, qualified by its versions. For backward compatibility's sake, we still expose
-- the old API both under `/api/` and under `/api/v0`. Specification is split under separate modules.
-- Unsurprisingly:
--
-- * Cryptokami.Wallet.API.V0 hosts the full specification of the V0 (Legacy) API;
-- * Cryptokami.Wallet.API.V1 hosts the full specification of the V1 API;
--
-- This project uses Servant, which means the logic is separated from the implementation (i.e. the Server).
-- Such server, together with all its web handlers lives in an executable which contains the aptly-named
-- modules:
--
-- * Cryptokami.Wallet.Server contains the main server;
-- * Cryptokami.Wallet.API.V0.Handlers contains all the @Handler@s serving the V0 API;
-- * Cryptokami.Wallet.API.V1.Handlers contains all the @Handler@s serving the V1 API;
--
type WalletAPI
    =    "api" :> Tags '["V0"]
               :> V0.API
    :<|> "api" :> "v0"
               :> Tags '["V0"]
               :> V0.API
    :<|> "api" :> "v1"
               :> Tags '["V1"]
               :> V1.API

walletAPI :: Proxy WalletAPI
walletAPI = Proxy